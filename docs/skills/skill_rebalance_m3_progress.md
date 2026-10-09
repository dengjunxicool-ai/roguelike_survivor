# SDD ledger — plan: docs/superpowers/plans/2026-10-09-skill-system-rebalance.md

M3 base: 6c7e5b3 (merged PR #15). Branch: codex/skill-rebalance-m3. Tasks T10–T13 only.

Ruling: user explicitly requested M3 after manually merging M2 — proceed with approved spec/plan; preserve M2 full-run acceptance as open rather than assert it passed — cost if wrong: later M4 balance work must still close the recorded gameplay gap.
Ruling: reuse E-drive linked worktree, execute task/ledger bookkeeping with PowerShell/Python instead of POSIX skill helpers — Windows and no-C-write constraint; all scratch/evidence under E:/codex/skill-rebalance — cost if wrong: helper automation unavailable, manually verify task boundaries.
Pre-flight: T10 produces final-action pure snapshots; T11 changes actions before adaptation; snapshots must record after growth and milestones, never re-adapt during replay.
Pre-flight: T12 produces geometry/source interaction contracts and semantic case schema; T13 consumes identical services/schema, no second compatibility runtime.
Pre-flight: T10/T12 consume T3 provenance and combat clock, T5 cleanup; pending replay/interaction state must clear on remove and reset, obey pause and derived-output limits.
Baseline: M3-baseline full suite 180/180 PASS, exit 0.

Task 10: in progress — real snapshot/replay and bounded chaos runtime; tests first.

Task 10: RED missing snapshot/runtime; GREEN original lance/meteor outputs, pure JSON, 40%/35% copied packets, no business side effects, origin cleanup, four entropy branches/last two/expiry, fifth-cast charge/sixth bonus, 25-fission suction then one 2s burst, zero-delta pause, one-generation geometry.
Task 10: Ruling: explicit chaos_contract replaces removed placeholder effects in legacy inventory check — real runtime is tested by T10 behavior fixtures; no fake stat is retained to satisfy old field-only checks — cost if wrong: runtime contract must remain linked to its behavior tests.
Task 10: fixed delayed replay executor lifetime after verbose leak trace found abandoned SceneTreeTimer/SkillInstance references; persistent service executor retains callbacks until completion.
Task 10: complete (commits 6c7e5b3..HEAD; T10-suite-final 182/182 PASS, exit 0; copied delayed callbacks finish with no script/engine error). Task 11: started; milestones test RED missing profile.
Task 11: complete (base 4f9a031; T11-suite 183/183 PASS, exit 0). Immutable effect-ID patches before single growth; eighteen Lv1/Lv3/Lv5 paths, 66 original mechanics, actual first-hit stacks/barrier recovery/single cooldown refund. Ruling: scope stable-ID uniqueness to definitions using level_overrides because existing non-milestone modifier IDs deliberately repeat; those originals remain untouched. Spatial line/end-point behavior continues through the shared geometry contract in T12. Task 12: started; thirty representative fusions and real indexed geometry.

Task 12: RED geometry service missing; thirty contracts missing; actual fixtures found derived reaction restarted fusion, cast target result lost to deep copy, targetless area creation rejected, and unneeded overlap event flood starving the event budget. GREEN fixes narrowphase, shared retarget result, creation identity, owned-rule interest filtering plus one-second sustained overlap emission.
Task 12: Ruling: lightning orb is the existing ball_lightning_orb AreaEffect from thunder_dash_ball_lightning, so observe area overlap and move that actual object rather than invent a thunder attack projectile — preserves the shipped source form — cost if wrong: future projectile orb implementations must use the same spatial contract explicitly.
Task 12: Ruling: legacy literal payload/numeric-presence checks recognize fusion_rules; no duplicate placeholder areas remain. Real fixture damage/spawn/ICD checks and steam per-second/curse-resolution tests are the behavioral gate — cost if wrong: new rules require new runtime fixtures rather than relying on old number-presence tests.
Task 12: Ruling: new area-created/reaction events consume the existing bounded event budget; chaos test waits for queued/deferred outputs before asserting object creation — production budget remains unchanged — cost if wrong: end-to-end frame latency still needs M4 dense-wave measurement.
Task 12: actual catalog cast regression found void_rift_field ID mismatch; fixed. Removal regression cleared fusion Cursed pause/bonus sources. Actual barrier recovery regression permits original base shield gains to charge fusion while fusion-generated/copy shield gains stay excluded. New line/cross bounds, target hits and visuals share the same shape.

Task 12: Ruling: real lava hit regression drives the spawned area damage pipeline directly instead of assuming its budgeted physics tick fires in the current bucket; isolated reproduction proved frame-dependent assertion, not missing ignition — cost if wrong: this test proves damage provenance, while scheduling/performance remains a separate gate. Shield recovery exception now requires the actual grant action producer identity, not merely a non-fusion origin.

Task 12: complete (base 6102668; T12-suite-verified 186/186 PASS, exit 0). Thirty first-batch independent positive/three-negative fixtures plus actual spatial, timer, curse, shield and pool-generation tests. Task 13: started; remaining thirty contracts and full ID behavior coverage.
