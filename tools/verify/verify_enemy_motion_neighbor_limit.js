const fs = require("fs");
const path = require("path");

const root = process.cwd();

function readProjectFile(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function extractFunction(source, name) {
  const marker = `func ${name}`;
  const start = source.indexOf(marker);
  if (start < 0) {
    throw new Error(`Missing function ${name}`);
  }
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next < 0 ? source.length : next);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const enemyBase = readProjectFile("scripts/enemies/enemy_base.gd");
const enemyBehavior = readProjectFile("scripts/enemies/behaviors/enemy_behavior.gd");
const enemyStatusDisplay = readProjectFile("scripts/enemies/enemy_status_display_controller.gd");
const enemyTimelineController = readProjectFile("scripts/enemies/timeline/enemy_timeline_controller.gd");
const areaEffect = readProjectFile("scripts/combat/area_effect.gd");
const playerController = readProjectFile("scripts/player/player_controller.gd");
const skillsData = JSON.parse(readProjectFile("data/skills/skills.json"));
const wavesData = JSON.parse(readProjectFile("data/waves/waves.json"));
const enemyScene = readProjectFile("scenes/enemies/enemy.tscn");
const bossScene = readProjectFile("scenes/enemies/boss.tscn");

const limitActorMotion = extractFunction(enemyBase, "_limit_actor_motion");
const physicsProcess = extractFunction(enemyBase, "_physics_process");
const separationDirection = extractFunction(enemyBehavior, "_get_separation_direction");
const meleeCrowdCheck = extractFunction(enemyBehavior, "_idle_if_melee_space_blocked");
const contactDamage = extractFunction(enemyBase, "_apply_contact_damage");
const runtimeTick = extractFunction(enemyBase, "_update_enemy_runtime_tick");
const statusDisplaySetup = extractFunction(enemyStatusDisplay, "setup");
const timelineProcess = extractFunction(enemyTimelineController, "process");
const areaCollisionSetup = extractFunction(areaEffect, "_enable_area_collision");
const areaTargetCollection = extractFunction(areaEffect, "_collect_tick_damage_targets");
const areaPhysicsProcess = extractFunction(areaEffect, "_physics_process");
const areaSetup = extractFunction(areaEffect, "setup");
const playerApplyMovement = extractFunction(playerController, "_apply_dash_or_walk_velocity");
const playerLimitActorMotion = extractFunction(playerController, "_limit_actor_motion");

for (const [name, body] of [
  ["EnemyBase._limit_actor_motion", limitActorMotion],
  ["EnemyBehavior._get_separation_direction", separationDirection],
  ["EnemyBehavior._idle_if_melee_space_blocked", meleeCrowdCheck],
]) {
  assert(
    !body.includes("get_nodes_in_group"),
    `${name} must use bounded nearby-enemy candidates instead of scanning all enemies every physics frame.`
  );
}

assert(
  enemyBase.includes("_nearby_enemies("),
  "EnemyBase should expose a nearby-enemy helper for movement limiting."
);

assert(
  enemyBehavior.includes("_nearby_enemies("),
  "EnemyBehavior should use the nearby-enemy helper for separation and crowd checks."
);

assert(
  enemyScene.includes("collision_mask = 0"),
  "Regular enemies should keep their layer for hit detection but disable their own physics collision mask."
);

assert(
  bossScene.includes("collision_mask = 0"),
  "Boss enemies should keep their layer for hit detection but disable their own physics collision mask."
);

assert(
  contactDamage.includes("_is_target_touching_contact_radius"),
  "Enemy contact damage should use a distance/radius check instead of relying on move_and_slide collisions."
);

assert(
  !contactDamage.includes("get_slide_collision_count") && !contactDamage.includes("get_slide_collision"),
  "Enemy contact damage should not inspect slide collisions after enemy physics collision masks are disabled."
);

assert(
  !runtimeTick.includes("_update_debug_health_display"),
  "Enemy per-frame runtime tick must not refresh debug HP bars; update them only when health changes."
);

assert(
  !statusDisplaySetup.includes("_ensure_label"),
  "Enemy status labels should be created lazily only when an enemy has visible statuses."
);

assert(
  physicsProcess.includes("_should_limit_actor_motion"),
  "Enemy motion limiting should be gated so crowded scenes do not run avoidance for every enemy on every physics frame."
);

assert(
  limitActorMotion.includes("_should_skip_enemy_neighbor_motion_limit"),
  "Enemy motion limiting should skip enemy-neighbor avoidance under crowded LOD while still checking player contact."
);

assert(
  enemyBehavior.includes("_should_skip_melee_neighbor_logic"),
  "Melee behavior should skip crowd/separation neighbor queries under crowded LOD."
);

assert(
  physicsProcess.includes("_should_update_enemy_visual_state"),
  "Enemy visual state updates should be gated so offscreen/crowded normal enemies do not refresh every physics frame."
);

assert(
  physicsProcess.includes("_should_skip_crowded_runtime_frame"),
  "Far normal enemies should skip full runtime frames under heavy crowding."
);

assert(
  enemyTimelineController.includes("_despawn_cooldown"),
  "Enemy timeline far-despawn scans should be throttled instead of scanning all enemies every physics frame."
);

assert(
  !timelineProcess.includes("_owner.call(\"_despawn_far_enemies\")"),
  "Enemy timeline process must not despawn-scan every physics frame; use a cooldown-gated helper."
);

assert(
  !areaCollisionSetup.includes("monitoring\", true") && !areaCollisionSetup.includes("monitoring = true"),
  "Player area effects should not enable Area2D monitoring; tick damage should use bounded scripted queries to avoid physics broadphase churn."
);

assert(
  !areaTargetCollection.includes("get_overlapping_bodies"),
  "AreaEffect target collection should not depend on Area2D overlap state for enemy damage ticks."
);

assert(
  areaPhysicsProcess.includes("_queue_programmatic_visual_redraw"),
  "AreaEffect programmatic visuals should throttle queue_redraw instead of redrawing every physics frame."
);

assert(
  areaSetup.includes("_enforce_max_active"),
  "AreaEffect setup should enforce max_active after deferred spawns are added so same-frame batches cannot exceed caps."
);

assert(
  areaEffect.includes("area_id") &&
    areaEffect.includes("grouping_key") &&
    areaEffect.includes('area.get("area_id")'),
  "AreaEffect max_active should group by area_id first so projectile-specific source ids cannot bypass ground-effect caps."
);

assert(
  !playerApplyMovement.includes("_limit_actor_motion"),
  "Player walk movement should not body-block against every enemy each physics frame."
);

assert(
  !playerLimitActorMotion.includes("get_nodes_in_group"),
  "Player motion limiting must not scan all enemies every physics frame."
);

function visit(value, visitor) {
  if (Array.isArray(value)) {
    for (const item of value) visit(item, visitor);
    return;
  }
  if (value && typeof value === "object") {
    visitor(value);
    for (const item of Object.values(value)) visit(item, visitor);
  }
}

const blazingRunAreas = [];
const cappedAreaExpectations = new Map([
  ["blazing_run_path", 2],
  ["meteor_burning_ground", 2],
  ["lava_rift", 1],
  ["divine_barrier_field", 1],
]);
visit(skillsData, (node) => {
  if (node.type === "spawn_area" && cappedAreaExpectations.has(node.area_id)) {
    blazingRunAreas.push(node);
  }
});

assert(blazingRunAreas.length > 0, "Expected capped fire area definitions in skills data.");
for (const area of blazingRunAreas) {
  const cap = cappedAreaExpectations.get(area.area_id);
  assert(
    Number(area.max_active || 0) > 0 && Number(area.max_active) <= cap,
    `${area.area_id} should cap active fire ground areas to avoid late-run AreaEffect buildup.`
  );
  if (area.area_id === "blazing_run_path") {
    assert(
      Number(area.max_targets || 0) > 0 && Number(area.max_targets) <= 6,
      "blazing_run_path should tightly cap tick targets because dash trails can overlap in dense crowds."
    );
  } else if (["meteor_burning_ground", "lava_rift"].includes(area.area_id)) {
    assert(
      Number(area.max_targets || 0) > 0 && Number(area.max_targets) <= 12,
      `${area.area_id} should cap tick targets so fire ground effects do not multiply dense-crowd status work.`
    );
  }
}

assert(
  Number(wavesData.spawn_rules?.max_normal_enemies_alive || 0) > 0 &&
    Number(wavesData.spawn_rules.max_normal_enemies_alive) <= 40,
  "Wave spawn rules should cap normal enemies at 40 to stay within the verified real-run performance budget."
);

console.log("verify_enemy_motion_neighbor_limit: PASS");
