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
