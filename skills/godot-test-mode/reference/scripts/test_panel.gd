class_name TestPanel
extends CanvasLayer
## Panel del modo de pruebas (spec 014): pestañas con las acciones sobre Platero, la navegación, los enemigos,
## los jefes y el mundo. Hecho con controles estándar; cada botón llama a una función de `TestActions`.
## Se maneja con el mouse (los botones no toman foco: el teclado sigue siendo del juego).

const WIDTH := 300.0
const FONT := 9

var tools: Node
var _tabs: TabContainer
var _room_option: OptionButton
var _enemy_option: OptionButton
var _enemies: Array[EnemyDefinition] = []
var _info: Label
var _boss_info: Label
var _speed_label: Label
var _stats_label: Label
var _runs_label: Label
var _checks: Dictionary = {}
var _pause_check: Button
var _built_stage: StringName = &""


func _init(owner_tools: Node) -> void:
	tools = owner_tools
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(640.0 - WIDTH, 14.0)
	panel.custom_minimum_size = Vector2(WIDTH, 346.0)
	panel.size = Vector2(WIDTH, 346.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.93)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_tabs = TabContainer.new()
	_tabs.add_theme_font_size_override("font_size", 8)
	panel.add_child(_tabs)
	_build_player_tab()
	_build_nav_tab()
	_build_enemies_tab()
	_build_boss_tab()
	_build_world_tab()
	_build_stats_tab()


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()
	if _pause_check != null and _pause_check.button_pressed:
		tools.get_tree().paused = visible


func refresh() -> void:
	var runner: StageRunner = tools.runner()
	_sync_checks()
	if runner != null and runner.stage != null and _built_stage != runner.stage.id:
		_fill_rooms(runner)
	_info.text = _stage_text(runner)
	_boss_info.text = _boss_text(runner)
	_speed_label.text = "Velocidad: ×%s" % str(Engine.time_scale)


func _process(_delta: float) -> void:
	if not visible:
		return
	if Engine.get_process_frames() % 15 == 0:
		refresh()
		_stats_label.text = tools.stats_text()
		_runs_label.text = tools.runs_text()


# --- construcción ------------------------------------------------------------------

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	scroll.add_child(column)
	return column


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FONT)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


## Interruptor: botón que alterna y muestra su estado (SÍ/NO) en el texto.
func _check(parent: Control, key: StringName, text: String, initial: bool, callback: Callable) -> Button:
	var c := Button.new()
	c.toggle_mode = true
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = initial
	c.set_meta(&"base_text", text)
	c.text = _toggle_text(text, initial)
	c.add_theme_font_size_override("font_size", FONT)
	c.toggled.connect(func(on: bool) -> void:
		c.text = _toggle_text(text, on)
		callback.call(on))
	parent.add_child(c)
	_checks[key] = c
	return c


func _toggle_text(text: String, on: bool) -> String:
	return "%s: %s" % [text, "SÍ" if on else "no"]


func _label(parent: Control, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH - 24.0
	l.add_theme_font_size_override("font_size", FONT)
	parent.add_child(l)
	return l


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 2)
	parent.add_child(r)
	return r


func _build_player_tab() -> void:
	var page := _page("Platero")
	_check(page, &"god", "Invulnerable (F3)", tools.god, func(on: bool) -> void: tools.set_god(on))
	_button(page, "Curar (F4)", func() -> void: tools.act(&"heal"))
	var silver := _row(page)
	_button(silver, "+100 plata", func() -> void: tools.act(&"silver", 100))
	_button(silver, "+1000 plata", func() -> void: tools.act(&"silver", 1000))
	_button(page, "Filo al máximo", func() -> void: tools.act(&"edge"))
	_button(page, "Empañar / pulir la espada", func() -> void: tools.act(&"tarnish"))
	_button(page, "Cambiar de patrono", func() -> void: tools.act(&"patron"))
	_button(page, "Subir de nivel (gratis)", func() -> void: tools.act(&"level"))
	_info = _label(page)


func _build_nav_tab() -> void:
	var page := _page("Mapa")
	_room_option = OptionButton.new()
	_room_option.focus_mode = Control.FOCUS_NONE
	_room_option.add_theme_font_size_override("font_size", FONT)
	page.add_child(_room_option)
	_button(page, "Ir a la sala elegida", func() -> void: tools.go_selected_room(_room_option))
	var step := _row(page)
	_button(step, "◀ Sala anterior", func() -> void: tools.act(&"room", -1))
	_button(step, "Sala siguiente ▶", func() -> void: tools.act(&"room", 1))
	_button(page, "Abrir todos los atajos", func() -> void: tools.act(&"shortcuts"))
	_button(page, "Ir a la meta (superar la etapa)", func() -> void: tools.act(&"goal"))
	_button(page, "Volver al Umbral", func() -> void: tools.act(&"umbral"))


func _build_enemies_tab() -> void:
	var page := _page("Enemigos")
	_button(page, "Matar a todos (F2)", func() -> void: tools.act(&"kill_all"))
	_button(page, "Saltar a la oleada siguiente", func() -> void: tools.act(&"skip_wave"))
	_button(page, "Abrir las salidas de la arena", func() -> void: tools.act(&"unlock"))
	_check(page, &"freeze", "Congelar enemigos", tools.freeze_enemies, func(on: bool) -> void: tools.freeze_enemies = on)
	_enemies = TestActions.enemy_definitions()
	_enemy_option = OptionButton.new()
	_enemy_option.focus_mode = Control.FOCUS_NONE
	_enemy_option.add_theme_font_size_override("font_size", FONT)
	for definition in _enemies:
		_enemy_option.add_item("%s (%s)" % [definition.display_name, definition.id])
	page.add_child(_enemy_option)
	_button(page, "Hacer aparecer junto a Platero", func() -> void: tools.spawn_selected(_enemy_option.selected, _enemies))


func _build_boss_tab() -> void:
	var page := _page("Jefes")
	_boss_info = _label(page)
	_button(page, "Siguiente fase (4)", func() -> void: tools.act(&"boss_phase"))
	_button(page, "Dejarlo a 1 de vida (5)", func() -> void: tools.act(&"boss_low"))
	_check(page, &"freeze_boss", "Congelar el patrón del jefe", tools.freeze_boss, func(on: bool) -> void: tools.freeze_boss = on)


func _build_world_tab() -> void:
	var page := _page("Mundo")
	_speed_label = _label(page)
	var speeds := _row(page)
	for speed in TestActions.SPEEDS:
		_button(speeds, "×%s" % str(speed), func() -> void: tools.set_speed(speed))
	_check(page, &"overlay", "Ver cajas de golpe y de daño (3)", tools.show_overlay, func(on: bool) -> void: tools.show_overlay = on)
	_check(page, &"fps", "Mostrar FPS", tools.show_fps, func(on: bool) -> void: tools.show_fps = on)
	_pause_check = _check(page, &"pause", "Pausar mientras el panel está abierto", false, func(on: bool) -> void:
		tools.get_tree().paused = visible and on)
	_label(page, "Atajos: F1 panel · F2 matar · F3 invulnerable · F4 curar · 1/2 velocidad · 0 normal · 3 cajas · 4/5 jefe · 6 plata · 7/8 salas · 9 filo. Se cambian en Controles.")


func _build_stats_tab() -> void:
	var page := _page("Stats")
	_stats_label = _label(page)
	_button(page, "Guardar esta pasada ahora", func() -> void: tools.save_stats_now())
	_label(page, "Últimas pasadas (archivo pruebas_stats.json):")
	_runs_label = _label(page)


# --- estado -------------------------------------------------------------------------

func _sync_checks() -> void:
	for key: StringName in _checks:
		var check: Button = _checks[key]
		match key:
			&"god": _set_toggle(check, tools.god)
			&"freeze": _set_toggle(check, tools.freeze_enemies)
			&"freeze_boss": _set_toggle(check, tools.freeze_boss)
			&"overlay": _set_toggle(check, tools.show_overlay)
			&"fps": _set_toggle(check, tools.show_fps)


func _set_toggle(check: Button, on: bool) -> void:
	check.set_pressed_no_signal(on)
	check.text = _toggle_text(String(check.get_meta(&"base_text")), on)


func _fill_rooms(runner: StageRunner) -> void:
	_room_option.clear()
	for definition in runner.stage.rooms:
		_room_option.add_item("%s (%s)" % [definition.display_name if definition.display_name != "" else String(definition.id), definition.id])
	_built_stage = runner.stage.id


func _stage_text(runner: StageRunner) -> String:
	if runner == null or runner.player == null:
		return "Sin etapa en curso (estás en el Umbral o en un menú)."
	var player := runner.player
	return "%s · sala %s\nCorazones %.1f/%.1f · Filo %.0f/%.0f%s · Plata %d" % [
		runner.stage.display_name, runner.current_room_id, player.hearts, player.max_hearts,
		player.sword.edge, player.sword.max_edge, " (empañada)" if player.sword.tarnished else "", player.silver]


func _boss_text(runner: StageRunner) -> String:
	if runner == null or runner.boss == null or not is_instance_valid(runner.boss) or runner.boss.is_dead():
		return "No hay un jefe vivo en esta sala."
	var boss := runner.boss
	return "%s · fase %d/%d · vida de la fase %.0f · vida total %.0f" % [
		boss.boss.display_name, boss.phase_index + 1, boss.boss.phases.size(), boss.phase_hp, boss.total_hp_left()]
