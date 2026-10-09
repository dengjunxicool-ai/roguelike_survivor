# SDD ledger — plan: docs/superpowers/plans/2026-10-09-skill-system-rebalance.md

M2 scope: T5–T9 only. Base c63688f; branch codex/skill-rebalance-m2; existing isolated E:/codex/skill-rebalance/worktree reused. All output E:/codex/skill-rebalance/. M1 PR branch retained.
Ruling: reuse linked E-drive worktree with a new branch instead of native creation — native tool cannot specify E-drive placement and user prohibits C writes — M1 commits remain on codex/skill-rebalance-m1.
Ruling: PowerShell/Python bookkeeping replaces Bash helper scripts — durable ledger and per-task commits retain the same completion contract — cost if wrong: manual ledger bookkeeping could omit a verification item; checked against plan and git history.
Pre-flight T5→T6: replacement must use the same requirements as offers, bypass ordinary capacity only during confirmation; do not lock a school on begin/cancel.
Pre-flight T3→T7/T9: counters use stable event_id; damage/resource eligibility uses provenance and target snapshots, not listener identity.
Pre-flight T4→T8: reuse freeze immunity and effective Power; do not add a second freeze pipeline.
Pre-flight T9→T14: minimal replacement UI and core/fusion HUD belong to M2; full card previews remain M4.
Ruling T5→T10: no copy snapshot service exists until M3; source cleanup calls clear_origin only when present and clears existing runtime source objects now.
Tasks: T5–T9 implementation and automated regression complete; final review fixes verified. M2 full-run gameplay acceptance remains open until the real-play results are assessed. M3/M4 not authorized in this turn.

T5: complete; capacity RED4→GREEN, replacement missing→GREEN. Core/fusion separate, 12 HUD slots and source-cleaning atomic replacement with one opportunity per run; cancel preserves school/skill/upgrade state. New slots/replacement and legacy slots/HUD/attack PASS, exit0/script_errors0/engine_errors0. M2 baseline169/169 PASS. Migrated legacy full-slot offer rejection to opportunity-used case; HUD10→12 assertion now backed by real layout/render-node tests. Outputs T05-*.

T6: complete; requirements/progression tests RED→GREEN; final full suite T06-acceptance 173/173 PASS (exit0). Shared stage/capability policy, Lv6 fusion migration gate, Lv8 core, category weights and four-level core guarantee. Fixed permanent school locks and old-run replacement transactions RED→GREEN. Runtime fixtures preserve combat assertions while admission tests cover new gates.
Ruling T6: legacy smoke fixtures install runtime skills explicitly — old fixtures exceeded learning capacity and prerequisites; gameplay assertions stay intact, with qualification independently covered — cost if wrong: a fixture may hide a learning regression (covered by requirement/offer/slot tests).

T7: complete; resource/cycle RED→GREEN. T07-cycle-final and T07-boss-final pass (script/engine errors0); fire/curse runtime smokes pass. Fractional resources, valid strong ticks, resolution/corpse dedupe, inferno self-charge prevention, cast-only ignite, true fire ground, capped combustion, fixed-time single-resolution pact and low-HP curse-only deepen. Ruling T7: event-position area mode prevents corpse retargeting — expiry/death explosions must retain their occurrence position — cost if wrong: incorrect area centering; covered by real damage tests.

T8: complete; control RED5→GREEN, execute RED5→GREEN. T08-control-final2 includes actual lance pre-hit splash and core threshold; T08-execute-green, frost smoke, frozen vulnerability all PASS, script/engine errors0. Crowd scan0.25s, shared6s ring, tier execute thresholds, Boss bonus/5s ICD, freeze weakness0.5s/10%/2s ICD and immovable target protection.

T9: complete; thunder and holy tests RED→GREEN. T09-thunder-final and T09-holy-final2 PASS (script/engine errors0). Initial positive thunder hits, bounded overload spread, actual cooldown modifiers, time-based barrier shield, shield cap/timed devotion, shared counterattack ICD and live guardian absorption through player damage pipeline. Full suite M2-pre-review: 179/179 PASS, exit0.
Ruling T9: migrate six legacy text/structure contracts to approved M2 descriptions and events — old assertions encoded superseded behavior; real runtime tests retain output checks — cost if wrong: a text contract could miss behavior, covered by separate real damage/status/shield tests.

Final review: one fresh-context read-only reviewer (gpt-6-astra), base c63688f..2a0e17f; 0 Critical, 8 Important. All eight entered one RED→GREEN fix pass in verify_m2_review_regressions.gd; final whole suite M2-final-suite 180/180 PASS, exit0. Script/engine errors0.
Final: fixed delayed meteor origin cancellation and pause semantics — pending output pauses and removed source cannot spawn, RED→GREEN.
Final: fixed pact settlement growth and fixed 5s mark — Lv2 legendary expiry151/death302 at100P, RED→GREEN.
Final: fixed ignite cast-area exclusion — real spawned lava damage produces additional90, attack/summon/status/derived hits excluded, RED→GREEN.
Final: fixed scorched coverage — real active-area registry (including deferred factory spawns), complete fire-ground IDs, tick-offset-independent35% and immediate exit, RED→GREEN.
Final: fixed competing offer guarantees and low-HP typed-array runtime error — upgrade then survival retained, RED→GREEN.
Final: fixed fear whisper dead admission — apply_cursed required in shared learning/offer evaluation, RED→GREEN.
Final: fixed Sanctuary after natural shield expiry — one effective shield query uses combat clock; positive while active/zero after6.1s with no hit/grant, RED→GREEN.
Final: fixed Boss resources from actual attack-applied Burning — five actual status ticks grant1 with source/copy/self-core eligibility independent of secondary-output gate, RED→GREEN.

Final: Ruling: retain M3/M4 phase boundaries for real copy, cast milestones, 60 fusion interactions, full card previews and balance/performance matrix — user authorized M2 only; keep approved fusion offer migration gate — cost if wrong: cannot treat M2 as the complete skill-system delivery.
Final: Ruling: resource_crossings action repetition remains per legal occurrence — no current M2 legal occurrence crosses multiple final resource thresholds, fractional counter API itself preserves crossings/remainder — cost if wrong: future long-duration/coalesced configurations could miss additional outputs.
Final: Ruling: retain legacy offer-rule compatibility filtering alongside shared M2 capability policy — reviewer found no current nonredundant base-data divergence; no generalized migration in this phase — cost if wrong: future legacy rule fields could diverge between learning and offers; current M2 entry tests pass.
Final: Ruling: retain E-drive worktree and verification evidence at the requested stage stop — the durable report/next phase still need them, no plan scratch workspace was created — cost if wrong: E-drive disk usage until later cleanup.
Final: deferred minors: none identified by reviewer.

M2 gameplay acceptance: NOT PASSED. Corrected unassisted runner inherits real attack runtime through add_skill; no HP/speed/damage assists, original mage75HP/98speed, seed618, abandoned_dungeon, time_scale5. School-biased real offers choose initial attack upgrade and two casts/summons; all subsequent progression uses real choice modal. Fire112.7s / Frost70.5s / Thunder68.8s / Curse67.8s / Holy39.5s ended DEFEAT, script_errors0/engine_errors0, Boss not reached. This autoplay evidence does not establish player impossibility or isolate balance vs controller strategy; it does not prove the 300s full-run criterion. Evidence M2-playable-{school}/result.json + report.md (JSON), retained on E drive. No production balance changes were made to manufacture victory. Stop and report M2 implementation/regression complete with gameplay acceptance still open; do not enter M3/M4.
