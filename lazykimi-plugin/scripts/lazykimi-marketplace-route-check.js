#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { validateInstalledMarketplacePackage, validateMarketplaceRoutes } = require('./lifecycle/marketplace-routes');

// Release root = the repository root that contains lazykimi-plugin/ and its
// marketplace.json v2. Defaults to two levels above this script; without
// release metadata the checker validates the installed package boundary
// itself. Package identity is derived from the manifest/contract content
// (plugin@marketplace), never from the containing directory leaf, so
// versioned caches and renamed checkouts keep a stable identity.
const hasExplicitReleaseRoot = process.argv[2] !== undefined;
const releaseRoot = hasExplicitReleaseRoot ? path.resolve(process.argv[2]) : path.resolve(__dirname, '..', '..');
try {
  const result = hasExplicitReleaseRoot
    ? validateMarketplaceRoutes(releaseRoot)
    : fs.existsSync(path.join(releaseRoot, 'lazykimi-plugin'))
      ? validateMarketplaceRoutes(releaseRoot)
      : validateInstalledMarketplacePackage(path.resolve(__dirname, '..'));
  process.stdout.write(`${JSON.stringify({
    status: 'pass',
    version: result.version,
    marketplace: result.marketplace_name,
    plugin: result.plugin,
    install_id: result.install_id,
    payload_files: result.payload_inventory.length,
  })}\n`);
} catch (error) {
  process.stderr.write(`${JSON.stringify({ error: error.code || 'MARKETPLACE_ROUTE_INVALID', message: error.message })}\n`);
  process.exitCode = 1;
}
