// Single-owner boundary supersedes the former JSON-fallback contract.
const {verifyBoundary}=require('./data_owner_boundary');
verifyBoundary(["scripts/upgrades/upgrade_pool.gd"]);
