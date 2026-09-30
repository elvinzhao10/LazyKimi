#!/usr/bin/env node
'use strict';

// Family-named refresh entry point. LazyKimi keeps ONE canonical contract
// generator — scripts/lazykimi-regenerate-marketplace-contract.js (ported in
// the per-host contracts task) — which already implements the v1.3.3
// metadata-drift rule (counts and mirrors derived from canonical files, no
// hand-maintained duplicates) plus the deterministic payload inventory and
// the Kimi route table. This wrapper delegates to it so family tooling that
// addresses `refresh-marketplace-contract.js` by name keeps working.

const { spawnSync } = require('node:child_process');
const path = require('node:path');

const canonical = path.join(__dirname, 'lazykimi-regenerate-marketplace-contract.js');
const result = spawnSync(process.execPath, [canonical], { stdio: 'inherit' });
process.exitCode = result.status ?? 1;
