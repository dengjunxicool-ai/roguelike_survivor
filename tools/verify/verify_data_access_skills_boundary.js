// Single-owner boundary supersedes the former JSON-fallback contract.
const {verifyBoundary}=require('./data_owner_boundary');
verifyBoundary(["scripts/skills/skill_manager.gd","scripts/characters/character_run_initializer.gd"]);
