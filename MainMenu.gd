extends Control
## Головне меню «Block Smash»: заголовок, рекорд, кнопка «Грати», налаштування гучності.
## Два режими: Classic та Lock Mode
## Сцена menu.tscn: один кореневий вузол Control з цим скриптом.
## Увесь інтерфейс створюється кодом.

const GAME_SCENE := "res://main.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_PATH := "user://save.cfg"

const TITLE_TOP := "BLOCK"
const TITLE_BOTTOM := "SMASH"

var volume := 0.8
var muted := false
var vibration := true
var vibration_button: Button
var best_score := 0
var selected_mode := "classic"  # класичний режим

var settings_page: Control
var volume_label: Label
var volume_slider: HSlider
var mute_button: Button
var beep_player: AudioStreamPlayer
var toast_label: Label
var toast_tween: Tween

var title_letters: Array = []   # [{ "node": Label, "base_y": float }]
var float_blocks: Array = []    # [{ "node": Control, "speed": float, "spin": float }]
var anim_time := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0e1a52"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_settings()
	_load_best()
	_apply_audio()

	beep_player = AudioStreamPlayer.new()
	beep_player.stream = _make_beep(660.0, 0.15)
	add_child(beep_player)

	_build_background()
	_build_title()
	_build_home()
	_build_settings()
	_build_toast()


func _process(delta: float) -> void:
	anim_time += delta
	# Хвиля букв заголовка
	for i in title_letters.size():
		var entry: Dictionary = title_letters[i]
		var label: Label = entry["node"]
		label.position.y = entry["base_y"] + sin(anim_time * 2.4 + i * 0.55) * 9.0
	# Плаваючі блоки на фоні
	for entry in float_blocks:
		var block: Control = entry["node"]
		block.position.y -= entry["speed"] * delta
		block.rotation += entry["spin"] * delta
		if block.position.y < -140.0:
			block.position.y = 1340.0
			block.position.x = randf_range(-30.0, 650.0)


# ------------------------------------------------------------ Build UI

func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color("0b1a5a"))
	grad.set_color(1, Color("3a1a78"))
	grad.add_point(0.5, Color("151a6b"))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 8
	tex.height = 256
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var palette: Array[Color] = [
		Color("3fd0ff"), Color("43d65a"), Color("ffcf3a"), Color("ff5a6a"), Color("a56bff"),
	]
	for i in 14:
		var block := FloatBlock.new()
		var s := randf_range(50.0, 110.0)
		block.size = Vector2(s, s)
		block.pivot_offset = block.size * 0.5
		block.color = palette[randi() % palette.size()]
		block.position = Vector2(randf_range(-30.0, 650.0), randf_range(0.0, 1280.0))
		block.rotation = randf() * TAU
		block.modulate.a = randf_range(0.12, 0.28)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(block)
		float_blocks.append({
			"node": block,
			"speed": randf_range(8.0, 28.0),
			"spin": randf_range(-0.4, 0.4),
		})


func _build_title() -> void:
	var top_colors: Array[Color] = [
		Color("27c8f0"), Color("3b82f6"), Color("3ddc4a"), Color("ffd23a"), Color("ff4d5e"),
	]
	var bottom_colors: Array[Color] = [
		Color("3b82f6"), Color("3ddc4a"), Color("ffd23a"), Color("ff9f1c"), Color("ff4d5e"),
	]
	var step := 128.0
	var start_x := (720.0 - step * 5.0) * 0.5
	for row in 2:
		var text: String = TITLE_TOP if row == 0 else TITLE_BOTTOM
		var cols: Array[Color] = top_colors if row == 0 else bottom_colors
		for i in 5:
			var label := Label.new()
			label.text = text[i]
			label.size = Vector2(step, 190.0)
			label.position = Vector2(start_x + i * step, 215.0 + row * 165.0)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var col := cols[i]
			label.add_theme_font_size_override("font_size", 150)
			label.add_theme_color_override("font_color", col.lightened(0.1))
			label.add_theme_color_override("font_outline_color", col.darkened(0.35))
			label.add_theme_constant_override("outline_size", 22)
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
			label.add_theme_constant_override("shadow_offset_y", 10)
			label.add_theme_constant_override("shadow_outline_size", 22)
			add_child(label)
			title_letters.append({"node": label, "base_y": label.position.y})


func _build_home() -> void:
	# Шестерня (налаштування) у лівому верхньому куті
	var gear := IconButton.new()
	gear.kind = "gear"
	gear.position = Vector2(30, 40)
	gear.size = Vector2(96, 96)
	gear.pressed.connect(_open_settings)
	add_child(gear)

	# Панель з рекордом і кнопками режимів
	var panel := Panel.new()
	panel.position = Vector2(100, 580)
	panel.size = Vector2(520, 340)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 0.08)
	panel_style.set_corner_radius_all(40)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(1, 1, 1, 0.16)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var trophy := TrophyIcon.new()
	trophy.position = Vector2(60, 18)
	trophy.size = Vector2(52, 52)
	trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(trophy)

	var best_label := Label.new()
	best_label.text = "РЕКОРД: " + _format_number(best_score)
	best_label.position = Vector2(125, 10)
	best_label.size = Vector2(380, 70)
	best_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	best_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	best_label.add_theme_font_size_override("font_size", 38)
	best_label.add_theme_color_override("font_color", Color("e6ecff"))
	panel.add_child(best_label)

	# Кнопка "ГРАТИ (Classic)"
	var play_classic := Button.new()
	play_classic.text = "ГРАТИ\n(Classic)"
	play_classic.position = Vector2(30, 100)
	play_classic.size = Vector2(230, 110)
	play_classic.pivot_offset = play_classic.size * 0.5
	play_classic.focus_mode = Control.FOCUS_NONE
	_style_button(play_classic, Color("3ddc4a"), 52, 32)
	play_classic.pressed.connect(func(): _on_play_pressed("classic"))
	panel.add_child(play_classic)

	# Кнопка "ГРАТИ (Lock Mode)"
	var play_lock := Button.new()
	play_lock.text = "ГРАТИ\n(Lock Mode)"
	play_lock.position = Vector2(260, 100)
	play_lock.size = Vector2(230, 110)
	play_lock.pivot_offset = play_lock.size * 0.5
	play_lock.focus_mode = Control.FOCUS_NONE
	_style_button(play_lock, Color("ff9f1c"), 52, 32)
	play_lock.pressed.connect(func(): _on_play_pressed("lock"))
	panel.add_child(play_lock)

	# М'яка пульсація обох кнопок
	var pulse1 := play_classic.create_tween().set_loops()
	pulse1.tween_property(play_classic, "scale", Vector2.ONE * 1.03, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse1.tween_property(play_classic, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var pulse2 := play_lock.create_tween().set_loops()
	pulse2.tween_property(play_lock, "scale", Vector2.ONE * 1.03, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse2.tween_property(play_lock, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Кнопка «Магазин»
	var shop := Button.new()
	shop.text = "МАГАЗИН"
	shop.position = Vector2(210, 960)
	shop.size = Vector2(300, 96)
	shop.focus_mode = Control.FOCUS_NONE
	_style_button(shop, Color("3b82f6"), 40, 44)
	shop.pressed.connect(func(): _soon("Магазин"))
	add_child(shop)

	# Нижня панель: Рейтинг / Подарунок / Профіль
	var kinds := ["bars", "gift", "profile"]
	var names := ["Рейтинг", "Подарунок", "Профіль"]
	var centers := [130.0, 360.0, 590.0]
	for i in 3:
		var button := IconButton.new()
		button.kind = kinds[i]
		button.size = Vector2(104, 104)
		button.position = Vector2(centers[i] - 52.0, 1090.0)
		var item_name: String = names[i]
		button.pressed.connect(func(): _soon(item_name))
		add_child(button)

		var caption := Label.new()
		caption.text = item_name
		caption.size = Vector2(200, 40)
		caption.position = Vector2(centers[i] - 100.0, 1202.0)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size", 30)
		caption.add_theme_color_override("font_color", Color("cfd9ff"))
		add_child(caption)


func _build_settings() -> void:
	settings_page = Control.new()
	add_child(settings_page)
	settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_page.visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	settings_page.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center_box := CenterContainer.new()
	settings_page.add_child(center_box)
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2263")
	style.set_corner_radius_all(48)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.2)
	style.content_margin_left = 50.0
	style.content_margin_right = 50.0
	style.content_margin_top = 50.0
	style.content_margin_bottom = 50.0
	panel.add_theme_stylebox_override("panel", style)
	center_box.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 36)
	panel.add_child(vbox)

	vbox.add_child(_make_label("Налаштування", 64))

	volume_label = _make_label("", 44)
	vbox.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = volume
	volume_slider.custom_minimum_size = Vector2(480, 64)
	_style_slider(volume_slider)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.drag_ended.connect(func(_changed: bool): _play_beep())
	vbox.add_child(volume_slider)

	mute_button = Button.new()
	mute_button.custom_minimum_size = Vector2(480, 90)
	mute_button.focus_mode = Control.FOCUS_NONE
	_style_button(mute_button, Color("5b6bd6"), 36, 40)
	mute_button.pressed.connect(_on_mute_pressed)
	vbox.add_child(mute_button)

	vibration_button = Button.new()
	vibration_button.custom_minimum_size = Vector2(480, 90)
	vibration_button.focus_mode = Control.FOCUS_NONE
	_style_button(vibration_button, Color("5b6bd6"), 36, 40)
	vibration_button.pressed.connect(_on_vibration_pressed)
	vbox.add_child(vibration_button)

	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(480, 100)
	back.focus_mode = Control.FOCUS_NONE
	_style_button(back, Color("ff9f1c"), 40, 44)
	back.pressed.connect(_close_settings)
	vbox.add_child(back)

	_update_volume_label()
	_update_mute_button()
	_update_vibration_button()


func _build_toast() -> void:
	toast_label = Label.new()
	toast_label.position = Vector2(60, 150)
	toast_label.size = Vector2(600, 56)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.add_theme_font_size_override("font_size", 36)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_color_override("font_outline_color", Color("1a2263"))
	toast_label.add_theme_constant_override("outline_size", 10)
	toast_label.modulate.a = 0.0
	add_child(toast_label)


# --------------------------------------------------------------- Helpers

func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _style_button(b: Button, base: Color, radius: int, font_size: int) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		var fill := base
		if state == "hover":
			fill = base.lightened(0.08)
		elif state == "pressed":
			fill = base.darkened(0.12)
		sb.bg_color = fill
		sb.set_corner_radius_all(radius)
		sb.border_width_bottom = 4 if state == "pressed" else 10
		sb.border_color = base.darkened(0.35)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 6)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", base.darkened(0.5))
	b.add_theme_constant_override("outline_size", 10)


func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.18)
	track.set_corner_radius_all(10)
	track.content_margin_top = 10.0
	track.content_margin_bottom = 10.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("3ddc4a")
	fill.set_corner_radius_all(10)
	fill.content_margin_top = 10.0
	fill.content_margin_bottom = 10.0
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _make_knob(56)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	s.add_theme_icon_override("grabber_disabled", knob)


## Кругла біла «ручка» слайдера, створена з радіального градієнта.
func _make_knob(diameter: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.9, Color.WHITE)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = diameter
	tex.height = diameter
	return tex


func _format_number(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return out


func _soon(feature: String) -> void:
	_play_beep()
	toast_label.text = feature + " — незабаром!"
	toast_label.modulate.a = 1.0
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.0)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)


# ------------------------------------------------------------ Callbacks

func _on_play_pressed(mode: String) -> void:
	selected_mode = mode
	get_tree().change_scene_to_file(GAME_SCENE)


func _open_settings() -> void:
	_play_beep()
	settings_page.modulate.a = 0.0
	settings_page.visible = true
	create_tween().tween_property(settings_page, "modulate:a", 1.0, 0.2)


func _close_settings() -> void:
	settings_page.visible = false


func _on_volume_changed(value: float) -> void:
	volume = value
	_apply_audio()
	_update_volume_label()
	_save_settings()


func _on_mute_pressed() -> void:
	muted = not muted
	_apply_audio()
	_update_mute_button()
	_save_settings()
	if not muted:
		_play_beep()


func _on_vibration_pressed() -> void:
	vibration = not vibration
	_update_vibration_button()
	_save_settings()
	if vibration:
		Input.vibrate_handheld(40)


func _update_vibration_button() -> void:
	vibration_button.text = "Вібрація: увімкнено" if vibration else "Вібрація: вимкнено"


# ---------------------------------------------------------------- Audio

func _apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, muted or volume <= 0.0)


func _update_volume_label() -> void:
	volume_label.text = "Гучність: %d%%" % roundi(volume * 100.0)


func _update_mute_button() -> void:
	mute_button.text = "Звук: вимкнено" if muted else "Звук: увімкнено"


func _play_beep() -> void:
	if not muted and volume > 0.0:
		beep_player.play()


## Короткий тестовий звук, згенерований кодом (аудіофайли не потрібні).
func _make_beep(freq: float, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var envelope := 1.0 - float(i) / count
		var sample := int(sin(TAU * freq * t) * envelope * 12000.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# ------------------------------------------------------------- Settings

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		volume = cfg.get_value("audio", "volume", 0.8)
		muted = cfg.get_value("audio", "muted", false)
		vibration = cfg.get_value("game", "vibration", true)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("game", "vibration", vibration)
	cfg.save(SETTINGS_PATH)


func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = cfg.get_value("game", "best_score", 0)


# ------------------------------------------------- Візуальні елементи

## Напівпрозорий об'ємний блок, що пливе на фоні.
class FloatBlock extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		BlockShape.draw_block(self, Rect2(Vector2.ZERO, size), color)


## Кругла іконка-кнопк�� (шестерня, рейтинг, подарунок, профіль).
class IconButton extends Button:
	var kind := "gear"

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(style_name, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var ic := Color(0.85, 0.92, 1.0)
		draw_circle(c, r, Color(1, 1, 1, 0.12))
		draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 3.0)
		match kind:
			"gear":
				draw_arc(c, r * 0.3, 0.0, TAU, 40, ic, r * 0.16)
				for i in 8:
					var dir := Vector2.RIGHT.rotated(TAU * i / 8.0)
					var side := dir.orthogonal() * r * 0.09
					var a := c + dir * r * 0.32
					var b := c + dir * r * 0.55
					draw_colored_polygon(
						PackedVector2Array([a - side, a + side, b + side * 0.8, b - side * 0.8]),
						ic
					)
			"bars":
				var base_y := c.y + r * 0.35
				draw_rect(Rect2(c.x - r * 0.45, base_y - r * 0.3, r * 0.24, r * 0.3), ic)
				draw_rect(Rect2(c.x - r * 0.12, base_y - r * 0.6, r * 0.24, r * 0.6), ic)
				draw_rect(Rect2(c.x + r * 0.21, base_y - r * 0.42, r * 0.24, r * 0.42), ic)
			"gift":
				draw_rect(Rect2(c.x - r * 0.4, c.y - r * 0.02, r * 0.8, r * 0.5), ic)
				draw_rect(Rect2(c.x - r * 0.48, c.y - r * 0.27, r * 0.96, r * 0.26), ic)
				draw_rect(Rect2(c.x - r * 0.07, c.y - r * 0.27, r * 0.14, r * 0.75), Color("2a3a8f"))
				draw_arc(c + Vector2(-r * 0.14, -r * 0.38), r * 0.13, 0.0, TAU, 20, ic, r * 0.07)
				draw_arc(c + Vector2(r * 0.14, -r * 0.38), r * 0.13, 0.0, TAU, 20, ic, r * 0.07)
			"profile":
				draw_circle(c + Vector2(0.0, -r * 0.2), r * 0.2, ic)
				var pts := PackedVector2Array()
				for i in range(0, 17):
					var ang := PI + PI * i / 16.0
					pts.append(Vector2(c.x + cos(ang) * r * 0.4, c.y + r * 0.5 + sin(ang) * r * 0.32))
				draw_colored_polygon(pts, ic)


## Золотий кубок біля рекорду.
class TrophyIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var gold := Color("ffc93c")
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.22 * w, 0.05 * h), Vector2(0.78 * w, 0.05 * h),
			Vector2(0.7 * w, 0.48 * h), Vector2(0.5 * w, 0.58 * h), Vector2(0.3 * w, 0.48 * h),
		]), gold)
		draw_rect(Rect2(0.44 * w, 0.55 * h, 0.12 * w, 0.22 * h), gold.darkened(0.15))
		draw_rect(Rect2(0.28 * w, 0.77 * h, 0.44 * w, 0.14 * h), gold.darkened(0.25))
		draw_arc(Vector2(0.2 * w, 0.25 * h), 0.14 * w, PI * 0.5, PI * 1.5, 12, gold, 0.06 * w)
		draw_arc(Vector2(0.8 * w, 0.25 * h), 0.14 * w, -PI * 0.5, PI * 0.5, 12, gold, 0.06 * w)


## Трикутник «play» на кнопці «Грати».
class PlayIcon extends Control:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(size.x, size.y * 0.5), Vector2(0.0, size.y),
		]), Color("e9ffe9"))
