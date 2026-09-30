#!/usr/bin/env node
'use strict';

// permission-record.js — Kimi PermissionRequest / PermissionResult advisory
// consumer. Ported from the LazyZCode v1.3.3 lifecycle-event.js consumer and
// split per the contracts/kimi-hook-consumers.v1.json split: PermissionRequest
// records the request, PermissionResult records the decision into the same
// normalized ledger. Behaviour: whitelist the event fields, redact
// secret-like keys/values, omit transcript_path, and append a normalized
// record under the workspace .lazykimi/ state logs — best-effort.
//
// Kimi output contract: print NOTHING on stdout (any stdout is parsed as
// strict JSON); diagnostics go to stderr. Advisory consumer: ALWAYS exits 0
// (never denies; Kimi deny would be exit code 2, which this hook must not use).

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const PLUGIN_ROOT = path.resolve(__dirname, '..');
const CONTRACT_PATH = path.join(PLUGIN_ROOT, 'contracts', 'kimi-hook-consumers.v1.json');
const EVENT = process.argv[2] === 'PermissionResult' ? 'PermissionResult' : 'PermissionRequest';
const SECRET_KEY = /(?:^|_)(?:token|password|secret|credential|grant|api_?key|private_?key|remote_?key|raw_?prompt|prompt|private_?transcript|transcript|authorization|oauth)(?:$|_)/i;
const SECRET_VALUE = /(?:\bBearer\s+[A-Za-z0-9._-]{10,}|\bsk-[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)/i;
const PATH_FIELDS = new Set(['path', 'file_path', 'old_cwd', 'new_cwd', 'worktree_path']);
const OMITTED_COMMON_FIELDS = new Set(['transcript_path']);
const WHITELIST = EVENT === 'PermissionResult'
  ? ['request_id', 'tool_name', 'outcome', 'decision', 'reason']
  : ['request_id', 'tool_name', 'reason'];
let MAX_INPUT_BYTES = 1048576;
let ACTIVE_STATUSES = new Set(['active', 'paused', 'created', 'planning', 'executing', 'blocked', 'verifying', 'reviewing']);
let REQUIRED_EVENT_FIELDS = [EVENT === 'PermissionResult' ? 'request_id' : 'request_id|tool_name'];
try {
  const CONTRACT = JSON.parse(fs.readFileSync(CONTRACT_PATH, 'utf8'));
  MAX_INPUT_BYTES = CONTRACT.boundary.max_payload_bytes;
  if (Array.isArray(CONTRACT.boundary.active_statuses)) ACTIVE_STATUSES = new Set(CONTRACT.boundary.active_statuses);
  const consumer = CONTRACT.events[EVENT];
  if (consumer && Array.isArray(consumer.required_fields)) REQUIRED_EVENT_FIELDS = consumer.required_fields;
} catch (error) {
  process.stderr.write(JSON.stringify({ status: 'error', reason: 'contract_unavailable', detail: String(error && error.message) }) + '\n');
}

function digest(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function isSecretKey(key) {
  return SECRET_KEY.test(key) && !OMITTED_COMMON_FIELDS.has(key);
}

function redact(value, location = '$') {
  if (Array.isArray(value)) return value.map((item, index) => redact(item, `${location}[${index}]`));
  if (value !== null && typeof value === 'object') {
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      if (isSecretKey(key)) continue; // omit secret-like fields entirely
      out[key] = redact(item, `${location}.${key}`);
    }
    return out;
  }
  if (typeof value === 'string') {
    let redacted = value.replace(SECRET_VALUE, '[redacted]');
    if (redacted !== value) return { redacted: true, sha256: digest(value), bytes: Buffer.byteLength(value) };
    return redacted;
  }
  return value;
}

function within(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
}

function summarized(value) {
  return { redacted: true, sha256: digest(value), bytes: Buffer.byteLength(value) };
}

function normalizedPath(value, projectRoot) {
  const resolved = path.resolve(projectRoot, value);
  return within(projectRoot, resolved) ? { project_relative: path.relative(projectRoot, resolved) || '.' } : summarized(value);
}

function activeRun(projectRoot) {
  const runsRoot = path.join(projectRoot, '.lazykimi', 'runs');
  let entries;
  try {
    entries = fs.readdirSync(runsRoot, { withFileTypes: true }).filter(entry => entry.isDirectory()).sort((a, b) => a.name.localeCompare(b.name));
  } catch {
    return null;
  }
  for (const entry of entries) {
    const statePath = path.join(runsRoot, entry.name, 'state.json');
    try {
      const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
      if (state !== null && typeof state === 'object' && ACTIVE_STATUSES.has(state.status)) return { state, statePath };
    } catch {}
  }
  return null;
}

function atomicWrite(target, value) {
  const temporary = `${target}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, target);
}

function outcomeOf(normalizedPayload) {
  if (EVENT === 'PermissionRequest') return 'requested';
  const outcome = normalizedPayload.outcome !== undefined ? normalizedPayload.outcome : normalizedPayload.decision;
  if (typeof outcome === 'string' && outcome.length > 0) return outcome.slice(0, 32).toLowerCase();
  return 'unknown';
}

function updateState(active, eventId, occurredAt, outcome) {
  if (active === null) return;
  const lifecycle = active.state.hook_lifecycle !== null && typeof active.state.hook_lifecycle === 'object' && !Array.isArray(active.state.hook_lifecycle)
    ? { ...active.state.hook_lifecycle }
    : {};
  lifecycle.last_event = { event: EVENT, event_id: eventId, occurred_at: occurredAt };
  lifecycle.last_permission = { event_id: eventId, outcome, completion_authority: false };
  atomicWrite(active.statePath, { ...active.state, hook_lifecycle: lifecycle });
}

function hasAnyField(payload, specification) {
  // Contract fields may carry alternatives ("request_id|tool_name").
  return specification.split('|').some(field => typeof payload[field] === 'string' && payload[field].length > 0);
}

function processEvent() {
  let input = fs.readFileSync(0);
  if (input.length > MAX_INPUT_BYTES) {
    process.stderr.write(JSON.stringify({ status: 'rejected', reason: 'payload_too_large', detail: `input exceeds ${MAX_INPUT_BYTES} bytes` }) + '\n');
    return;
  }
  let payload;
  try {
    payload = JSON.parse(input.toString('utf8'));
  } catch {
    process.stderr.write(JSON.stringify({ status: 'rejected', reason: 'malformed_json', detail: 'stdin must contain one JSON object' }) + '\n');
    return;
  }
  if (payload === null || Array.isArray(payload) || typeof payload !== 'object') {
    process.stderr.write(JSON.stringify({ status: 'rejected', reason: 'malformed_json', detail: 'stdin must contain one JSON object' }) + '\n');
    return;
  }
  payload = redact(payload); // redacts secret-like keys/values before anything is persisted
  const event = typeof payload.hook_event_name === 'string' ? payload.hook_event_name : EVENT;
  if (event !== EVENT) {
    process.stderr.write(JSON.stringify({ status: 'rejected', reason: 'unsupported_event', detail: event }) + '\n');
    return;
  }
  const sessionId = typeof payload.session_id === 'string' && payload.session_id.length > 0 ? payload.session_id : null;
  const cwdText = typeof payload.cwd === 'string' && payload.cwd.length > 0 ? payload.cwd : process.cwd();
  if (!sessionId) {
    process.stderr.write(JSON.stringify({ status: 'rejected', reason: 'missing_common_field', detail: 'session_id is required' }) + '\n');
    return;
  }
  for (const field of REQUIRED_EVENT_FIELDS) {
    if (!hasAnyField(payload, field)) {
      process.stderr.write(JSON.stringify({ status: 'rejected', reason: 'missing_event_field', detail: `${EVENT}.${field} is required` }) + '\n');
      return;
    }
  }
  const projectRoot = path.resolve(cwdText);
  const normalizedPayload = {};
  for (const key of WHITELIST) {
    const value = payload[key];
    if (value === undefined) continue;
    if (typeof value === 'string') {
      normalizedPayload[key] = PATH_FIELDS.has(key) ? normalizedPath(value, projectRoot) : value.slice(0, 128);
    } else if (typeof value === 'number' || typeof value === 'boolean') {
      normalizedPayload[key] = value;
    }
  }
  const identity = JSON.stringify({ session_id: sessionId, event: EVENT, cwd: projectRoot, payload: normalizedPayload, delivery_id: payload.event_id || payload.delivery_id || null });
  const eventId = `evt:${digest(identity)}`;
  const sessionKey = digest(sessionId).slice(0, 24);
  const recordDir = path.join(projectRoot, '.lazykimi', 'hook-events', sessionKey);
  const recordPath = path.join(recordDir, `${eventId.slice(4)}.json`);
  try {
    fs.mkdirSync(recordDir, { recursive: true, mode: 0o700 });
    if (fs.existsSync(recordPath)) return; // duplicate delivery — already recorded
    const occurredAt = payload.occurred_at === undefined || Number.isNaN(Date.parse(payload.occurred_at))
      ? new Date().toISOString()
      : new Date(payload.occurred_at).toISOString();
    const active = activeRun(projectRoot);
    const record = {
      schema_version: 1,
      record_type: 'normalized-hook-event',
      event_id: eventId,
      session_id: sessionId,
      raw_event: EVENT,
      canonical_event: EVENT === 'PermissionRequest' ? 'permission-request' : 'permission-result',
      occurred_at: occurredAt,
      cwd: projectRoot,
      consumer: { name: EVENT === 'PermissionRequest' ? 'permission-audit' : 'permission-audit-ledger', mode: 'advisory', completion_authority: false, invalidates: [] },
      payload: normalizedPayload,
    };
    updateState(active, eventId, occurredAt, outcomeOf(normalizedPayload));
    atomicWrite(recordPath, record);
  } catch (error) {
    // Best-effort persistence: a state-log failure must never fail the hook.
    process.stderr.write(JSON.stringify({ status: 'error', reason: 'internal_error', detail: String(error && error.message) }) + '\n');
  }
}

processEvent();
process.exitCode = 0;
