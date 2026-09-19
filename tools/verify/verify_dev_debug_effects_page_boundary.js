const fs = require("fs");
const path = require("path");
const { readTextFile } = require("../lib/json_file");

const root = path.resolve(__dirname, "../..");
const pagePath = path.join(root, "scripts", "debug", "pages", "dev_debug_effects_page.gd");
const panelPath = path.join(root, "scripts", "debug", "dev_debug_panel.gd");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function read(filePath) {
  return readTextFile(filePath);
}

function functionBody(source, name) {
  const start = source.indexOf(`func ${name}`);
  if (start < 0) return "";
  const next = source.indexOf("\nfunc ", start + 1);
  return source.slice(start, next < 0 ? source.length : next);
}

assert(fs.existsSync(pagePath), "DevDebugEffectsPage script must exist.");

const page = read(pagePath);
const panel = read(panelPath);

assert(page.includes("extends VBoxContainer"), "DevDebugEffectsPage must be a VBoxContainer.");
assert(page.includes("class_name DevDebugEffectsPage"), "DevDebugEffectsPage must declare its class name.");
assert(page.includes("signal log_requested(level: StringName, message: String)"), "Effects page must expose structured logging.");
assert(page.includes('preload("res://scenes/effects/fire_tornado_effect.tscn")'), "Effects page must own the Fire Tornado scene.");
assert(page.includes('preload("res://scenes/effects/mars_spark_missile_effect.tscn")'), "Effects page must own the Mars Spark Missile scene.");

for (const method of [
  "setup",
  "build",
  "populate_options",
  "start_continuous_effect",
  "fire_single_effect",
  "trigger_selected_effect",
  "spawn_fire_tornado_effect",
  "spawn_mars_spark_missile_effect",
  "resolve_fire_tornado_spawn_position",
  "resolve_mars_spark_missile_spawn_position",
  "resolve_mars_spark_missile_target_position",
  "get_effect_option",
]) {
  assert(functionBody(page, method) !== "", `DevDebugEffectsPage.${method} must exist.`);
}

assert(panel.includes('preload("res://scripts/debug/pages/dev_debug_effects_page.gd")'), "DevDebugPanel must preload the Effects page.");
assert(/var\s+_effects_page\s*:\s*VBoxContainer/.test(panel), "DevDebugPanel must retain the mounted Effects page.");
assert(/var\s+_effect_option\s*:\s*OptionButton/.test(panel), "DevDebugPanel must retain the effect-option compatibility alias.");

const buildPage = functionBody(panel, "_build_effects_page");
assert(buildPage.includes("DevDebugEffectsPageScript.new()"), "DevDebugPanel must instantiate DevDebugEffectsPage.");
assert(buildPage.includes('_add_category_page(page_root, "effects", "Effects")'), "Panel shell must retain the Effects category wrapper.");
assert(buildPage.includes('Callable(self, "_get_player")'), "Effects page must receive the existing player lookup.");
assert(buildPage.includes('Callable(self, "_get_nearest_enemy")'), "Effects page must receive the existing nearest-enemy lookup.");
assert(buildPage.includes("get_effect_option"), "Panel must assign its compatibility option alias from the page.");

const delegates = new Map([
  ["_populate_effect_options", "populate_options"],
  ["_start_continuous_effect_fire", "start_continuous_effect"],
  ["_fire_single_effect", "fire_single_effect"],
  ["_trigger_selected_effect", "trigger_selected_effect"],
  ["_spawn_fire_tornado_effect", "spawn_fire_tornado_effect"],
  ["_spawn_mars_spark_missile_effect", "spawn_mars_spark_missile_effect"],
  ["_resolve_fire_tornado_spawn_position", "resolve_fire_tornado_spawn_position"],
  ["_resolve_mars_spark_missile_spawn_position", "resolve_mars_spark_missile_spawn_position"],
  ["_resolve_mars_spark_missile_target_position", "resolve_mars_spark_missile_target_position"],
]);

for (const [panelMethod, pageMethod] of delegates) {
  const body = functionBody(panel, panelMethod);
  assert(body.includes(`_effects_page.call("${pageMethod}"`), `${panelMethod} must delegate to ${pageMethod}.`);
}

assert(!panel.includes("FIRE_TORNADO_EFFECT_SCENE"), "Panel must not retain the Fire Tornado scene dependency.");
assert(!panel.includes("MARS_SPARK_MISSILE_EFFECT_SCENE"), "Panel must not retain the Mars Spark Missile scene dependency.");
assert(!page.includes("GameData"), "Effects page must not depend on gameplay data services.");

console.log("[verify_dev_debug_effects_page_boundary] PASS");
