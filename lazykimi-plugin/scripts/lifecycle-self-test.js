'use strict';

const { verifyStagedPackage } = require('./lifecycle/bootstrap');

const result = verifyStagedPackage(process.cwd(), 'LazyKimi');
process.stdout.write(`${JSON.stringify({ product: 'LazyKimi', status: 'passed', version: result.version })}\n`);
