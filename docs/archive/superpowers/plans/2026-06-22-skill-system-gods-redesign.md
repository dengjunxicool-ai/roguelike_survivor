# Skill System Gods Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the weapon-bound player skill flow with a god-based skill system, define all six gods, and ship 60 fully functional Fire skills with particle feedback.

**Architecture:** Add `data/gods.json` and `data/skills.json` as the player skill source of truth, then migrate loaders, loadout, upgrade generation, skill ownership, Fire runtime rules, and UI away from weapons. Keep the existing combat pipeline for damage and status resolution; add focused data-driven Fire rule handling and a reusable `GPUParticles2D` particle factory for first-pass visuals.

**Tech Stack:** Godot 4.6 GDScript, JSON data configs, Node.js validation scripts, existing `DataManager`, `GameData`, `SkillManager`, `SkillExecutor`, `SkillEventBus`, `SkillActionExecutor`, and damage/status services.

---

## Locked Decisions

- The first batch does not keep a hard active-skill-slot cap of 5; a more scientific progression cap will be added later.
- Fire skills do not hard-code skill level or active skill count to 5. `max_level` remains a data field, with values chosen by skill behavior and implementation needs.
- Passive skills do not count against active skill limits; if a later global cap is introduced, it must be configuration-driven.
- The current default starting attack is preserved as `fireball` (currently from `fire_staff.starting_skill_id`), but it is no longer resolved from a weapon. `mars_spark_missile` is the first Fire learnable skill and its particle profile, not the character starting attack.
- The workspace is not a git repository, so commit steps are replaced with verification checkpoints. Running `git status --short` currently fails with `fatal: not a git repository`.

## File Structure

- Create `data/gods.json`: six god definitions.
- Create `data/skills.json`: 60 Fire learnable skill definitions and their particle/runtime metadata, plus migrated `starting_skills` for current run-start attacks that are not offered as upgrade cards.
- Modify `data/characters.json`: remove weapon allowlists from active use and add `starting_skill_id`.
- Modify `data/upgrades.json`: remove or disable weapon-tagged level-up cards from the active pool.
- Modify `scripts/core/data_manager.gd`: load gods and skills, stop indexing player skills from old skill files.
- Modify `scripts/game/game_data.gd`: expose god and skill pools from new data, stop fallback loading old player skill files.
- Modify `scripts/characters/run_loadout.gd`: make loadouts character-only.
- Modify `scripts/characters/character_loadout_service.gd`: validate characters only.
- Modify `scripts/characters/character_run_initializer.gd`: grant character starting skill without weapon binding.
- Modify `scripts/characters/character_runtime.gd`: remove active run dependency on equipped weapon state.
- Modify `scripts/player/player_controller.gd`: remove weapon systems from setup and upgrade dispatch.
- Modify `scripts/ui/screens/character_loadout_controller.gd`: remove weapon grid and emit character-only confirmation.
- Modify `scripts/ui/screens/character_loadout_view_model_builder.gd`: build character-only view models.
- Modify `scripts/ui/ui_manager.gd` and related signal wiring: accept character-only loadout confirmation.
- Modify `scripts/ui/hud/run_hud_state_provider.gd`: remove weapon/branch HUD state.
- Modify `scripts/debug/dev_debug_panel.gd`: add a Fire skill debug entry that can select a skill card and validate runtime effects without the normal progression flow.
- Modify `scripts/upgrades/upgrade_pool.gd`: add dev-tools Fire skill option generation and replace old weapon-branch debug options.
- Modify `scripts/enemies/enemy_status_display_controller.gd` or create an enemy health bar controller: replace numeric enemy health with a visual bar.
- Modify `scripts/enemies/enemy_base.gd`: update the enemy health bar from the health-changed/damage path while preserving damage popups.
- Modify `scripts/skills/skill_definition.gd`: parse `god_id`, `rarity`, `particle`, and `runtime_rules`.
- Modify `scripts/skills/skill_instance.gd`: expose runtime rule state for passive and Fire rules.
- Modify `scripts/skills/skill_manager.gd`: support active and passive owned skills.
- Modify `scripts/skills/skill_executor.gd`: tick active skills and Fire runtime rules without weapon context.
- Modify `scripts/skills/skill_event_bus.gd`: route supported global skill events to owned active/passive skills.
- Modify `scripts/skills/skill_action_executor.gd`: remove weapon source assumptions and add particle spawn action support.
- Create `scripts/skills/fire_skill_runtime.gd`: data-driven Fire rules for status stacks, kill triggers, retaliation, shields, revive, cooldown reduction, and empowerment.
- Create `scripts/visual/skill_particle_factory.gd`: reusable `GPUParticles2D` factory.
- Create `docs/skills/runtime_families.md`: document every runtime family, required fields, runtime support, and matching skills; update it whenever a new family is added.
- Create `tools/verify_gods_and_skills_contract.js`: data contract validation.
- Create `tools/verify_skill_runtime_no_dead_cards.js`: validation that selectable skills have real runtime effects.
- Create `tools/verify_weapon_system_removed_from_main_flow.js`: static guard against active weapon dependencies.
- Create `tools/verify_fire_skill_upgrade_pool.js`: upgrade-pool data validation.
- Create `tools/verify_fire_skill_card_selection_runtime.gd`: runtime smoke that selects a skill card and attacks an enemy once.
- Create `tools/verify_fire_skill_dev_tools_entry.gd`: runtime smoke for the DevDebugPanel Fire skill debug entry.
- Create `tools/verify_enemy_health_bar.gd`: runtime smoke for the visual enemy health bar and easing.
- Create `tools/verify_fire_skill_runtime_smoke.gd`: Godot runtime smoke for representative Fire mechanics.
- Modify `package.json`: replace weapon validation scripts with god/skill validation scripts.

---

### Task 1: Data Contract Validation First

**Files:**
- Create: `tools/verify_gods_and_skills_contract.js`
- Create: `tools/json_file.js` only if the existing helper cannot parse UTF-8 JSON safely
- Test: `data/gods.json`
- Test: `data/skills.json`

- [ ] **Step 1: Write the failing validation script**

Create `tools/verify_gods_and_skills_contract.js` with this structure:

```javascript
const { readJson } = require("./json_file");

const GODS_PATH = "data/gods.json";
const SKILLS_PATH = "data/skills.json";
const EXPECTED_GODS = ["fire", "thunder", "frost", "curse", "holy", "chaos"];
const EXPECTED_FIRE_NAMES = [
  "火星飞弹", "焰舌喷吐", "灼热脉冲", "火羽刃", "熔芯箭", "余烬火花",
  "焦灼标记", "火纹护甲", "热浪推击", "火焰鞭影", "赤焰连击", "火苗复制",
  "燃血刺", "灯芯守卫", "火花反击", "灼心弱点", "火种积蓄", "烈焰回旋",
  "灰烬回收", "赤火护星", "熔屑飞溅", "焰影步", "炽热凝视", "火油亲和",
  "双焰施放", "炎爆火印", "熔炉赐印", "黑焰附着", "炼狱连弹", "日矛点名",
  "融甲灼烧", "凤凰羽护", "火鸦群袭", "熔核回响", "炽热回流", "怒焰连杀",
  "赤阳护盾", "灼魂清算", "烈焰偏转", "焦热狂热", "火刑宣告", "燃尽余波",
  "余烬循环", "焚心裁决", "炎爆序列", "灰烬复燃", "赤日连祷", "黑火债务",
  "凤凰回翔", "烈焰狂宴", "熔芯过载", "日冕爆发", "灭火成灰", "火种裂变",
  "终焰王冠", "凤凰涅槃", "太阳熔炉", "黑日降临", "万火归一", "灭世炎轮"
];

const RARITY_COUNTS = { common: 24, rare: 18, epic: 12, legendary: 6 };

function fail(message) {
  console.error(`[verify_gods_and_skills_contract] ${message}`);
  process.exitCode = 1;
}

function countBy(items, key) {
  return items.reduce((counts, item) => {
    const value = item[key];
    counts[value] = (counts[value] || 0) + 1;
    return counts;
  }, {});
}

const gods = readJson(GODS_PATH).gods || [];
const skillsData = readJson(SKILLS_PATH);
const skills = skillsData.skills || [];
const startingSkills = skillsData.starting_skills || [];

const godIds = gods.map((god) => god.id);
for (const expected of EXPECTED_GODS) {
  if (!godIds.includes(expected)) fail(`Missing god id: ${expected}`);
}
if (new Set(godIds).size !== godIds.length) fail("God ids must be unique.");
if (gods.length !== 6) fail(`Expected exactly 6 gods, got ${gods.length}.`);

const fireSkills = skills.filter((skill) => skill.god_id === "fire");
if (fireSkills.length !== 60) fail(`Expected 60 Fire skills, got ${fireSkills.length}.`);

if (fireSkills.some((skill) => skill.id === "fireball")) {
  fail("fireball is the migrated starting attack and must not count as one of the 60 Fire learnable skills.");
}
if (!startingSkills.some((skill) => skill.id === "fireball")) {
  fail("Missing migrated starting attack in data/skills.json starting_skills: fireball.");
}

const fireNames = fireSkills.map((skill) => skill.display_name);
for (const expectedName of EXPECTED_FIRE_NAMES) {
  if (!fireNames.includes(expectedName)) fail(`Missing Fire skill: ${expectedName}`);
}

const rarityCounts = countBy(fireSkills, "rarity");
for (const [rarity, expectedCount] of Object.entries(RARITY_COUNTS)) {
  if ((rarityCounts[rarity] || 0) !== expectedCount) {
    fail(`Expected ${expectedCount} ${rarity} Fire skills, got ${rarityCounts[rarity] || 0}.`);
  }
}

for (const skill of fireSkills) {
  for (const field of ["id", "display_name", "god_id", "rarity", "source_rarity", "description", "vfx_description", "build_hint", "category", "runtime_family", "tags", "particle"]) {
    if (skill[field] === undefined || skill[field] === "" || (Array.isArray(skill[field]) && skill[field].length === 0)) {
      fail(`Skill ${skill.id || skill.display_name} is missing ${field}.`);
    }
  }
}

for (const startingSkill of startingSkills) {
  if (startingSkill.offer_in_upgrade_pool !== false) {
    fail(`Starting skill ${startingSkill.id} must set offer_in_upgrade_pool: false.`);
  }
}

if (!process.exitCode) {
  console.log("[verify_gods_and_skills_contract] PASS");
}
```

- [ ] **Step 2: Run the validation and verify it fails**

Run:

```powershell
node tools\verify_gods_and_skills_contract.js
```

Expected: FAIL because `data/gods.json` and `data/skills.json` do not exist yet.

- [ ] **Step 3: Checkpoint**

Record the failing output in the task notes. Do not change production code in this task.

---

### Task 2: Add Gods And Fire Skill Data

**Files:**
- Create: `data/gods.json`
- Create: `data/skills.json`
- Create: `docs/skills/runtime_families.md`
- Modify: `data/characters.json`
- Test: `tools/verify_gods_and_skills_contract.js`

- [ ] **Step 1: Create `data/gods.json`**

Use this shape:

```json
{
  "gods": [
    {
      "id": "fire",
      "display_name": "火焰",
      "title": "火之神",
      "description": "以燃烧、爆发、弹体、反击和终局强化为核心的高压输出神系。",
      "tags": ["fire", "burn", "burst", "projectile"],
      "color": [1.0, 0.34, 0.08, 1.0],
      "implemented": true
    },
    {
      "id": "thunder",
      "display_name": "雷霆",
      "title": "雷之神",
      "description": "以电荷、连锁、过载和高频触发为核心的爆发神系。",
      "tags": ["thunder", "lightning", "charge", "chain"],
      "color": [0.28, 0.62, 1.0, 1.0],
      "implemented": false
    },
    {
      "id": "frost",
      "display_name": "寒霜",
      "title": "冰之神",
      "description": "以寒冷、减速、冻结和范围控制为核心的控制神系。",
      "tags": ["frost", "ice", "slow", "control"],
      "color": [0.55, 0.88, 1.0, 1.0],
      "implemented": false
    },
    {
      "id": "curse",
      "display_name": "诅咒",
      "title": "暗之神",
      "description": "以诅咒、债务、腐化和延迟清算为核心的持续压制神系。",
      "tags": ["curse", "dark", "debt", "corruption"],
      "color": [0.52, 0.24, 0.78, 1.0],
      "implemented": false
    },
    {
      "id": "holy",
      "display_name": "神圣",
      "title": "圣之神",
      "description": "以圣印、护盾、治疗和审判爆发为核心的攻防神系。",
      "tags": ["holy", "shield", "heal", "judgement"],
      "color": [1.0, 0.86, 0.34, 1.0],
      "implemented": false
    },
    {
      "id": "chaos",
      "display_name": "混沌",
      "title": "混沌之神",
      "description": "以随机、变异、多神系混合和概率强化为核心的变化神系。",
      "tags": ["chaos", "random", "mutation", "entropy"],
      "color": [0.68, 0.22, 0.92, 1.0],
      "implemented": false
    }
  ]
}
```

- [ ] **Step 2: Create `data/skills.json`**

Create all 60 Fire learnable skills in the top-level `skills` array. Each entry must include `runtime_family` and use one of these runtime families so validation and runtime rules can prove the card is not dead. `mars_spark_missile` is the first Fire learnable skill and its particle effect, not the character starting attack.

```json
{
  "id": "mars_spark_missile",
  "display_name": "火星飞弹",
  "god_id": "fire",
  "rarity": "common",
  "source_rarity": "普通",
  "description": "周期性发射小型火星弹，自动追踪最近敌人。",
  "vfx_description": "小颗橙红火星拖尾飞行。",
  "build_hint": "弹体数量流、燃烧铺垫",
  "category": "active",
  "runtime_family": "projectile",
  "tags": ["fire", "projectile", "homing", "burn_setup"],
  "max_level": 1,
  "base": {
    "damage": 8,
    "damage_type": "direct_magical",
    "element": "fire",
    "cooldown": 1.35,
    "range": 620,
    "projectile_speed": 360,
    "projectile_count": 3,
    "area_radius": 10
  },
  "components": [
    {"type": "cooldown", "params": {"seconds": 1.35}},
    {"type": "targeting", "params": {"mode": "nearest_enemy", "range": 620}}
  ],
  "events": [
    {
      "trigger": "on_cast",
      "actions": [
        {
          "type": "spawn_projectile",
          "params": {
            "projectile_id": "fire_spark_projectile",
            "count": 3,
            "speed": 360,
            "lifetime": 2.0,
            "collision_radius": 10,
            "homing_enabled": true,
            "homing_turn_rate": 8.5,
            "homing_seek_range": 620,
            "damage": 8,
            "damage_origin": "skill",
            "damage_type": "direct_magical",
            "element": "fire",
            "particle_profile": "fire_spark_trail"
          }
        }
      ]
    },
    {
      "trigger": "on_projectile_hit",
      "source_id": "fire_spark_projectile",
      "actions": [
        {"type": "deal_damage", "params": {"amount": 8, "damage_type": "direct_magical", "element": "fire", "can_crit": true, "damage_origin": "skill"}},
        {"type": "spawn_particles", "params": {"profile": "fire_hit_small", "position_mode": "target"}}
      ]
    }
  ],
  "particle": {"profile": "fire_spark_trail"}
}
```

Use these runtime families across the full file:

```json
["projectile", "cone_area", "radial_pulse", "orbit", "targeted_strike", "summon", "passive_modifier", "stack_mark", "kill_trigger", "damage_taken_trigger", "cooldown_reducer", "shield", "empower_next_fire", "delayed_damage", "revive_once", "fire_skill_count_scaling"]
```

If a skill description cannot be accurately expressed by the existing families, add a new family and update `docs/skills/runtime_families.md` with:

```markdown
## runtime_family_id

- Meaning: what behavior this family represents.
- Required fields: required `base`, `components`, `events`, or `runtime_rules` fields.
- Runtime support: the action, component, or runtime rule that implements it.
- Matching skills: skill ids and Chinese names using this family.
- First-pass simplification: describe any simplified-but-real behavior.
```

- [ ] **Step 3: Add the existing starting attack to characters**

Migrate the current default starting attack from `data/primary_attack.json` into `data/skills.json` under a separate top-level `starting_skills` array. The first migrated entry is `fireball`, because the current default `fire_staff.starting_skill_id` is `fireball`.

The migrated starting attack must set:

```json
{
  "id": "fireball",
  "category": "active",
  "is_starting_skill": true,
  "offer_in_upgrade_pool": false
}
```

For every current object in `data/characters.json`, add:

```json
"starting_skill_id": "fireball"
```

Do not rely on `allowed_weapon_ids` for runtime. Do not use `mars_spark_missile` as a character starting attack. The field can be removed during this task if all readers are migrated in Tasks 5-7; otherwise leave it inert until those readers are removed.

- [ ] **Step 4: Run the contract validation**

Run:

```powershell
node tools\verify_gods_and_skills_contract.js
```

Expected: PASS.

---

### Task 3: Validate No Selectable Dead Skills And Simulate Card Selection

**Files:**
- Create: `tools/verify_skill_runtime_no_dead_cards.js`
- Create: `tools/verify_fire_skill_card_selection_runtime.gd`
- Test: `data/skills.json`
- Test: representative Fire skill runtime behavior

- [ ] **Step 1: Write the failing data validation**

Create `tools/verify_skill_runtime_no_dead_cards.js`:

```javascript
const { readJson } = require("./json_file");

const skills = readJson("data/skills.json").skills || [];
const SUPPORTED_RULES = new Set([
  "fire_stack_mark",
  "fire_kill_spawn",
  "fire_cooldown_refund",
  "fire_damage_taken_retaliation",
  "fire_shield",
  "fire_empower_next",
  "fire_delayed_echo",
  "fire_revive_once",
  "fire_skill_count_scaling",
  "fire_status_expire_damage",
  "fire_projectile_split",
  "fire_burning_bonus",
  "fire_high_health_bonus"
]);

let failed = false;
function fail(message) {
  console.error(`[verify_skill_runtime_no_dead_cards] ${message}`);
  failed = true;
}

for (const skill of skills.filter((item) => item.god_id === "fire")) {
  const hasEvents = Array.isArray(skill.events) && skill.events.some((event) => Array.isArray(event.actions) && event.actions.length > 0);
  const hasComponents = Array.isArray(skill.components) && skill.components.length > 0;
  const hasModifiers = Array.isArray(skill.skill_modifiers) && skill.skill_modifiers.length > 0;
  const ruleTypes = Array.isArray(skill.runtime_rules) ? skill.runtime_rules.map((rule) => rule.type) : [];
  const hasSupportedRules = ruleTypes.some((type) => SUPPORTED_RULES.has(type));
  if (!skill.runtime_family) {
    fail(`${skill.id} is missing runtime_family.`);
  }
  if (!hasEvents && !hasModifiers && !hasSupportedRules) {
    fail(`${skill.id} has no executable events, passive modifiers, or supported runtime rules.`);
  }
  for (const type of ruleTypes) {
    if (!SUPPORTED_RULES.has(type)) {
      fail(`${skill.id} uses unsupported runtime rule: ${type}`);
    }
  }
  if (skill.category === "active" && !hasComponents) {
    fail(`${skill.id} is active but has no components.`);
  }
}

if (failed) process.exit(1);
console.log("[verify_skill_runtime_no_dead_cards] PASS");
```

- [ ] **Step 2: Run and verify failure or pass**

Run:

```powershell
node tools\verify_skill_runtime_no_dead_cards.js
```

Expected: FAIL until all 60 Fire skills have executable data or supported runtime rules.

- [ ] **Step 3: Complete data until the validation passes**

Update `data/skills.json` so each Fire skill has one of:

```json
{"events": [{"trigger": "on_cast", "actions": [{"type": "spawn_area", "params": {"area_id": "fire_pulse_area", "damage": 10, "element": "fire"}}]}]}
```

or:

```json
{"skill_modifiers": [{"stat": "damage", "op": "multiplier_add", "value": 0.08, "scope": {"domain": "damage", "element": ["fire"]}}]}
```

or:

```json
{"runtime_rules": [{"type": "fire_cooldown_refund", "params": {"status_id": "burn", "refund_seconds": 0.25}}]}
```

- [ ] **Step 4: Run validation again**

Run:

```powershell
node tools\verify_skill_runtime_no_dead_cards.js
```

Expected: PASS.

- [ ] **Step 5: Add card-selection runtime smoke**

Create `tools/verify_fire_skill_card_selection_runtime.gd` to simulate:

```text
Create DataManager.
Create Player plus SkillManager/SkillExecutor/SkillEventBus.
Create one test enemy and record its starting health.
Generate Fire skill cards from UpgradePool.
Apply the current tested skill card.
Trigger one skill attack.
Wait 0.2 to 1.0 seconds for projectile/area/status/particle resolution.
Assert enemy health decreased, a status was applied, or player/skill runtime state changed.
Assert a GPUParticles2D node was spawned.
Assert a damage popup node or DebugCombatTrace damage record exists.
Assert final damage went through the existing damage formula chain instead of direct HP editing.
```

The first version must cover at least one representative skill per runtime family. Add a smoke case whenever a new runtime family is introduced.

- [ ] **Step 6: Run the card-selection smoke**

Run:

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_card_selection_runtime.gd
```

Expected output includes:

```text
PASS card selected
PASS attack triggered
PASS projectile or particle feedback observed
PASS status or runtime effect observed when expected
PASS damage popup or damage trace observed
PASS damage formula chain used
```

---

### Task 3.5: Add Fire Skill Chain Debug Entry To Dev Tools

**Files:**
- Modify: `scripts/debug/dev_debug_panel.gd`
- Modify: `scripts/upgrades/upgrade_pool.gd`
- Create: `tools/verify_fire_skill_dev_tools_entry.gd`
- Test: current dev-tools skill selection, grant, cast, and feedback chain

- [ ] **Step 1: Write the failing Dev Tools smoke**

Create `tools/verify_fire_skill_dev_tools_entry.gd`. The script must complete this chain without entering the normal level-up flow:

```gdscript
extends SceneTree

func _init() -> void:
	root.set_meta("developer_mode_enabled", true)
	root.set_meta("debug_control_mode", true)
	root.set_meta("debug_manual_spawn_only", true)

	var ui_manager: Node = root.get_node_or_null("UIManager")
	_assert(ui_manager != null and ui_manager.has_method("start_developer_debug_run"), "UIManager developer debug run exists")
	ui_manager.call("start_developer_debug_run", {"character_id": "mage", "map_id": "default", "debug": true})
	await process_frame
	await process_frame

	var panel: Node = root.find_child("DevDebugPanel", true, false)
	_assert(panel != null, "DevDebugPanel exists")
	_assert(panel.has_method("debug_run_fire_skill_chain"), "DevDebugPanel exposes Fire skill chain debug method")

	var result: Dictionary = panel.call("debug_run_fire_skill_chain", &"mars_spark_missile")
	_assert(bool(result.get("option_generated", false)), "Fire skill debug option generated")
	_assert(bool(result.get("granted", false)), "Fire skill granted through debug card path")
	_assert(int(result.get("cast_count", 0)) >= 1, "Fire skill debug cast count")
	_assert(int(result.get("damage_record_count", 0)) >= 1, "Fire skill debug damage recorded")
	_assert(int(result.get("particle_count", 0)) >= 1, "Fire skill debug particles spawned")
	_assert(int(result.get("damage_popup_count", 0)) >= 1, "Fire skill debug damage popup shown")
	quit(0)


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	push_error("FAIL %s" % label)
	quit(1)
```

Run:

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_dev_tools_entry.gd
```

Expected: FAIL because DevDebugPanel does not yet expose `debug_run_fire_skill_chain()`.

- [ ] **Step 2: Add dev Fire skill option generation to UpgradePool**

In `scripts/upgrades/upgrade_pool.gd`, add:

```gdscript
func generate_debug_fire_skill_options(player: Node, god_id: StringName = &"fire") -> Array:
	var options: Array = []
	for skill: Dictionary in GameData.get_learnable_skill_pool():
		if StringName(String(skill.get("god_id", ""))) != god_id:
			continue
		if bool(skill.get("offer_in_upgrade_pool", true)) == false:
			continue
		options.append(_make_skill_learn_option(player, skill))
	return options
```

If the final learn-card constructor is not named `_make_skill_learn_option()`, create it in Task 7 and reuse it here. Dev tools must not invent a second grant path.

- [ ] **Step 3: Add Fire Skill Debug controls to DevDebugPanel**

In the `Skill Cards` page of `scripts/debug/dev_debug_panel.gd`, add:

- A Fire skill `OptionButton` listing all 60 Fire learnable skills.
- `Grant Fire Skill`: uses the same grant path as a real upgrade card.
- `Spawn Target`: reuses existing `_spawn_debug_enemy()`.
- `Cast Selected Fire Skill`: triggers the selected skill once.
- `Run Fire Skill Chain`: runs the full chain and writes the result to the panel log.

Add this public debug method:

```gdscript
func debug_run_fire_skill_chain(skill_id: StringName) -> Dictionary:
	# Shared by the DevDebugPanel button and the headless smoke.
	# Return real values for option_generated, granted, cast_count, damage_record_count, particle_count, damage_popup_count.
	return {}
```

The final implementation must return real statistics. Sources:

- `option_generated`: `UpgradePool.generate_debug_fire_skill_options()`.
- `granted`: the same skill-card grant path used by the upgrade UI.
- `cast_count`: `SkillExecutor.debug_cast_all_skills(trace_id)` or an equivalent single-skill debug cast.
- `damage_record_count`: records from `DebugCombatTrace.get_records(root)` where `type == "damage"`.
- `particle_count`: new `GPUParticles2D` nodes created by this trace.
- `damage_popup_count`: damage popup nodes or enemy debug display records created by the hit.

- [ ] **Step 4: Run the Dev Tools smoke**

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_dev_tools_entry.gd
```

Expected output includes:

```text
PASS UIManager developer debug run exists
PASS DevDebugPanel exists
PASS DevDebugPanel exposes Fire skill chain debug method
PASS Fire skill debug option generated
PASS Fire skill granted through debug card path
PASS Fire skill debug cast count
PASS Fire skill debug damage recorded
PASS Fire skill debug particles spawned
PASS Fire skill debug damage popup shown
```

---

### Task 4: Migrate DataManager And GameData

**Files:**
- Modify: `scripts/core/data_manager.gd`
- Modify: `scripts/game/game_data.gd`
- Test: `tools/verify_gods_and_skills_contract.js`

- [ ] **Step 1: Extend `DataManager` constants and indexes**

In `scripts/core/data_manager.gd`, add:

```gdscript
const GODS_PATH: String = "res://data/gods.json"
const SKILLS_PATH: String = "res://data/skills.json"
const GODS_KEY: String = "gods"
const SKILLS_KEY: String = "skills"

var _god_definitions: Dictionary = {}
```

- [ ] **Step 2: Clear and load new data**

In `load_all()`, clear `_god_definitions`, load `gods.json`, and index `skills.json`:

```gdscript
_god_definitions.clear()

var gods_document: Dictionary = _load_json_document(GODS_PATH)
_index_definitions(gods_document, GODS_KEY, "id", _god_definitions, GODS_PATH)

var skills_document: Dictionary = _load_json_document(SKILLS_PATH)
_index_definitions(skills_document, SKILLS_KEY, "id", _skill_definitions, SKILLS_PATH)
_index_skill_upgrade_definitions(skills_document, SKILLS_PATH)
_index_definitions(skills_document, COMBAT_OBJECTS_KEY, "id", _combat_object_definitions, SKILLS_PATH)
```

Remove the player-skill indexing calls for `PRIMARY_ATTACK_PATH` and `LEARNABLE_SKILLS_PATH`. Keep constants only if old debug tools still need them outside the main flow.

- [ ] **Step 3: Add god getters**

Add:

```gdscript
func get_god_definition(god_id: Variant) -> Dictionary:
	return _get_definition(_god_definitions, god_id)


func get_god_definitions() -> Array[Dictionary]:
	return _get_definition_values(_god_definitions)
```

- [ ] **Step 4: Add skill upgrade indexing**

Add a helper that derives learn cards from `skills`:

```gdscript
func _index_skill_upgrade_definitions(document: Dictionary, path: String) -> void:
	for skill: Dictionary in _get_dictionary_array(document, SKILLS_KEY, path):
		if not bool(skill.get("offer_in_pool", true)):
			continue
		var skill_id: String = String(skill.get("id", ""))
		if skill_id == "":
			continue
		var upgrade_id: StringName = StringName("learn_skill:%s" % skill_id)
		var card: Dictionary = {
			"id": String(upgrade_id),
			"display_name": String(skill.get("display_name", skill_id)),
			"description": String(skill.get("description", "")),
			"rarity": String(skill.get("rarity", "common")),
			"tags": skill.get("tags", []),
			"enabled": true,
			"base_weight": 0,
			"weight_decay": 1,
			"max_level": 1,
			"learn_skill_id": skill_id,
			"level_descriptions": [String(skill.get("description", ""))]
		}
		_upgrade_definitions[upgrade_id] = card
		_level_up_upgrade_definitions[upgrade_id] = card.duplicate(true)
```

- [ ] **Step 5: Mirror behavior in `GameData`**

Add `GODS_PATH`, `SKILLS_PATH`, `get_god`, `get_god_pool`, and make `get_skill`, `get_skill_pool`, `get_level_up_upgrade_pool`, and `get_upgrade` use `data/skills.json`.

Use this fallback for skills:

```gdscript
static func get_skill(skill_id: StringName) -> Dictionary:
	var data: Dictionary = _get_definition_from_data_manager("get_skill_definition", skill_id)
	if not data.is_empty():
		return data
	return _find_by_id(_get_array(SKILLS_PATH, "skills"), skill_id)
```

- [ ] **Step 6: Run validations**

Run:

```powershell
node tools\verify_gods_and_skills_contract.js
node tools\verify_skill_runtime_no_dead_cards.js
```

Expected: PASS.

---

### Task 5: Make Loadout Character-Only And Preserve Starting Skill

**Files:**
- Modify: `scripts/characters/run_loadout.gd`
- Modify: `scripts/characters/character_loadout_service.gd`
- Modify: `scripts/characters/character_run_initializer.gd`
- Modify: `scripts/characters/character_runtime.gd`
- Modify: `data/characters.json`
- Test: `tools/verify_weapon_system_removed_from_main_flow.js`

- [ ] **Step 1: Write static guard first**

Create `tools/verify_weapon_system_removed_from_main_flow.js`:

```javascript
const fs = require("fs");

const forbidden = [
  { file: "scripts/characters/run_loadout.gd", patterns: ["weapon_id", "weapon_data", "weapon_definition"] },
  { file: "scripts/characters/character_loadout_service.gd", patterns: ["get_allowed_weapon_ids", "validate_loadout(character_id: Variant, weapon_id", "GameData.get_weapon"] },
  { file: "scripts/characters/character_run_initializer.gd", patterns: ["WeaponSkillBinding", "WeaponEquipSystem", "bind_starting_skill", "lock_equipped_weapon"] },
  { file: "scripts/player/player_controller.gd", patterns: ["WeaponEquipSystemScript", "WeaponSkillBindingScript", "WeaponBranchSystemScript", "WeaponVisualScript"] },
  { file: "scripts/upgrades/upgrade_pool.gd", patterns: ["branch_choice", "WeaponBranchSystem", "get_equipped_weapon"] }
];

let failed = false;
for (const entry of forbidden) {
  const text = fs.readFileSync(entry.file, "utf8");
  for (const pattern of entry.patterns) {
    if (text.includes(pattern)) {
      console.error(`[verify_weapon_system_removed_from_main_flow] ${entry.file} still contains ${pattern}`);
      failed = true;
    }
  }
}

if (failed) process.exit(1);
console.log("[verify_weapon_system_removed_from_main_flow] PASS");
```

- [ ] **Step 2: Run and verify failure**

Run:

```powershell
node tools\verify_weapon_system_removed_from_main_flow.js
```

Expected: FAIL because loadout and player still reference weapons.

- [ ] **Step 3: Rewrite `RunLoadout`**

Replace the model with:

```gdscript
extends RefCounted
class_name RunLoadout

const CharacterDefinitionScript: Script = preload("res://scripts/characters/character_definition.gd")

var character_id: StringName = &""
var character_data: Dictionary = {}
var character_definition: RefCounted


func _init(character_config: Dictionary = {}) -> void:
	character_data = character_config.duplicate(true)
	character_id = StringName(String(character_data.get("id", "")))
	if not character_data.is_empty():
		character_definition = CharacterDefinitionScript.new(character_data)


func is_valid() -> bool:
	return character_id != &"" and not character_data.is_empty()
```

- [ ] **Step 4: Rewrite `CharacterLoadoutService`**

Keep these public methods:

```gdscript
static func validate_loadout(character_id: Variant) -> bool:
	return get_validation_errors(character_id).is_empty()


static func get_validation_errors(character_id: Variant) -> Array[String]:
	var errors: Array[String] = []
	var resolved_character_id: StringName = StringName(String(character_id))
	if resolved_character_id == &"":
		errors.append("Missing character_id.")
		return errors
	var character: Dictionary = GameData.get_character(resolved_character_id)
	if character.is_empty():
		errors.append("Unknown character_id: %s" % String(resolved_character_id))
		return errors
	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id == &"":
		errors.append("Character %s has no starting_skill_id." % String(resolved_character_id))
	elif GameData.get_skill(starting_skill_id).is_empty():
		errors.append("Character %s references missing starting_skill_id: %s" % [String(resolved_character_id), String(starting_skill_id)])
	return errors


static func build_loadout(character_id: Variant) -> RefCounted:
	var resolved_character_id: StringName = StringName(String(character_id))
	if not validate_loadout(resolved_character_id):
		return null
	return RunLoadoutScript.new(GameData.get_character(resolved_character_id))
```

- [ ] **Step 5: Update `CharacterRunInitializer`**

Replace weapon initialization and binding with:

```gdscript
func initialize_loadout(player: Node, loadout: RefCounted) -> bool:
	if loadout == null or not bool(loadout.call("is_valid")) or player == null:
		return false
	var runtime: Node = player.get_node_or_null("CharacterRuntime")
	if runtime == null:
		return false
	var character_id: StringName = StringName(String(loadout.get("character_id")))
	var initialized: bool = bool(runtime.call("initialize", String(character_id)))
	if not initialized:
		push_warning("[CharacterRunInitializer] Failed to initialize character runtime for %s." % String(character_id))
		return false
	_initialize_trait_system(player, runtime)
	return true


func configure_starting_skills(player: Node) -> void:
	if player == null:
		return
	var skill_manager: Node = player.get_node_or_null("SkillManager")
	if skill_manager == null:
		return
	if skill_manager.has_method("clear_skills"):
		skill_manager.call("clear_skills")
	var character: Dictionary = GameData.get_character(StringName(String(player.get("selected_character_id"))))
	var starting_skill_id: StringName = StringName(String(character.get("starting_skill_id", "")))
	if starting_skill_id != &"" and skill_manager.has_method("add_skill"):
		skill_manager.call("add_skill", starting_skill_id)
	_connect_trait_skill_events(player)
```

- [ ] **Step 6: Update `CharacterRuntime`**

Change `initialize()` to accept only `character_id`, remove active run dependencies on equipped weapon fields, and keep trait access working from character data.

- [ ] **Step 7: Run static guard**

Run:

```powershell
node tools\verify_weapon_system_removed_from_main_flow.js
```

Expected: still FAIL until Player is migrated in Task 6 and UpgradePool is migrated in Task 7.

---

### Task 6: Remove Weapon Systems From Player And UI

**Files:**
- Modify: `scripts/player/player_controller.gd`
- Modify: `scripts/ui/screens/character_loadout_controller.gd`
- Modify: `scripts/ui/screens/character_loadout_view_model_builder.gd`
- Modify: `scripts/ui/screens/character_loadout_text.gd`
- Modify: `scripts/ui/ui_manager.gd`
- Modify: `scripts/ui/hud/run_hud_state_provider.gd`
- Test: `tools/verify_weapon_system_removed_from_main_flow.js`

- [ ] **Step 1: Remove weapon child systems from `PlayerController`**

Delete preloads and child creation for:

```gdscript
WeaponEquipSystemScript
WeaponSkillBindingScript
WeaponBranchSystemScript
WeaponVisualScript
```

Set the exported defaults to:

```gdscript
@export var selected_character_id: StringName = &"mage"
@export var load_config_from_data: bool = true
```

Change `_ready()` to:

```gdscript
var default_loadout: RefCounted = CharacterLoadoutServiceScript.build_loadout(selected_character_id)
```

Change `reset_for_loadout()` to set only `selected_character_id`.

- [ ] **Step 2: Remove branch and skill-level weapon upgrade dispatch**

In `apply_upgrade()`, remove `branch_choice:` handling. Keep:

```gdscript
if upgrade_id_text.begins_with(SKILL_LEVEL_UP_OPTION_PREFIX):
	if _apply_skill_level_up_upgrade(upgrade_id_text, dev_enabled):
		upgrade_applied.emit(upgrade_id)
	return
```

Update `_upgrade_skill()` so it only calls `SkillManager.upgrade_skill` and no longer calls `WeaponBranchSystem`.

- [ ] **Step 3: Make character selection UI emit character only**

In `CharacterLoadoutController`, change:

```gdscript
signal loadout_confirmed(character_id: StringName)
var selected_character_id: StringName = &"mage"
```

Remove `_build_weapon_panel`, `_weapon_grid`, weapon detail labels, `_toggle_weapon_selection`, `_show_weapon_details`, and weapon validation from `_confirm_loadout()`.

- [ ] **Step 4: Make view model character-only**

In `CharacterLoadoutViewModelBuilder.build()`, use:

```gdscript
func build(character_id: StringName, carousel_index: int, sync_index_from_selected: bool) -> Dictionary:
```

Return no `weapon_id` or `weapons`. Details include role, stats, trait, drawback, difficulty, lock, and starting skill text from `starting_skill_id`.

- [ ] **Step 5: Update UIManager signal path**

Update `loadout_confirmed` connections and handlers so they pass only `character_id`. Build run loadouts with:

```gdscript
CharacterLoadoutServiceScript.build_loadout(character_id)
```

- [ ] **Step 6: Remove weapon HUD state**

In `RunHudStateProvider`, remove weapon name, branch, evolution, and current weapon skill fields. Keep current active skills if already shown.

- [ ] **Step 7: Run static guard**

Run:

```powershell
node tools\verify_weapon_system_removed_from_main_flow.js
```

Expected: FAIL only for `UpgradePool` until Task 7, or PASS if all forbidden references are gone.

---

### Task 7: Rewrite UpgradePool As Skill-First

**Files:**
- Modify: `scripts/upgrades/upgrade_pool.gd`
- Modify: `scripts/upgrades/upgrade_offer_policy.gd`
- Modify: `data/upgrades.json`
- Create: `tools/verify_fire_skill_upgrade_pool.js`
- Test: `tools/verify_weapon_system_removed_from_main_flow.js`

- [ ] **Step 1: Write upgrade pool data validation**

Create `tools/verify_fire_skill_upgrade_pool.js`:

```javascript
const { readJson } = require("./json_file");

const skills = readJson("data/skills.json").skills || [];
const upgrades = readJson("data/upgrades.json");
let failed = false;
function fail(message) {
  console.error(`[verify_fire_skill_upgrade_pool] ${message}`);
  failed = true;
}

for (const upgrade of upgrades.level_up_upgrades || []) {
  const tags = upgrade.tags || [];
  const required = upgrade.required_weapon_tags || [];
  if (tags.includes("weapon")) fail(`${upgrade.id} still has weapon tag.`);
  if (required.length > 0) fail(`${upgrade.id} still requires weapon tags.`);
}

const fireSkills = skills.filter((skill) => skill.god_id === "fire");
for (const skill of fireSkills) {
  if (skill.offer_in_pool === false) fail(`${skill.id} is blocked from the pool.`);
}

if (failed) process.exit(1);
console.log("[verify_fire_skill_upgrade_pool] PASS");
```

- [ ] **Step 2: Run and verify failure**

Run:

```powershell
node tools\verify_fire_skill_upgrade_pool.js
```

Expected: FAIL because existing upgrades include weapon tags.

- [ ] **Step 3: Remove branch stage logic from `UpgradePool`**

Delete `_build_branch_choice_options`, `_select_branch_choice_stage_options`, `_get_weapon_branch_system`, `_get_current_weapon_id`, `_get_current_weapon_skill_id`, `_is_current_weapon_skill`, and debug full weapon option functions.

`generate_options()` should become:

```gdscript
func generate_options(player: Node, count: int = 3) -> Array:
	var requested_count: int = maxi(count, 0)
	if requested_count <= 0:
		return []
	return _select_growth_stage_options(player, requested_count)
```

- [ ] **Step 4: Generate learn and upgrade cards from skills**

Use `GameData.get_skill_pool()` for learn cards. Learn card option ids stay compatible with Player dispatch:

```gdscript
"id": "level_up_upgrade:learn_skill:%s" % String(skill.get("id", ""))
```

Owned upgrade cards use:

```gdscript
"id": "skill_level_up:%s" % String(skill_id)
```

- [ ] **Step 5: Keep rarity weights aligned**

Use existing `rarity_weights` unchanged:

```gdscript
var rarity_weights: Dictionary = {
	"common": 60.0,
	"rare": 28.0,
	"epic": 10.0,
	"legendary": 2.0
}
```

- [ ] **Step 6: Clean `data/upgrades.json`**

Remove or disable level-up upgrades whose purpose is weapon-specific. Keep survival and generic meta cards that do not require weapon tags.

- [ ] **Step 7: Run validations**

Run:

```powershell
node tools\verify_fire_skill_upgrade_pool.js
node tools\verify_weapon_system_removed_from_main_flow.js
```

Expected: PASS.

---

### Task 8: Add Passive Skills And Runtime Rules

**Files:**
- Modify: `scripts/skills/skill_definition.gd`
- Modify: `scripts/skills/skill_instance.gd`
- Modify: `scripts/skills/skill_manager.gd`
- Modify: `scripts/skills/skill_executor.gd`
- Modify: `scripts/skills/skill_event_bus.gd`
- Create: `scripts/skills/fire_skill_runtime.gd`
- Test: `tools/verify_skill_runtime_no_dead_cards.js`

- [ ] **Step 1: Extend `SkillDefinition`**

Add fields:

```gdscript
var god_id: StringName = &""
var rarity: String = "common"
var particle: Dictionary = {}
var runtime_rules: Array[Dictionary] = []
var skill_modifiers: Array[Dictionary] = []
```

Parse them in `_init()`:

```gdscript
god_id = StringName(String(data.get("god_id", "")))
rarity = String(data.get("rarity", "common"))
particle = _parse_dictionary(data.get("particle", {}))
runtime_rules = _parse_dictionary_array(data.get("runtime_rules", []))
skill_modifiers = _parse_dictionary_array(data.get("skill_modifiers", []))
```

- [ ] **Step 2: Extend `SkillManager` for passive ownership**

Add:

```gdscript
var passive_skills: Dictionary = {}
```

Update `add_skill()`:

```gdscript
if category == "passive":
	passive_skills[id] = skill_instance
	learned_skill_ids[id] = true
	_apply_passive_skill_modifiers(skill_instance)
	skill_added.emit(id)
	skill_changed.emit()
	return true
```

Add:

```gdscript
func get_owned_skill_instances() -> Array:
	var owned: Array = []
	owned.append_array(active_skills.values())
	owned.append_array(passive_skills.values())
	return owned
```

Keep `get_all_skills()` returning active skills for `SkillExecutor`; add separate calls where global event routing needs passives.

- [ ] **Step 3: Add Fire runtime node**

Create `scripts/skills/fire_skill_runtime.gd` with:

```gdscript
extends RefCounted
class_name FireSkillRuntime

const SkillActionExecutorScript: Script = preload("res://scripts/skills/skill_action_executor.gd")

var _action_executor: RefCounted = SkillActionExecutorScript.new()

func tick(skill_manager: Node, delta: float, context: Dictionary) -> void:
	for skill_instance: RefCounted in _get_owned(skill_manager):
		_tick_rules(skill_instance, delta, context)


func handle_event(event_name: StringName, skill_manager: Node, context: Dictionary) -> void:
	for skill_instance: RefCounted in _get_owned(skill_manager):
		_handle_rules(event_name, skill_instance, context)
```

Implement supported rule types from Task 3. Each rule must mutate combat through existing actions or modifier stores, not direct HP edits.

- [ ] **Step 4: Wire Fire runtime**

In `SkillExecutor._physics_process()`, after ticking active skills:

```gdscript
_fire_runtime.call("tick", _skill_manager, delta, _build_global_skill_context(delta))
```

In `SkillEventBus.emit_skill_event()`, call Fire runtime for events such as `on_projectile_hit`, `on_enemy_killed`, and `on_player_damaged`.

- [ ] **Step 5: Run no-dead-card validation**

Run:

```powershell
node tools\verify_skill_runtime_no_dead_cards.js
```

Expected: PASS.

---

### Task 9: Add Particle Factory And Spawn Action

**Files:**
- Create: `scripts/visual/skill_particle_factory.gd`
- Modify: `scripts/skills/skill_action_executor.gd`
- Modify: `data/skills.json`
- Test: `tools/verify_skill_runtime_no_dead_cards.js`

- [ ] **Step 1: Create particle factory**

Create:

```gdscript
extends RefCounted
class_name SkillParticleFactory

static func spawn(parent: Node, position: Vector2, profile: Dictionary) -> GPUParticles2D:
	if parent == null:
		return null
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = String(profile.get("name", "SkillParticles"))
	particles.position = position
	particles.amount = maxi(int(profile.get("amount", 24)), 1)
	particles.lifetime = maxf(float(profile.get("lifetime", 0.35)), 0.05)
	particles.one_shot = true
	particles.emitting = true
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.initial_velocity_min = float(profile.get("velocity_min", 40.0))
	material.initial_velocity_max = float(profile.get("velocity_max", 120.0))
	material.spread = float(profile.get("spread", 180.0))
	material.scale_min = float(profile.get("scale_min", 0.5))
	material.scale_max = float(profile.get("scale_max", 1.2))
	particles.process_material = material
	particles.modulate = _color(profile.get("color", [1.0, 0.34, 0.08, 0.9]))
	parent.add_child(particles)
	particles.finished.connect(Callable(particles, "queue_free"))
	return particles


static func _color(value: Variant) -> Color:
	if value is Array and value.size() >= 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Color(1.0, 0.34, 0.08, 0.9)
```

- [ ] **Step 2: Add `spawn_particles` action**

In `SkillActionExecutor.execute_action()` add:

```gdscript
"spawn_particles":
	return _spawn_particles(params, context)
```

Implement `_spawn_particles()` using `SkillParticleFactory.spawn()`.

- [ ] **Step 3: Attach particles to Fire skills**

Every Fire skill in `data/skills.json` has a `particle` profile and at least one visual action for cast, hit, pulse, trigger, or revive.

- [ ] **Step 4: Run validation**

Run:

```powershell
node tools\verify_skill_runtime_no_dead_cards.js
```

Expected: PASS.

---

### Task 10: Runtime Smoke Tests

**Files:**
- Create: `tools/verify_fire_skill_runtime_smoke.gd`
- Modify: `package.json`
- Test: `scripts/skills/fire_skill_runtime.gd`
- Test: `scripts/visual/skill_particle_factory.gd`

- [ ] **Step 1: Create Godot smoke script**

Create `tools/verify_fire_skill_runtime_smoke.gd` to:

```gdscript
extends SceneTree

func _init() -> void:
	var data_manager: Node = preload("res://scripts/core/data_manager.gd").new()
	root.add_child(data_manager)
	data_manager.load_all()
	_assert(data_manager.get_god_definitions().size() == 6, "six gods load")
	_assert(data_manager.get_skill_definition(&"mars_spark_missile").get("god_id") == "fire", "first Fire learnable skill loads")
	_assert(data_manager.get_skill_definition(&"fireball").get("is_starting_skill") == true, "migrated starting attack loads")
	quit(0)


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	push_error("FAIL %s" % label)
	quit(1)
```

Expand this script after Task 8 and Task 9 to instantiate a player, add representative Fire skills, spawn a dummy enemy, call `debug_cast_all_skills()`, and assert damage/status/particles.

- [ ] **Step 2: Run the smoke script**

Run:

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_runtime_smoke.gd
```

Expected: PASS after loader migration, then stronger PASS after runtime checks are added.

- [ ] **Step 3: Update package scripts**

Modify `package.json`:

```json
{
  "scripts": {
    "validate:skills": "node tools\\verify_gods_and_skills_contract.js && node tools\\verify_skill_runtime_no_dead_cards.js && node tools\\verify_fire_skill_upgrade_pool.js && node tools\\verify_weapon_system_removed_from_main_flow.js",
    "test:skills:runtime": ".\\roguelike_survivor.console.exe --headless --path . --script tools\\verify_fire_skill_runtime_smoke.gd",
    "test:skills:card": ".\\roguelike_survivor.console.exe --headless --path . --script tools\\verify_fire_skill_card_selection_runtime.gd",
    "test:skills:devtools": ".\\roguelike_survivor.console.exe --headless --path . --script tools\\verify_fire_skill_dev_tools_entry.gd",
    "test:enemy:healthbar": ".\\roguelike_survivor.console.exe --headless --path . --script tools\\verify_enemy_health_bar.gd",
    "test:skills": "npm run validate:skills && npm run test:skills:runtime && npm run test:skills:card && npm run test:skills:devtools && npm run test:enemy:healthbar"
  }
}
```

If JSON escaping rejects the executable command on Windows, keep `validate:skills` in `package.json` and document the runtime command in the final verification output.

---

### Task 11: Final Verification Pass

**Files:**
- All files touched above

- [ ] **Step 1: Run data and static validation**

Run:

```powershell
node tools\verify_gods_and_skills_contract.js
node tools\verify_skill_runtime_no_dead_cards.js
node tools\verify_fire_skill_upgrade_pool.js
node tools\verify_weapon_system_removed_from_main_flow.js
```

Expected: all PASS.

- [ ] **Step 2: Run Godot runtime smoke**

Run:

```powershell
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_runtime_smoke.gd
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_card_selection_runtime.gd
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_fire_skill_dev_tools_entry.gd
.\roguelike_survivor.console.exe --headless --path . --script tools\verify_enemy_health_bar.gd
```

Expected: PASS, with output confirming:

```text
PASS six gods load
PASS first Fire learnable skill loads
PASS migrated starting attack loads
PASS character-only run starts
PASS Fire skill option generated
PASS Fire skill deals damage
PASS Fire status skill applies status
PASS Fire particles spawned
PASS Fire skill debug option generated
PASS Fire skill granted through debug card path
PASS Fire skill debug damage recorded
PASS no weapon branch option generated
PASS enemy health bar eases after damage
```

- [ ] **Step 3: Run a manual game smoke**

Start the project, choose a character, begin a run, level up, choose a Fire skill, and confirm:

```text
No weapon selection is required.
The `fireball` starting attack is granted at start.
Level-up choices include Fire skills using current rarity weights.
Dev Tools can select a Fire skill and validate grant, cast, damage, status, particles, and damage popup feedback in one chain.
Chosen Fire skills spawn visible GPUParticles2D effects.
Enemies take damage through the normal damage popup and health flow.
No branch or evolution UI appears.
```

- [ ] **Step 4: Check working tree state**

Run:

```powershell
git status --short
```

Expected in this workspace: `fatal: not a git repository`. Report that commits were not possible because the workspace has no `.git` repository.

---

## Plan Self-Review

- Spec coverage: The plan covers `gods.json`, `skills.json`, Fire 60 data, real runtime effects, particles, character-only loadout, preserved starting skill, upgrade-pool rarity, weapon removal, and validation.
- Dead-card scan: The plan uses concrete file paths, commands, data shapes, and acceptance outputs. It does not allow inert skill cards or unsupported runtime rules.
- Type consistency: Skill ids, `god_id`, `rarity`, `runtime_rules`, `particle`, `starting_skill_id`, and option prefixes are consistent across the data, loader, manager, and upgrade tasks.
