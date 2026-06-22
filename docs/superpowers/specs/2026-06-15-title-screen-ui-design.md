# Title Screen UI Design

## Goal

Redesign the welcome screen for a dark fantasy 3/4 top-down roguelike survivor game. The first screen should immediately communicate dungeon combat, premium dark fantasy tone, and clear menu actions.

## Approved Direction

Use a 3/4 overhead dungeon arena as the primary visual instead of a corridor-style hero image. Keep the existing title-screen state flow intact: the title screen still waits for the first input, then reveals the main menu.

The approved approach is:

- Generated top-down arena background at `res://assets/ui/title/title_screen_topdown_background.png`.
- Previous generated corridor background at `res://assets/ui/title/title_screen_background.png` as the first fallback.
- Existing map art at `res://assets/ui/maps/abandoned_dungeon.png` as the second fallback.
- Centered title plaque with the visible main title `Survivor`, small genre kicker, accent line, subtitle, and press-any-key prompt.
- Right vertical menu panel with dark gold button states.
- Bottom version label kept subtle and hidden on compact viewports.

## UI/UX System Notes

`$ui-ux-pro-max` recommended an immersive game-entry pattern, dark premium base, gold CTA accents, high contrast, and responsive safety checks. The implementation adapts those web/mobile recommendations into Godot UI controls:

- Immersion comes from the background art, not explanatory marketing copy.
- CTA hierarchy comes from gold hover/pressed states on menu buttons.
- Responsive safety is handled in `TitleScreenController.update_layout()`.
- Visual noise is reduced through meaningful title/menu panels instead of broad black rectangular overlays.

## Visual Style

The screen uses charcoal stone, blue-green darkness, violet soul-crystal accents, and restrained antique gold. The generated image avoids text, characters, buttons, and HUD so all interactive elements remain native Godot controls.

Generated image prompt used:

```text
Dark fantasy 3/4 top-down roguelike survivor title screen background. Ruined dungeon arena, cracked stone battle floor, broken gothic walls and pillars, purple soul crystals, amber torches, abyss fog, cursed gate. Environment only, no characters, no monsters, no text, no UI. Leave darker negative space for a title on the left and a vertical menu on the right.
```

## Architecture

Only `scripts/ui/screens/title_screen_controller.gd` owns this screen's layout, visuals, and title-specific button styling. `scripts/ui/ui_manager.gd` still creates the controller, connects `state_requested` and `quit_requested`, and registers the screen under `STATE_TITLE`.

No gameplay, save data, HUD, character selection, map selection, or combat code is changed.

## Components

- `TextureRect` background: full-screen top-down arena art with aspect-covered scaling.
- Title plaque: genre kicker, large `Survivor` title, accent line, subtitle, input prompt.
- Action menu: `PanelContainer` with title label and existing action buttons.
- Footer: small version label, hidden on compact screens.

## Data Flow

Input handling is unchanged. `handle_input()` reveals actions once. Menu buttons continue to emit the same `state_requested` values or `quit_requested`.

Localization still uses `LocalizationService.translate()`. Missing title-specific strings fall back to readable Chinese text inside the controller.

## Error Handling

Background loading tries three assets in order:

1. `res://assets/ui/title/title_screen_topdown_background.png`
2. `res://assets/ui/title/title_screen_background.png`
3. `res://assets/ui/maps/abandoned_dungeon.png`

If all fail, the dark base `ColorRect` remains visible.

## Verification

Run these checks after implementation:

```powershell
node tools\check_text_encoding.js
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --editor --path . --quit
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify_ui_architecture.gd
```
