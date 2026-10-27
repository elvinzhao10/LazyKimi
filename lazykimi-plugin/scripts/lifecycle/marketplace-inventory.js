'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { LifecycleError } = require('./errors');
const { safeFile } = require('./files');

const ERROR_CODE = 'MARKETPLACE_PAYLOAD_INVALID';
const byteOrder = (left, right) => Buffer.compare(Buffer.from(left), Buffer.from(right));
const digest = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');

function excludedEntry(name) {
  return name === '.gitkeep' || name === '__pycache__' || name.endsWith('.pyc');
}

function safeDirectory(pluginRoot, relative) {
  const parts = relative === '.' ? [] : relative.split('/');
  if (parts.some((part) => part === '' || part === '.' || part === '..' || part.includes('\\'))) {
    throw new LifecycleError(ERROR_CODE, `unsafe payload path: ${relative}`);
  }
  let directory = pluginRoot;
  for (const part of ['', ...parts]) {
    directory = path.join(directory, part);
    const stat = fs.lstatSync(directory);
    if (!stat.isDirectory() || stat.isSymbolicLink()) {
      throw new LifecycleError(ERROR_CODE, `unsafe payload directory: ${relative}`);
    }
  }
  return directory;
}

function inventory(pluginRoot, policy) {
  const records = [];
  const walk = (relative, included = true) => {
    const directory = safeDirectory(pluginRoot, relative);
    for (const name of fs.readdirSync(directory).sort(byteOrder)) {
      const child = path.posix.join(relative, name);
      const absolute = path.join(pluginRoot, child);
      const stat = fs.lstatSync(absolute);
      const includeChild = included && !excludedEntry(name);
      if (stat.isDirectory() && !stat.isSymbolicLink()) walk(child, includeChild);
      else if (stat.isFile() && stat.nlink === 1) {
        if (includeChild) records.push({ path: child, sha256: digest(safeFile(absolute, ERROR_CODE).bytes) });
      } else {
        throw new LifecycleError(ERROR_CODE, `canonical payload must contain only regular files: ${child}`);
      }
    }
  };
  try {
    for (const root of policy.roots) walk(root);
    for (const relative of policy.files) {
      safeDirectory(pluginRoot, path.posix.dirname(relative));
      records.push({ path: relative, sha256: digest(safeFile(path.join(pluginRoot, relative), ERROR_CODE).bytes) });
    }
  } catch (error) {
    if (error instanceof LifecycleError) throw error;
    throw new LifecycleError(ERROR_CODE, 'canonical payload unavailable', error);
  }
  return records.sort((left, right) => byteOrder(left.path, right.path));
}

module.exports = { excludedEntry, inventory };
