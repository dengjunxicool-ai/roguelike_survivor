const fs = require('fs');
const path = require('path');
const assert = require('assert');
const root = path.resolve(__dirname, '../..');
const enemies = JSON.parse(fs.readFileSync(path.join(root, 'data/enemies/enemies.json'), 'utf8')).monsters;
for (const enemy of enemies) {
  assert(['normal', 'elite', 'boss'].includes(enemy.enemy_rank), `${enemy.id}: enemy_rank is required`);
  for (const field of ['type', 'rank', 'move_speed', 'contact_damage', 'contact_interval', 'damage_interval', 'collision_radius', 'resistances']) {
    assert(!Object.hasOwn(enemy, field), `${enemy.id}: obsolete top-level ${field}`);
  }
  assert(enemy.base_stats.contact_interval > 0, `${enemy.id}: base_stats.contact_interval is required`);
  assert(!Object.hasOwn(enemy.base_stats, 'defense'), `${enemy.id}: armor is the sole defense attribute`);
}
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
for (const file of ['scripts/enemies/enemy_config_helper.gd', 'scripts/enemies/spawning/enemy_spawn_request.gd', 'scripts/enemies/spawning/enemy_spawn_service.gd']) {
  assert(!read(file).includes('enemy_type'), `${file}: old enemy_type contract returned`);
  assert(!read(file).includes('enemy_rank_override'), `${file}: use enemy_rank in requests`);
}
assert(!read('scripts/enemies/enemy_spawner.gd').includes('func _get_spawn_position'), 'spawn position belongs to EnemySpawnService');
assert(!fs.existsSync(path.join(root, 'scripts/debug/hot_path_profiler.gd')), 'profiler must live in runtime');
console.log('[verify_enemy_canonical_contract] PASS');
