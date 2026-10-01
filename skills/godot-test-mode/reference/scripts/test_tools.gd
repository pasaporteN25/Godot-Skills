extends Node
## Autoload del modo de pruebas (spec 014). Sin la feature `pruebas` ni el argumento `--pruebas` no hace nada:
## no crea cartel, panel ni atajos. Con ellos: cartel "MODO PRUEBAS", panel (F1), atajos `test_*`, capa de
## cajas de golpe y estadísticas por etapa. (Sin `class_name`: el autoload ya se llama TestTools.)

## Atajos que ejecutan una acción simple de `act`.
const SIMPLE_ACTIONS := {
	&"test_kill_all": &"kill_all", &"test_heal": &"heal", &"test_silver": &"silver", &"test_edge": &"edge",
	&"test_room_prev": &"room_prev", &"test_room_next": &"room_next", &"test_boss_phase": &"boss_phase",
	&"test_boss_low": &"boss_low",
}

var god: bool = false
var freeze_enemies: bool = false
var freeze_boss: bool = false
var show_overlay: bool = false
var show_fps: bool = false
var stats: TestStats
## Archivo de estadísticas (las pruebas automáticas lo cambian).
var stats_path: String = TestMode.STATS_PATH

var _panel: TestPanel
var _banner: Label
var _overlay: TestOverlay
var _completed: bool = false
var _froze_enemies: bool = false
var _froze_boss: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not TestMode.enabled():
		set_process(false)
		set_process_unhandled_input(false)
		return
	TestMode.activate()
	ControlBindings.ensure_loaded()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_banner = Label.new()
	_banner.position = Vector2(400.0, 0.0)
	_banner.custom_minimum_size = Vector2(236.0, 0.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_banner.add_theme_font_size_override("font_size", 9)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_banner.add_theme_constant_override("outline_size", 2)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_banner)
	_panel = TestPanel.new(self)
	add_child(_panel)
	_update_banner()


# --- acceso al juego -------------------------------------------------------------------

func game() -> Game:
	return get_tree().current_scene as Game


## La etapa en curso, o null si se está en el Umbral, en un menú o en una pantalla final.
func runner() -> StageRunner:
	var g := game()
	if g == null or g.mode != Game.MODE_STAGE or g.runner == null or not is_instance_valid(g.runner):
		return null
	return g.runner if g.runner.player != null else null


## Hay cartel y panel (el modo está encendido y el autoload los armó).
func is_active() -> bool:
	return _banner != null


func panel() -> TestPanel:
	return _panel


# --- cada cuadro -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var current := runner()
	_track_stats(current)
	if current != null:
		_apply_flags(current)
	_sync_overlay(current)
	if game() == null and not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0
	_update_banner()


func _apply_flags(current: StageRunner) -> void:
	current.player.test_god = god
	var freeze_changed := freeze_enemies != _froze_enemies or freeze_boss != _froze_boss
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var boss := enemy.is_in_group("bosses")
		if boss and freeze_boss:
			enemy.frozen = true
		elif not boss and freeze_enemies:
			enemy.frozen = true
		elif freeze_changed and enemy.frozen:
			enemy.frozen = false
	_froze_enemies = freeze_enemies
	_froze_boss = freeze_boss


func _sync_overlay(current: StageRunner) -> void:
	var wanted := show_overlay and current != null
	if wanted and (_overlay == null or not is_instance_valid(_overlay) or _overlay.get_parent() != current):
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.queue_free()
		_overlay = TestOverlay.new()
		current.add_child(_overlay)
	elif not wanted and _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null


func _update_banner() -> void:
	if _banner == null:
		return
	var text := "MODO PRUEBAS"
	if not is_equal_approx(Engine.time_scale, 1.0):
		text += "  ×%s" % str(Engine.time_scale)
	if god:
		text += "  INVULN"
	if show_fps:
		text += "  %d FPS" % Engine.get_frames_per_second()
	_banner.text = text


# --- estadísticas --------------------------------------------------------------------------

func _track_stats(current: StageRunner) -> void:
	if stats != null and stats.runner != current:
		finish_stats()
	if current != null and stats == null:
		stats = TestStats.new()
		add_child(stats)
		stats.bind(current)
		_completed = false
	if stats != null and stats.runner != null and is_instance_valid(stats.runner):
		_completed = _completed or stats.runner.state.completed


## Cierra la medición de la etapa en curso (al salir de ella o al cerrar el juego).
func finish_stats() -> void:
	if stats == null:
		return
	stats.finish(&"completed" if _completed else &"left", stats_path)
	stats.queue_free()
	stats = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_active():
		finish_stats()


func save_stats_now() -> void:
	if stats != null:
		TestStats.append_run(stats.to_dict(&"manual"), stats_path)


func stats_text() -> String:
	if stats == null:
		return "Sin etapa en curso."
	return stats.summary()


func runs_text() -> String:
	var runs := TestStats.read_runs(stats_path)
	if runs.is_empty():
		return "Todavía no hay pasadas guardadas."
	var lines: Array[String] = []
	for run: Dictionary in runs.slice(maxi(0, runs.size() - 5)):
		lines.append("%s · %s · daño %s · filo %s · plata %s · muertes %s · %s" % [
			run.get("stage", "?"), run.get("outcome", "?"), run.get("damage_taken", 0), run.get("edge_spent", 0),
			run.get("silver_earned", 0), run.get("deaths", 0), TestStats.format_time(float(run.get("seconds", 0.0)))])
	return "\n".join(lines)


# --- acciones (panel y atajos) ----------------------------------------------------------------

func set_god(on: bool) -> void:
	god = on
	var current := runner()
	if current != null:
		current.player.test_god = on


func set_speed(value: float) -> void:
	TestActions.set_speed(value)


func go_selected_room(option: OptionButton) -> void:
	var current := runner()
	if current != null and option.selected >= 0 and option.selected < current.stage.rooms.size():
		TestActions.go_to_room(current, current.stage.rooms[option.selected].id)


func spawn_selected(index: int, definitions: Array[EnemyDefinition]) -> void:
	var current := runner()
	if current != null and index >= 0 and index < definitions.size():
		TestActions.spawn_enemy(current, definitions[index], freeze_enemies)


## Ejecuta una acción por nombre. Sin etapa en curso, las que la necesitan no hacen nada.
func act(action: StringName, arg: Variant = null) -> void:
	var current := runner()
	var g := game()
	if action == &"umbral":
		if g != null:
			g.go_umbral()
		return
	if current == null:
		return
	var boss := current.boss if current.boss != null and is_instance_valid(current.boss) and not current.boss.is_dead() else null
	match action:
		&"heal": TestActions.heal(current.player)
		&"silver": TestActions.add_silver(current.player, int(arg) if arg != null else 1000)
		&"edge": TestActions.edge_to_max(current.player)
		&"tarnish": TestActions.toggle_tarnish(current.player)
		&"patron": TestActions.cycle_patron(g.session, current.player)
		&"level": TestActions.force_level_up(g.session, current.player)
		&"room": TestActions.step_room(current, int(arg))
		&"room_prev": TestActions.step_room(current, -1)
		&"room_next": TestActions.step_room(current, 1)
		&"shortcuts": TestActions.open_all_shortcuts(current)
		&"goal": TestActions.complete_stage(current)
		&"kill_all": TestActions.kill_all(current)
		&"skip_wave": current.skip_wave()
		&"unlock": current.unlock_exits()
		&"boss_phase":
			if boss != null:
				TestActions.boss_next_phase(boss)
		&"boss_low":
			if boss != null:
				TestActions.boss_to_one_hp(boss)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"test_panel"):
		_panel.toggle()
	elif event.is_action_pressed(&"test_god"):
		set_god(not god)
	elif event.is_action_pressed(&"test_overlay"):
		show_overlay = not show_overlay
	elif event.is_action_pressed(&"test_speed_down"):
		TestActions.step_speed(-1)
	elif event.is_action_pressed(&"test_speed_up"):
		TestActions.step_speed(1)
	elif event.is_action_pressed(&"test_speed_reset"):
		TestActions.set_speed(1.0)
	else:
		for action: StringName in SIMPLE_ACTIONS:
			if event.is_action_pressed(action):
				act(SIMPLE_ACTIONS[action])
				return
