// Syncs the GitHub team owners-<repo> to the set of Port users who own the service.
//
// Desired members = _user entities whose `team` list intersects the service's
// owning `team` list, and that have a non-empty properties.github_login.
// Only membership of owners-<repo> is changed. Teams are never created or deleted,
// and CODEOWNERS is never touched.
//
// MODE=dry-run  -> report the diff only (default in the workflow)
// MODE=apply    -> add and remove members to match the desired set
//
// Configuration comes from environment variables. See the README in this folder.

import crypto from 'node:crypto';
import { appendFileSync } from 'node:fs';

const {
  PORT_CLIENT_ID,
  PORT_CLIENT_SECRET,
  OWNERSHIP_APP_PRIVATE_KEY,
  OWNERSHIP_APP_CLIENT_ID,
  OWNERSHIP_INSTALLATION_ID,
  OWNERSHIP_GITHUB_ORG,
  PORT_API_URL,
  SERVICE_BLUEPRINT,
  SERVICE,
  REPO,
  MODE,
  GITHUB_STEP_SUMMARY,
} = process.env;

const GITHUB_API = 'https://api.github.com';

// Set by configure() at the start of main().
let ORG;
let PORT_API;
let BLUEPRINT;

function configure() {
  ORG = requireEnv('OWNERSHIP_GITHUB_ORG', OWNERSHIP_GITHUB_ORG);
  // Include /v1, for example https://api.port.io/v1 or https://api.us.port.io/v1.
  PORT_API = requireEnv('PORT_API_URL', PORT_API_URL).replace(/\/+$/, '');
  BLUEPRINT = (SERVICE_BLUEPRINT ?? '').trim() || 'service';
}

function fail(message) {
  throw new Error(message);
}

function requireEnv(name, value) {
  if (!value || !value.trim()) fail(`Missing required value: ${name}`);
  return value.trim();
}

// ---------- Port ----------

async function portToken() {
  const res = await fetch(`${PORT_API}/auth/access_token`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      clientId: PORT_CLIENT_ID,
      clientSecret: PORT_CLIENT_SECRET,
    }),
  });
  if (!res.ok) fail(`Port auth failed with HTTP ${res.status}`);
  const body = await res.json();
  return body.accessToken;
}

async function portGet(token, path) {
  const res = await fetch(`${PORT_API}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) fail(`Port GET ${path} failed with HTTP ${res.status}`);
  return res.json();
}

async function readDesiredMembers(token, serviceId) {
  const serviceBody = await portGet(
    token,
    `/blueprints/${encodeURIComponent(BLUEPRINT)}/entities/${encodeURIComponent(serviceId)}`,
  );
  const service = serviceBody.entity ?? serviceBody;
  const ownerTeams = new Set(service.team ?? []);
  if (ownerTeams.size === 0) {
    fail(`${BLUEPRINT} ${serviceId} has no owning teams in Port. Refusing to sync.`);
  }

  // Rule: a swarm's parent team must co-own any service the swarm owns.
  const teamsBody = await portGet(token, '/blueprints/_team/entities');
  const teams = Array.isArray(teamsBody) ? teamsBody : teamsBody.entities ?? [];
  const teamById = new Map(teams.map((t) => [t.identifier, t]));
  const missingParents = [];
  for (const teamId of ownerTeams) {
    const team = teamById.get(teamId);
    if (team?.properties?.team_kind !== 'swarm') continue;
    const parentRef = team.relations?.parent_team;
    const parent = typeof parentRef === 'object' && parentRef ? parentRef.identifier : parentRef;
    if (parent && !ownerTeams.has(parent)) {
      missingParents.push(`${teamId} (parent ${parent})`);
    }
  }
  if (missingParents.length) {
    fail(
      `Service ${serviceId} owns swarm(s) without their parent team as an owner: ${missingParents.join(', ')}. ` +
        'Link the swarm to the service again so the parent is added. Refusing to sync.',
    );
  }

  const usersBody = await portGet(token, '/blueprints/_user/entities');
  const users = Array.isArray(usersBody) ? usersBody : usersBody.entities ?? [];

  const desired = new Map(); // lowercase login -> { login, port user }
  const skipped = [];

  for (const user of users) {
    const userTeams = user.team ?? [];
    const isOwner = userTeams.some((team) => ownerTeams.has(team));
    if (!isOwner) continue;

    const login = (user.properties?.github_login ?? '').trim();
    if (!login) {
      skipped.push({ user: user.identifier, reason: 'no github_login in Port' });
      continue;
    }
    desired.set(login.toLowerCase(), { login, user: user.identifier });
  }

  return { ownerTeams: [...ownerTeams], desired, skipped };
}

// ---------- GitHub App ----------

function makeAppJwt(clientId, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);
  const encode = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
  const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iat: now - 60,
    exp: now + 540,
    iss: clientId,
  })}`;
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(unsigned)
    .sign(privateKeyPem, 'base64url');
  return `${unsigned}.${signature}`;
}

async function github(method, path, token, body) {
  const res = await fetch(`${GITHUB_API}${path}`, {
    method,
    headers: {
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      Authorization: `Bearer ${token}`,
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (res.status === 204) return null;

  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  if (!res.ok) {
    const message = data?.message ?? text;
    const error = new Error(`${method} ${path} -> HTTP ${res.status}: ${message}`);
    error.status = res.status;
    throw error;
  }
  return data;
}

async function installationToken() {
  const jwt = makeAppJwt(
    requireEnv('OWNERSHIP_APP_CLIENT_ID', OWNERSHIP_APP_CLIENT_ID),
    requireEnv('OWNERSHIP_APP_PRIVATE_KEY', OWNERSHIP_APP_PRIVATE_KEY),
  );
  const installationId = requireEnv('OWNERSHIP_INSTALLATION_ID', OWNERSHIP_INSTALLATION_ID);
  const result = await github('POST', `/app/installations/${installationId}/access_tokens`, jwt);
  return result.token;
}

async function currentTeamMembers(token, slug) {
  const members = [];
  for (let page = 1; ; page += 1) {
    const batch = await github(
      'GET',
      `/orgs/${ORG}/teams/${slug}/members?per_page=100&page=${page}`,
      token,
    );
    members.push(...batch);
    if (batch.length < 100) break;
  }
  return members;
}

// ---------- Main ----------

function writeSummary(markdown) {
  console.log(markdown);
  if (GITHUB_STEP_SUMMARY) appendFileSync(GITHUB_STEP_SUMMARY, `${markdown}\n`);
}

async function main() {
  configure();
  const service = requireEnv('SERVICE', SERVICE);
  const repo = requireEnv('REPO', REPO);
  const mode = requireEnv('MODE', MODE);
  if (mode !== 'dry-run' && mode !== 'apply') fail(`MODE must be dry-run or apply, got ${mode}`);

  const slug = `owners-${repo}`;

  const portAccess = await portToken();
  const { ownerTeams, desired, skipped } = await readDesiredMembers(portAccess, service);

  if (desired.size === 0) {
    fail(
      `Port resolves no members with a github_login for ${service} (owner teams: ${ownerTeams.join(', ')}). ` +
        'Refusing to empty the GitHub team.',
    );
  }

  const token = await installationToken();

  // The team must already exist. This job never creates teams.
  try {
    await github('GET', `/orgs/${ORG}/teams/${slug}`, token);
  } catch (error) {
    if (error.status === 404) fail(`GitHub team ${ORG}/${slug} does not exist. Create it first.`);
    throw error;
  }

  const members = await currentTeamMembers(token, slug);
  const current = new Map(members.map((m) => [m.login.toLowerCase(), m.login]));

  const toAdd = [...desired.values()].filter((d) => !current.has(d.login.toLowerCase()));
  const toRemove = [...current.entries()]
    .filter(([lower]) => !desired.has(lower))
    .map(([, login]) => login);
  const unchanged = [...desired.values()].filter((d) => current.has(d.login.toLowerCase()));

  const results = [];

  if (mode === 'apply') {
    for (const { login, user } of toAdd) {
      try {
        await github('PUT', `/orgs/${ORG}/teams/${slug}/memberships/${login}`, token, { role: 'member' });
        results.push({ action: 'added', login, status: 'ok' });
      } catch (error) {
        results.push({ action: 'added', login, status: `failed: ${error.message}`, user });
      }
    }
    for (const login of toRemove) {
      try {
        await github('DELETE', `/orgs/${ORG}/teams/${slug}/memberships/${login}`, token);
        results.push({ action: 'removed', login, status: 'ok' });
      } catch (error) {
        results.push({ action: 'removed', login, status: `failed: ${error.message}` });
      }
    }
  }

  const rows = [
    ...toAdd.map((d) => ({ action: 'add', login: d.login, port_user: d.user })),
    ...toRemove.map((login) => ({ action: 'remove', login, port_user: '' })),
    ...unchanged.map((d) => ({ action: 'no change', login: d.login, port_user: d.user })),
  ];

  const lines = [
    `## owners-${repo} sync (${mode})`,
    '',
    `- Service: \`${service}\``,
    `- Port owner teams: ${ownerTeams.map((t) => `\`${t}\``).join(', ')}`,
    `- Desired members: ${desired.size}`,
    `- Current GitHub members: ${members.length}`,
    `- To add: ${toAdd.length}, to remove: ${toRemove.length}, unchanged: ${unchanged.length}`,
    '',
    '| Action | GitHub login | Port user |',
    '| --- | --- | --- |',
    ...rows.map((r) => `| ${r.action} | ${r.login} | ${r.port_user} |`),
  ];

  if (skipped.length) {
    lines.push('', '**Skipped (Port user in owner team, not synced):**');
    lines.push(...skipped.map((s) => `- ${s.user}: ${s.reason}`));
  }

  if (mode === 'apply') {
    lines.push('', '**Results:**');
    lines.push(...results.map((r) => `- ${r.action} ${r.login}: ${r.status}`));
  } else {
    lines.push('', 'Dry run. No GitHub changes were made.');
  }

  writeSummary(lines.join('\n'));

  const failures = results.filter((r) => r.status !== 'ok');
  if (failures.length) fail(`${failures.length} membership change(s) failed. See summary.`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
