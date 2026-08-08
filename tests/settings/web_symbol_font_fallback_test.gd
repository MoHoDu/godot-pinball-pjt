extends SceneTree


const WAVE_THEME_PATH := \
	"res://Resources/ui/wave_hud/dark/wave_hud_theme.tres"
const PICTURE_FONT_PATH := \
	"res://Resources/ui/themes/web_safe_picture_font.tres"
const BLACK_HAN_FONT_PATH := \
	"res://Resources/ui/themes/web_safe_black_han_font.tres"
const SELECTION_HUD_PATH := \
	"res://Resources/Prefabs/ui/ball_selection/current/select_ball_selection_hud.tscn"
const WAVE_HUD_PATH := \
	"res://Resources/Prefabs/ui/wave_hud/wave_hud.tscn"
const REPAIR_CARD_PATH := \
	"res://Resources/Prefabs/ui/repair_placement/repair_part_inventory_card.tscn"
const SETTINGS_POPUP_PATH := \
	"res://Resources/Prefabs/ui/settings/settings_popup.tscn"
const REQUIRED_SYMBOLS := "✓·←→—"


var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_shared_display_font_fallbacks()
	_test_wave_theme_fallbacks()
	await _test_selection_hud_symbols()
	await _test_boss_empty_last_hit_symbol()
	await _test_repair_card_symbols()
	_test_reward_shop_display_font()
	await _test_settings_display_fonts()
	_finish()


func _test_shared_display_font_fallbacks() -> void:
	for path: String in [PICTURE_FONT_PATH, BLACK_HAN_FONT_PATH]:
		var font := load(path) as Font
		_expect(font != null, "Web-safe display font must load: %s" % path)
		if font == null:
			continue
		for character: String in REQUIRED_SYMBOLS:
			_expect(
				font.has_char(character.unicode_at(0)),
				"Web-safe display font must contain '%s': %s" % [character, path]
			)


func _test_wave_theme_fallbacks() -> void:
	var theme := load(WAVE_THEME_PATH) as Theme
	_expect(theme != null, "Wave HUD theme must load.")
	if theme == null:
		return
	var font := theme.default_font
	_expect(font != null, "Wave HUD theme must provide its authored font.")
	if font == null:
		return
	for character: String in REQUIRED_SYMBOLS:
		_expect(
			font.has_char(character.unicode_at(0)),
			"Wave HUD font fallback must contain '%s'." % character
		)


func _test_selection_hud_symbols() -> void:
	var packed := load(SELECTION_HUD_PATH) as PackedScene
	_expect(packed != null, "Selection HUD scene must load.")
	if packed == null:
		return
	var hud := packed.instantiate() as Control
	root.add_child(hud)
	await process_frame
	var paths: Array[NodePath] = [
		NodePath("Center/Panel/Margin/VBox/Header/TitleGroup/EyebrowLabel"),
		NodePath("Center/Panel/Margin/VBox/Bottom/ConfirmArea/ConfirmMargin/ConfirmVBox/ConfirmButton"),
		NodePath("Center/Panel/Margin/VBox/Bottom/ConfirmArea/ConfirmMargin/ConfirmVBox/ConfirmHint"),
		NodePath("Center/Panel/Margin/VBox/GuideLabel"),
	]
	for path: NodePath in paths:
		var control := hud.get_node(path) as Control
		_expect(control != null, "Selection HUD symbol control must exist: %s" % path)
		if control == null:
			continue
		var text := String(control.get("text"))
		var font := control.get_theme_font(&"font")
		_expect(font != null, "Selection HUD control must resolve a font: %s" % path)
		if font == null:
			continue
		for character: String in text:
			if character.unicode_at(0) <= 127:
				continue
			_expect(
				font.has_char(character.unicode_at(0)),
				"Selection HUD font must render '%s' at %s." % [character, path]
			)
	hud.queue_free()
	await process_frame


func _test_boss_empty_last_hit_symbol() -> void:
	var packed := load(WAVE_HUD_PATH) as PackedScene
	_expect(packed != null, "Wave HUD scene must load.")
	if packed == null:
		return
	var hud := packed.instantiate() as Control
	root.add_child(hud)
	await process_frame
	var score := hud.get_node("DesignSpace/ScoreRepairHud") as WaveScoreRepairHud
	_expect(score != null, "Wave HUD must contain the production score HUD.")
	if score == null:
		hud.queue_free()
		await process_frame
		return
	score.render({
		&"score_display_mode": WaveHudStateSource.SCORE_MODE_BOSS,
		&"boss_max_health": 12000,
		&"boss_current_health": 12000,
		&"boss_last_damage": 0,
	})
	var target := score.get_node("TargetScore") as Label
	_expect(target.text == "—", "Boss HUD must retain the authored empty-hit dash.")
	var font := target.get_theme_font(&"font")
	_expect(
		font != null and font.has_char("—".unicode_at(0)),
		"Boss HUD font must render the empty-hit dash in Web builds."
	)
	hud.queue_free()
	await process_frame


func _test_repair_card_symbols() -> void:
	var packed := load(REPAIR_CARD_PATH) as PackedScene
	_expect(packed != null, "Repair inventory card scene must load.")
	if packed == null:
		return
	var card := packed.instantiate() as Control
	root.add_child(card)
	await process_frame
	var feature := card.get_node("FeatureLabel") as Label
	var font := feature.get_theme_font(&"font")
	_expect(feature.text.contains("·"), "Repair card must retain its authored separator.")
	_expect(
		font != null and font.has_char("·".unicode_at(0)),
		"Repair card font must render its separator in Web builds."
	)
	card.queue_free()
	await process_frame


func _test_reward_shop_display_font() -> void:
	var font := RewardShopHud.DISPLAY_FONT as Font
	_expect(
		font != null and font.resource_path == BLACK_HAN_FONT_PATH,
		"Reward shop must use the Web-safe Black Han display font."
	)
	_expect(
		font != null and font.has_char("·".unicode_at(0)),
		"Reward shop display font must render the purchase separator."
	)


func _test_settings_display_fonts() -> void:
	var packed := load(SETTINGS_POPUP_PATH) as PackedScene
	_expect(packed != null, "Settings popup scene must load.")
	if packed == null:
		return
	var popup := packed.instantiate() as Control
	root.add_child(popup)
	await process_frame
	var picture_font_found := false
	var black_han_font_found := false
	for node: Node in popup.find_children("*", "Label", true, false):
		var font := (node as Label).get_theme_font(&"font")
		if font.resource_path == PICTURE_FONT_PATH:
			picture_font_found = true
		elif font.resource_path == BLACK_HAN_FONT_PATH:
			black_han_font_found = true
	_expect(picture_font_found,
		"Settings title must use the Web-safe picture display font.")
	_expect(black_han_font_found,
		"Settings license names must use the Web-safe Black Han display font.")
	popup.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: web_symbol_font_fallback_test")
		quit(0)
		return
	print("FAIL: web_symbol_font_fallback_test (%d failures)" % _failures.size())
	quit(1)
