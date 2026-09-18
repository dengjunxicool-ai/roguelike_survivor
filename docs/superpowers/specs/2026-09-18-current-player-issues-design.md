# Current Player-Visible Issues Repair Design

## Scope

Repair the eight player-visible issues confirmed in the current working tree:

1. Missing `dash_end` skill events.
2. Dash-path filtering incorrectly applied to ordinary circular areas.
3. Character selection content becoming unreachable on narrow viewports.
4. Map selection content becoming unreachable on narrow viewports.
5. Combat HUD clipping on narrow viewports.
6. Invalid title-menu geometry at 320×240.
7. Pause being unavailable from keyboard or controller navigation.
8. Result unlock text being reused across separate runs.

The dormant `radiance` status, unused generic modal flow, and unrelated stale verification scripts are explicitly out of scope.

## Design Principles

- Preserve existing gameplay, data contracts, and desktop presentation outside the affected cases.
- Repair behavior at the existing system boundary instead of adding parallel runtime paths.
- Keep changes small in the high-risk player, skill, and UI state-machine code.
- Add a regression verification before each production change and observe it fail for the intended reason.
- Do not rewrite or revert unrelated staged or unstaged work already present in the repository.

## Combat Event Repair

`Player` remains the owner of dash lifecycle events. It will detect the transition from an active dash to an inactive dash and emit exactly one `dash_end` event after movement for the final dash frame is resolved. The event will use the same context builder and SkillEventBus used by `dash_start` and `dash_tick`, so existing trigger-rule adapters and skill definitions need no alternate path.

Regression coverage must prove that one completed dash emits one `dash_start`, at least one `dash_tick`, and exactly one `dash_end`; subsequent non-dashing frames must not emit additional end events.

## Area Target-Filtering Repair

Dash-path filtering becomes an explicit action parameter rather than an implicit consequence of dash context. `SkillActionAreaBuilder` will only set `dash_path_filter` when the action parameters request it. Dash coordinates may still be carried for actions that deliberately opt in.

Ordinary circular areas, including the start and end rifts created by `chaos_dash_rift_step`, retain radial hit testing. Existing path-shaped effects may opt in through their action configuration when their intended geometry is a line segment.

Regression coverage must construct an area with dash context but without the opt-in flag and confirm that a target inside the radius but beside the dash line remains eligible. A separate assertion must confirm that explicit opt-in still enables path filtering.

## Responsive Selection Screens

The existing selection controllers retain their desktop horizontal layout. Their content row will use a container capable of switching orientation:

- At normal widths, character and map panels remain horizontal with their current minimum widths.
- At compact widths, the content row becomes vertical, panel minimum widths are reduced to the available content width, and the existing vertical ScrollContainer provides access to every section.
- Horizontal scrolling remains disabled because compact mode no longer depends on off-screen horizontal content.

The compact breakpoint is derived from the current combined panel minimum widths rather than introducing a separate global responsive subsystem.

Regression coverage must verify both orientations and confirm that compact panel widths do not force content wider than the viewport.

## Responsive Combat HUD

The HUD retains its design-space rectangles. During layout, it calculates a uniform narrow-screen scale for fixed-size HUD groups. Positioning uses each control's scaled visual size so centered and right-anchored controls remain inside the viewport.

Desktop viewports use scale `1.0`. Narrow viewports reduce the scale only as much as required to fit the widest critical element, with a lower bound that keeps text usable. The player-status panel and skill bar must fit horizontally at the project's supported compact width. No gameplay values or HUD content are removed.

Regression coverage must inspect the resulting visual bounds at desktop, 720px, and 360px widths.

## Title Screen at Minimal Viewports

The title action menu will never receive a negative size. Compact layout will reserve a bounded visible region for actions. If the complete action list cannot fit, it will be hosted by a vertical ScrollContainer so every action remains reachable without placing the menu outside the viewport.

The 320×240 boundary is handled directly rather than falling back to a larger fictional viewport. Regression coverage must assert positive menu dimensions and in-viewport bounds at exactly 320×240.

## Pause Input and Focus

`UIManager` will handle the standard `ui_cancel` action:

- `RUNNING` transitions to `PAUSE_MENU`.
- `PAUSE_MENU` transitions back to `RUNNING`.
- Other modal and result states keep their existing behavior.

The HUD pause button will accept keyboard focus. Mouse behavior remains unchanged. Input handling must mark the event handled to prevent duplicate transitions.

Regression coverage must exercise the state transition using an `InputEventAction` and confirm focus is enabled on the pause button.

## Result Unlock Cache Lifetime

The result unlock service keeps its same-result cache so repeated refreshes of one result screen remain idempotent. A new reset method clears that cache at the start of every run. `UIManager` invokes the result controller's run-reset hook while initializing run state.

Two runs that happen to share map, outcome, and floored duration must therefore evaluate unlock text independently. Repeated refreshes within one run must still return the cached result.

Regression coverage must simulate two run boundaries with the same result key and confirm the second run is not served stale text.

## Verification Strategy

Each repair follows red-green verification. Relevant checks include:

- Dash lifecycle runtime verification.
- Area-effect dash-path filtering runtime verification.
- Character-select and map-select responsive layout verification.
- HUD responsive bounds verification.
- Title-screen minimal viewport verification.
- Pause input/focus verification.
- Result unlock cache lifetime verification.
- Existing related Godot runtime checks.
- `node tools/validate/check_text_encoding.js`.
- `node tools/validate/validate_enemy_configs.js`.
- `node tools/validate/validate_modifier_effects.js`.
- A normal-window full-flow autoplay run.

Completion requires the new regressions and the directly affected existing checks to pass. Unrelated pre-existing verification failures will be reported separately and will not be silently changed under this scope.
