# Wave HUD - Implementation Handoff

Source design: `../wave_hud.pen` (`bi8Au`)

## Approved repair gauge colors

- Track/background: `#A349A4` (purple)
- Filled progress: `#FFF200` (gold/yellow)
- Pencil variables: `$style/repair-gauge-track`, `$style/repair-gauge-fill`

## Layer order (back to front)

1. `01_board_wall_background.png`
2. Flippers: `30_flipper_bottom_placement.png`, `31_flipper_side_placement.png`
3. Ball: `32_cat_eye_ball_placement.png`
4. World UI: `13_world_max_combo_text.png`
5. HUD: `10_hud_life_stock.png`, `11_hud_score_repair_gauge.png`, `12_hud_settings_button.png`

`00_full_ingame_preview.png` is the visual reference for final placement. `20_style_guide.png` contains the design-system rules. Files prefixed with `source_` are the original-resolution game art and should be transformed in Godot rather than repeatedly rasterized.

## Godot notes

- Keep the repair gauge track and fill as separate controls so progress can be animated.
- Keep the max-combo layer backgroundless and anchored to the related world object.
- Preserve PNG alpha for all HUD and placement assets.
