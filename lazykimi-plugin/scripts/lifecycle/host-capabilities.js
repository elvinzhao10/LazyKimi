'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const CAPABILITY_STATUSES = Object.freeze(['package-ready', 'missing', 'probe-observed', 'current-session-ready']);
const SURFACES = Object.freeze(['skills', 'commands', 'agents', 'hooks', 'mcp']);
const HOSTILE_OUTPUT = /ignore previous instructions|system prompt|<\/?(?:system|assistant|user)>/i;
const VERSION = /(?:Kimi(?: Code)?(?: CLI)?\s+)?v?(\d+)\.(\d+)\.(\d+)/i;
const FIFTEEN_MINUTES = 15 * 60 * 1000;
// Kimi plugin-enablement observation paths are documented-untested (T21 host
// verification item): when the real per-user plugin config location differs,
// these reads degrade to "absent" and never mutate anything.
const DEFAULT_CONFIG_PATH = path.join(process.env.HOME || '', '.kimi-code', 'config.json');
const DEFAULT_MARKETPLACES_PATH = path.join(process.env.HOME || '', '.kimi-code', 'plugins', 'known_marketplaces.json');

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function readableFingerprint(file) {
  try {
    return sha256(file);
  } catch (error) {
    if (error && typeof error === 'object' && ['ENOENT', 'EACCES', 'EISDIR', 'ENOTDIR'].includes(error.code)) return null;
    throw error;
  }
}

function missing(capability, reasonCode, fingerprint = null) {
  return { capability, status: 'missing', reason_code: reasonCode, fingerprint, evidence: null };
}

function capability(capabilityName, status, fingerprint, evidence, reasonCode = null) {
  if (!CAPABILITY_STATUSES.includes(status)) throw new Error('invalid capability status');
  return { capability: capabilityName, status, reason_code: reasonCode, fingerprint, evidence };
}

function execute(executable, arguments_) {
  let result;
  try {
    result = spawnSync(executable, arguments_, {
      cwd: path.dirname(executable), encoding: 'utf8', shell: false, timeout: 3000, maxBuffer: 65536,
      env: { PATH: process.env.PATH || '/usr/bin:/bin' },
    });
  } catch (error) {
    return { ok: false, output: '' , error };
  }
  if (result.error || result.status !== 0 || typeof result.stdout !== 'string') return { ok: false, output: '' };
  if (HOSTILE_OUTPUT.test(result.stdout) || result.stdout.length > 65535) return { ok: false, hostile: true, output: '' };
  return { ok: true, hostile: false, output: result.stdout };
}

function parsedVersion(executable) {
  const result = execute(executable, ['--version']);
  if (!result.ok) return { ...result, version: null };
  const matched = result.output.match(VERSION);
  return { ...result, version: matched ? matched.slice(1, 4).map(Number) : null };
}

function versionText(version) {
  return version.join('.');
}

function discoverKimiBinary(pathValue = process.env.PATH || '') {
  for (const directory of pathValue.split(path.delimiter).filter(Boolean)) {
    const candidate = path.resolve(directory, 'kimi');
    try {
      fs.accessSync(candidate, fs.constants.R_OK | fs.constants.X_OK);
      return candidate;
    } catch (error) {
      if (!error || typeof error !== 'object' || !['ENOENT', 'EACCES', 'ENOTDIR'].includes(error.code)) throw error;
    }
  }
  return null;
}

// Bounded, read-only CLI probe. The `kimi` binary is probed only through
// `--version`; every claim is fingerprinted to the exact executable bytes.
function probeKimi({ binary, now }) {
  if (typeof binary !== 'string' || binary === '') {
    return { product: 'Kimi', binary: null, version: null, outcome: 'absent', reason_code: 'BINARY_ABSENT',
      capabilities: SURFACES.map((name) => missing(name, 'BINARY_ABSENT')) };
  }
  const fingerprint = readableFingerprint(binary);
  if (fingerprint === null) {
    return { product: 'Kimi', binary, version: null, outcome: 'blocked', reason_code: 'BINARY_UNREADABLE',
      capabilities: SURFACES.map((name) => missing(name, 'BINARY_UNREADABLE', null)) };
  }
  const probe = parsedVersion(binary);
  if (probe.hostile) {
    return { product: 'Kimi', binary, version: null, outcome: 'blocked', reason_code: 'UNTRUSTED_PROBE_OUTPUT',
      capabilities: SURFACES.map((name) => missing(name, 'UNTRUSTED_PROBE_OUTPUT', fingerprint)) };
  }
  if (!probe.ok || probe.version === null) {
    return { product: 'Kimi', binary, version: null, outcome: 'blocked', reason_code: 'VERSION_PROBE_FAILED',
      capabilities: SURFACES.map((name) => missing(name, 'VERSION_PROBE_FAILED', fingerprint)) };
  }
  const version = versionText(probe.version);
  const postFingerprint = readableFingerprint(binary);
  if (postFingerprint !== fingerprint) {
    return { product: 'Kimi', binary, version, outcome: 'blocked', reason_code: 'STALE_EXECUTABLE',
      capabilities: SURFACES.map((name) => missing(name, 'STALE_EXECUTABLE', postFingerprint)) };
  }
  const evidence = {
    scope: 'probe', ref: `kimi-cli#sha256=${fingerprint}`, sha256: fingerprint, session_id: null,
    observed_at: now, argv: ['--version'],
  };
  return {
    product: 'Kimi', binary, version, outcome: 'observed', reason_code: null,
    capabilities: SURFACES.map((name) => capability(name, 'probe-observed', fingerprint, evidence)),
  };
}

function readJsonFile(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    if (error && typeof error === 'object' && ['ENOENT', 'EACCES', 'EISDIR', 'ENOTDIR'].includes(error.code)) return null;
    if (error instanceof SyntaxError) return null;
    throw error;
  }
}

function pluginEntry(plugins, pluginId) {
  if (!plugins || typeof plugins !== 'object' || Array.isArray(plugins)) return { found: false, enabled: false };
  const installed = plugins.installed;
  if (installed && typeof installed === 'object' && !Array.isArray(installed) && pluginId in installed) {
    return { found: true, enabled: entryEnabled(installed[pluginId]) };
  }
  if (Array.isArray(installed)) {
    const entry = installed.find((item) => item && (item.id === pluginId || item.name === pluginId));
    if (entry !== undefined) return { found: true, enabled: entryEnabled(entry) };
  }
  if (pluginId in plugins) return { found: true, enabled: entryEnabled(plugins[pluginId]) };
  return { found: false, enabled: false };
}

function entryEnabled(entry) {
  if (entry === true) return true;
  if (entry === false || entry === null || entry === undefined) return false;
  if (typeof entry === 'object') {
    if (typeof entry.enabled === 'boolean') return entry.enabled;
    if (typeof entry.disabled === 'boolean') return !entry.disabled;
  }
  return false;
}

// Best-effort, advisory enable-state observation. Reads the user-scope Kimi
// config "plugins" key and the known-marketplaces registry when readable.
// Missing or unreadable files degrade to status "absent" and never mutate
// anything; this is an observation only.
function observeKimiEnablement({
  pluginId,
  marketplaceName,
  configPath = DEFAULT_CONFIG_PATH,
  knownMarketplacesPath = DEFAULT_MARKETPLACES_PATH,
  now = new Date().toISOString(),
} = {}) {
  if (typeof pluginId !== 'string' || pluginId === '') throw new Error('pluginId is required');
  const config = readJsonFile(configPath);
  const marketplaces = readJsonFile(knownMarketplacesPath);
  const configFingerprint = readableFingerprint(configPath);
  const masterEnabled = !config || typeof config !== 'object' ? null
    : typeof config.plugins === 'object' && config.plugins !== null && !Array.isArray(config.plugins)
      && typeof config.plugins.enabled === 'boolean' ? config.plugins.enabled : null;
  const entry = config && typeof config === 'object' ? pluginEntry(config.plugins, pluginId) : { found: false, enabled: false };
  const marketplaceRows = marketplaces && typeof marketplaces === 'object' && Array.isArray(marketplaces.marketplaces)
    ? marketplaces.marketplaces : [];
  const marketplaceRow = marketplaceName
    ? marketplaceRows.find((row) => row && (row.name === marketplaceName || row.id === marketplaceName)) ?? null
    : null;
  const status = !config ? 'absent' : !entry.found ? 'absent' : entry.enabled && masterEnabled !== false ? 'enabled' : 'disabled';
  return {
    status,
    best_effort: true,
    observed_at: now,
    config_path: configPath,
    config_fingerprint: configFingerprint,
    master_enabled: masterEnabled,
    plugin_found: entry.found,
    plugin_enabled: entry.enabled,
    marketplace_registered: marketplaceRow !== null,
    marketplace: marketplaceRow === null ? null : {
      id: marketplaceRow.id ?? null,
      name: marketplaceRow.name ?? null,
      plugin_count: typeof marketplaceRow.pluginCount === 'number' ? marketplaceRow.pluginCount : null,
    },
  };
}

function currentObservation(observation, now) {
  if (!observation || typeof observation !== 'object' || Array.isArray(observation)) return { current: false, reason: 'OBSERVATION_ABSENT' };
  const observedAt = Date.parse(observation.observed_at);
  const current = Date.parse(now);
  if (!Number.isFinite(observedAt) || observedAt > current || current - observedAt > FIFTEEN_MINUTES) {
    return { current: false, reason: 'OBSERVATION_STALE' };
  }
  return { current: true, reason: null };
}

function blockedMatrix(reasonCode, fingerprint) {
  return { product: 'Kimi', outcome: 'blocked', reason_code: reasonCode,
    capabilities: SURFACES.map((name) => missing(name, reasonCode, fingerprint)) };
}

// Capability matrix for the Kimi host. Evidence ladder:
//   package-ready        manifest declares the surface (package scope)
//   probe-observed       current enablement observation (probe scope)
//   current-session-ready  current-session receipt binds the surface (session scope)
//   missing              surface excluded, unobserved, or the claim failed closed
function buildKimiMatrix({ manifestPath, routes, enablement = null, receipt = null, now, version = null, build = null, sessionId = null }) {
  const fingerprint = sha256(manifestPath);
  const selected = new Set(routes);
  if (selected.has('kimi-plugin-manifest') && selected.has('kimi-work-skills-fallback')) return blockedMatrix('ROUTE_COLLISION', fingerprint);
  const fallbackOnly = selected.has('kimi-work-skills-fallback');
  const allowed = fallbackOnly ? new Set(['skills', 'mcp']) : new Set(SURFACES);
  const rows = Object.fromEntries(SURFACES.map((name) => [name, allowed.has(name)
    ? capability(name, 'package-ready', fingerprint, {
      scope: 'package', ref: `lazykimi-plugin/kimi.plugin.json#sha256=${fingerprint}`, sha256: fingerprint, session_id: null,
    })
    : missing(name, 'FALLBACK_SURFACE_EXCLUDED', fingerprint)]));
  if (enablement && typeof enablement === 'object') {
    if (enablement.status === 'enabled') {
      const evidence = {
        scope: 'probe', ref: `kimi-config#sha256=${enablement.config_fingerprint ?? 'unknown'}`,
        sha256: fingerprint, session_id: null, observed_at: enablement.observed_at ?? now,
      };
      for (const name of SURFACES) {
        if (rows[name].status === 'package-ready') {
          rows[name] = capability(name, 'probe-observed', fingerprint, evidence);
        }
      }
    } else if (rows.skills.status === 'package-ready' || fallbackOnly) {
      const reason = enablement.status === 'disabled' ? 'PLUGIN_DISABLED' : 'ENABLEMENT_ABSENT';
      for (const name of SURFACES) {
        if (rows[name].status === 'package-ready') rows[name] = missing(name, reason, fingerprint);
      }
    }
  }
  if (receipt === null || receipt === undefined) {
    return { product: 'Kimi', outcome: enablement && enablement.status === 'enabled' ? 'observed' : 'degraded', reason_code: null,
      capabilities: SURFACES.map((name) => rows[name]) };
  }
  const freshness = currentObservation(receipt, now);
  if (!freshness.current) return blockedMatrix(freshness.reason, fingerprint);
  if (receipt.status !== 'observed') return blockedMatrix('OBSERVATION_STATUS_INVALID', fingerprint);
  if (receipt.workspace_clean !== true) return blockedMatrix('WORKSPACE_DIRTY', fingerprint);
  if (receipt.product !== 'Kimi' || receipt.version !== version || receipt.build !== build || receipt.session_id !== sessionId
    || receipt.manifest_fingerprint !== fingerprint || receipt.route !== [...selected][0] || !Array.isArray(receipt.surfaces)) {
    return blockedMatrix('KIMI_OBSERVATION_INVALID', fingerprint);
  }
  const observed = new Set(receipt.surfaces);
  const sessionEvidence = {
    scope: 'current-session', ref: `lazykimi-plugin/kimi.plugin.json#sha256=${fingerprint}`,
    sha256: fingerprint, session_id: sessionId, observed_at: receipt.observed_at,
  };
  return {
    product: 'Kimi', outcome: 'observed', reason_code: null,
    capabilities: SURFACES.map((name) => observed.has(name)
      ? capability(name, 'current-session-ready', fingerprint, sessionEvidence)
      : missing(name, 'SURFACE_NOT_OBSERVED', fingerprint)),
  };
}

module.exports = {
  CAPABILITY_STATUSES,
  SURFACES,
  buildKimiMatrix,
  discoverKimiBinary,
  observeKimiEnablement,
  probeKimi,
};
