extends SceneTree
## Spec 014: modo de pruebas. Activación, guardado aparte, saltos, acciones, estadísticas, atajos y preset.
## Uso: Godot_console.exe --headless --path . -s tests/headless/test_mode.gd

const GAME_SCENE := "res://scenes/game/game.tscn"
const TOOLS_SCRIPT := "res://scripts/test/test_tools.gd"
const TMP_STATS := "user://test_mode_stats.json"

var failures: Array[String] = []
var checks := 0
var tools: Node


func _initialize() -> void:
	SaveGame.enabled = false
	AudioSettings.enabled = false
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func new_game(jump: Dictionary) -> Game:
	Launch.test_jump = jump
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as Game
	root.add_child(game)
	await frames(4)
	return game


func clear_game(game: Game) -> void:
	game.queue_free()
	await frames(2)
	for a in InputMap.get_actions():
		Input.action_release(a)


func silver_pickups(runner: StageRunner) -> int:
	var n := 0
	for child in runner.room.get_children():
		if child is SilverPickup:
			n += 1
	return n


func living_enemies(runner: StageRunner) -> int:
	var n := 0
	for node in get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.is_dead() and runner.room.is_ancestor_of(e):
			n += 1
	return n


func _run() -> void:
	# AC-014-1: sin la feature ni el argumento no hay nada.
	TestMode.force = 0
	check(not TestMode.enabled(), "AC-014-1: apagado, TestMode.enabled() es false")
	var autoload := get_root().get_node("TestTools")
	check(autoload.get_child_count() == 0 and not autoload.is_active(), "AC-014-1: el autoload no crea cartel, panel ni nada")
	check(not InputMap.has_action(&"test_panel") and not TestMode.is_active(), "AC-014-1: no hay atajos de pruebas en el InputMap")
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	var has_jump := false
	for button in menu.find_children("*", "Button", true, false):
		has_jump = has_jump or (button as Button).text.begins_with("Saltar")
	check(not has_jump, "AC-014-1: el menú normal no tiene «Saltar a…»")
	menu.queue_free()
	await frames(1)

	# Preset de exportación (AC-014-10).
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "AC-014-10: export_presets.cfg se lee")
	check(String(presets.get_value("preset.0", "custom_features", "")).find("pruebas") < 0 and String(presets.get_value("preset.1", "custom_features", "")).find("pruebas") >= 0, "AC-014-10: solo el preset de pruebas lleva la feature")
	check(presets.get_value("preset.0", "export_path") != presets.get_value("preset.1", "export_path") and String(presets.get_value("preset.1", "name", "")) == "Windows (pruebas)", "AC-014-10: el .exe de pruebas es distinto")

	# AC-014-2: guardado aparte.
	TestMode.force = 1
	var real_save := FileAccess.get_file_as_string("user://save.json") if FileAccess.file_exists("user://save.json") else ""
	TestMode.activate()
	check(TestMode.enabled() and SaveGame.path == TestMode.SAVE_PATH and ControlBindings.path == TestMode.BINDINGS_PATH, "AC-014-2: guardado y controles con archivos propios")
	SaveGame.enabled = true
	var session := GameSession.new(load("res://resources/arcs/arc_i.tres"), load("res://resources/levels/arc_i_levels.tres"))
	session.silver = 123
	SaveGame.save(session)
	SaveGame.enabled = false
	var real_after := FileAccess.get_file_as_string("user://save.json") if FileAccess.file_exists("user://save.json") else ""
	check(FileAccess.file_exists(TestMode.SAVE_PATH) and real_after == real_save, "AC-014-2: guardar no cambia user://save.json")
	SaveGame.delete()

	# AC-014-12: atajos en el InputMap sin chocar con el juego ni entre sí.
	var seen := {}
	var clash := false
	var all_present := true
	for shortcut: Dictionary in TestMode.SHORTCUTS:
		all_present = all_present and InputMap.has_action(shortcut["action"])
		var code := int(shortcut["key"])
		clash = clash or seen.has(code)
		seen[code] = shortcut["action"]
		for game_action in ControlBindings.GAME_ACTIONS:
			if code in ControlBindings.keys_of(game_action):
				clash = true
	check(all_present and not clash, "AC-014-12: cada acción tiene su atajo y ninguno choca con el juego")
	check(ControlBindings.actions().has(&"test_panel") and ControlBindings.label(&"test_god").begins_with("Pruebas"), "AC-015-7: los atajos aparecen en la pantalla de controles")
	check(ControlBindings.set_key(&"test_god", 0, KEY_F9)["ok"] and ControlBindings.clear_key(&"test_god", 0), "AC-015-7: un atajo se puede cambiar y vaciar")
	ControlBindings.reset_all()

	# El menú de pruebas muestra «Saltar a…».
	menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	has_jump = false
	for button in menu.find_children("*", "Button", true, false):
		has_jump = has_jump or (button as Button).text.begins_with("Saltar")
	check(has_jump, "El menú de pruebas tiene «Saltar a…»")
	var jump_screen := JumpScreen.new()
	root.add_child(jump_screen)
	await frames(2)
	jump_screen.arc_option.select(1)
	jump_screen._on_arc_selected(1)
	jump_screen.stage_option.select(3)
	jump_screen._on_stage_selected(3)
	var data := jump_screen.jump_data()
	check(data["arc"] == 1 and data["stage"] == 3 and data["level"] == 4 and data["sword"] == &"sky_silver", "«Saltar a…» propone el equipo del arco y devuelve la elección")
	check(jump_screen.stage_option.item_count == load("res://resources/arcs/arc_ii.tres").stages.size() + (1 if load("res://resources/arcs/arc_ii.tres").interlude != null else 0), "«Saltar a…» lista todas las etapas del arco")
	jump_screen.queue_free()
	menu.queue_free()
	await frames(1)

	# El autoload real, instanciado con el modo encendido: cartel y panel.
	tools = (load(TOOLS_SCRIPT) as GDScript).new()
	tools.stats_path = TMP_STATS
	root.add_child(tools)
	await frames(2)
	check(tools.is_active() and tools.panel() != null and tools.panel()._tabs.get_tab_count() == 6, "Con el modo encendido hay cartel y panel de 6 pestañas")
	tools.panel().toggle()
	tools.panel().toggle()
	check(not tools.panel().visible, "El panel se abre y se cierra")

	# AC-014-3: saltar a cualquier etapa de los tres arcos, sin completar las anteriores.
	var campaign := load("res://resources/campaigns/main_campaign.tres") as CampaignDefinition
	var jump_ok := true
	for arc_index in campaign.arcs.size():
		for stage_index in [0, 3, campaign.arcs[arc_index].stages.size() - 1]:
			var game := await new_game({"arc": arc_index, "stage": stage_index, "level": 2, "silver": 50})
			var arc := campaign.arcs[arc_index]
			jump_ok = jump_ok and game.mode == Game.MODE_STAGE and game.runner != null and game.runner.stage == arc.stages[stage_index] and game.session.arc_index == arc_index
			await clear_game(game)
	check(jump_ok, "AC-014-3: se puede empezar en la etapa 1, 4 y la última de los tres arcos")
	var game := await new_game({"arc": 1, "stage": 5, "room": &"", "level": 4, "silver": 200, "sword": &"sky_silver", "hearts": 1})
	var s := game.session
	check(s.completed.has(campaign.arcs[0].stages[7].id) and s.completed.has(campaign.arcs[1].stages[4].id) and not s.completed.has(campaign.arcs[1].stages[5].id), "AC-014-3: lo anterior queda superado y la etapa elegida no")
	check(s.level == 4 and s.bonus_hearts == 3 and s.silver == 200 and s.sword_id == &"sky_silver", "El equipo inicial se aplica a la sesión (nivel, corazones, plata, espada)")
	check(game.runner.player.max_hearts == 4.0 + 3.0 and game.runner.player.silver == 200 and game.runner.player.sword.definition.id == &"sky_silver", "El equipo inicial llega a Platero")
	var runner := game.runner

	# AC-014-4: teletransporte a cualquier sala.
	var rooms := runner.stage.rooms
	var target := rooms[rooms.size() - 1].id
	check(TestActions.go_to_room(runner, target) and runner.current_room_id == target, "AC-014-4: teletransporta a la última sala de la etapa")
	await frames(2)
	var bounds := runner.room.camera_bounds
	var cam := runner.player.get_node("Camera") as Camera2D
	check(cam.limit_right == int(bounds.end.x) and cam.limit_bottom == int(bounds.end.y) and bounds.has_point(runner.player.global_position), "AC-014-4: la cámara y Platero quedan en la sala nueva")
	var back := TestActions.step_room(runner, 1)
	check(back == rooms[0].id and runner.current_room_id == rooms[0].id, "AC-014-4: «sala siguiente» da la vuelta a la etapa")
	check(TestActions.step_room(runner, -1) == rooms[rooms.size() - 1].id, "AC-014-4: «sala anterior» retrocede")
	check(not TestActions.go_to_room(runner, &"no_existe"), "Ir a una sala inexistente no hace nada")
	check(TestActions.open_all_shortcuts(runner) >= 0, "Abrir todos los atajos no falla")
	await clear_game(game)

	# AC-014-5: matar a todos sin botín, saltar oleadas, abrir arena.
	game = await new_game({"arc": 0, "stage": 0, "room": &"b2"})
	runner = game.runner
	await frames(3)
	check(living_enemies(runner) > 0, "Hay enemigos en la sala antes de matarlos")
	var silver_before := runner.player.silver
	var killed := TestActions.kill_all(runner)
	await frames(60)
	check(killed > 0 and living_enemies(runner) == 0 and silver_pickups(runner) == 0 and runner.player.silver == silver_before, "AC-014-5: matar a todos no suelta plata y no deja enemigos (%d matados, %d vivos, %d monedas)" % [killed, living_enemies(runner), silver_pickups(runner)])
	check(not runner.test_no_loot, "AC-014-5: el modo sin botín se apaga solo")
	var defeated_before := runner.state.defeated.size()
	check(defeated_before > 0, "Las derrotas quedan registradas (la sala no reaparece sin dormir)")
	runner.room.lock_until_clear = true
	runner.state.defeated.clear()
	runner._spawn_encounters()
	await frames(4)
	var locked := not runner.room.exits.is_empty()
	for ex in runner.room.exits:
		locked = locked and ex.locked
	check(locked, "La arena forzada cierra sus salidas")
	var arena_enemies := living_enemies(runner)
	runner.skip_wave()
	await frames(4)
	check(living_enemies(runner) >= arena_enemies, "Saltar la oleada hace aparecer la siguiente sin vencer la actual")
	runner.unlock_exits()
	var unlocked := true
	for ex in runner.room.exits:
		unlocked = unlocked and not ex.locked
	check(unlocked and not runner._arena_locked, "AC-014-5: abrir las salidas desbloquea la arena")
	var spawned := TestActions.spawn_enemy(runner, load("res://resources/enemies/clock_moth.tres"), true)
	await frames(2)
	check(spawned != null and spawned.frozen and spawned.get_parent() == runner.room, "Hacer aparecer un enemigo (congelado) junto a Platero")
	var defs := TestActions.enemy_definitions()
	var ids := defs.map(func(d: EnemyDefinition) -> StringName: return d.id)
	check(ids.has(&"clock_moth") and ids.has(&"dream_owl") and not ids.has(&"polemarch_body"), "La lista de enemigos incluye los menores y excluye los cuerpos de jefe")

	# AC-014-6: invulnerable.
	var player := runner.player
	var hearts := player.hearts
	var hurt := [0.0]
	player.hurt.connect(func(a: float) -> void: hurt[0] += a)
	player.test_god = true
	player.invuln_time = 0.0
	player.take_damage(2.0, player.global_position + Vector2(10, 0))
	check(player.hearts == hearts and hurt[0] == 2.0 and player.stagger_time > 0.0, "AC-014-6: invulnerable recibe la reacción pero no pierde corazones")
	player.invuln_time = 0.0
	var shock := Shockwave.new()
	shock.position = player.global_position
	runner.room.add_child(shock)
	await frames(3)
	check(player.hearts == hearts, "AC-014-6: una onda de jefe tampoco le quita corazones")
	player.test_god = false
	player.invuln_time = 0.0
	player.take_damage(1.0, player.global_position + Vector2(10, 0))
	check(player.hearts == hearts - 1.0, "AC-014-6: sin invulnerabilidad el daño vuelve a contar")

	# Acciones sobre Platero.
	TestActions.heal(player)
	check(player.hearts == player.max_hearts, "Curar llena los corazones")
	player.sword.wear(40.0)
	TestActions.edge_to_max(player)
	check(player.sword.edge == player.sword.max_edge, "Filo al máximo")
	check(TestActions.toggle_tarnish(player) and player.sword.tarnished and not TestActions.toggle_tarnish(player), "Empañar y pulir la espada")
	var level_before := game.session.level
	var perk := TestActions.force_level_up(game.session, player)
	check(perk != &"" and game.session.level == level_before + 1, "Subir de nivel gratis aplica la mejora")
	check(TestActions.step_speed(1) == 2.0 and Engine.time_scale == 2.0 and TestActions.step_speed(-2) == 0.5 and TestActions.set_speed(1.0) == 1.0, "Velocidades por pasos y reposición a ×1")
	await clear_game(game)

	# AC-014-7: jefes.
	game = await new_game({"arc": 1, "stage": 3})
	runner = game.runner
	await frames(3)
	var boss := runner.boss
	check(boss != null and boss.phase_index == 0, "AC-014-7: saltar al subjefe del arco II lo hace aparecer")
	TestActions.boss_to_one_hp(boss)
	check(boss.phase_hp == 1.0 and boss.total_hp_left() == 1.0 + boss.boss.phases[1].hp, "AC-014-7: dejar al jefe a 1 de vida")
	TestActions.boss_next_phase(boss)
	check(boss.phase_index == 1, "AC-014-7: pasar a la fase siguiente")
	TestActions.boss_next_phase(boss)
	await frames(2)
	check(boss.is_dead(), "AC-014-7: pasar la última fase lo vence")
	await frames(200)
	check(game.mode != Game.MODE_STAGE or runner.state.boss_defeated, "AC-014-7: el flujo posterior (fin de etapa) sigue funcionando")
	await clear_game(game)

	# Atajos, banderas y velocidad (AC-014-8).
	game = await new_game({"arc": 0, "stage": 0})
	current_scene = game
	await frames(3)
	check(tools.runner() == game.runner and tools.runner() != null, "TestTools encuentra la etapa en curso")
	var toggle := InputEventAction.new()
	toggle.action = &"test_god"
	toggle.pressed = true
	tools._unhandled_input(toggle)
	await frames(2)
	check(tools.god and game.runner.player.test_god, "El atajo de invulnerable (F3) la activa en Platero")
	tools.set_god(false)
	var speed_up := InputEventAction.new()
	speed_up.action = &"test_speed_up"
	speed_up.pressed = true
	tools._unhandled_input(speed_up)
	check(Engine.time_scale == 2.0, "El atajo de velocidad sube a ×2")
	tools.show_overlay = true
	await frames(3)
	check(tools._overlay != null and is_instance_valid(tools._overlay) and tools._overlay.get_parent() == game.runner, "El overlay de cajas se agrega a la etapa")
	tools.show_overlay = false
	await frames(3)
	check(tools._overlay == null, "El overlay se quita al apagarlo")
	tools.freeze_enemies = true
	TestActions.spawn_enemy(game.runner, load("res://resources/enemies/clock_moth.tres"))
	await frames(3)
	var all_frozen := true
	for node in get_nodes_in_group("enemies"):
		all_frozen = all_frozen and (node as Enemy).frozen
	check(all_frozen, "«Congelar enemigos» detiene a todos")
	tools.freeze_enemies = false
	await frames(3)
	var none_frozen := true
	for node in get_nodes_in_group("enemies"):
		none_frozen = none_frozen and not (node as Enemy).frozen
	check(none_frozen, "Al soltar «congelar», vuelven a moverse")

	# AC-014-11: estadísticas.
	var stats := tools.stats as TestStats
	check(stats != null and stats.runner == game.runner, "AC-014-11: las estadísticas miden la etapa en curso")
	game.runner.player.invuln_time = 0.0
	game.runner.player.take_damage(1.5, game.runner.player.global_position + Vector2(5, 0))
	game.runner.player.sword.wear(7.0)
	game.runner.player.add_silver(40)
	await frames(3)
	check(is_equal_approx(stats.damage_taken, 1.5) and is_equal_approx(stats.edge_spent, 7.0) and stats.silver_earned == 40 and stats.seconds > 0.0, "AC-014-11: daño, filo y plata contados")
	stats.seconds = 10.0
	if FileAccess.file_exists(TMP_STATS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_STATS))
	tools.finish_stats()
	var runs := TestStats.read_runs(TMP_STATS)
	check(runs.size() == 1 and runs[0]["damage_taken"] == 1.5 and runs[0]["silver_earned"] == 40 and runs[0]["stage"] != "", "AC-014-11: la pasada se vuelca al archivo de estadísticas")

	# AC-014-8: la velocidad vuelve a ×1 al salir al menú (sin Game como escena actual).
	TestActions.set_speed(4.0)
	current_scene = null
	game.queue_free()
	await frames(4)
	check(is_equal_approx(Engine.time_scale, 1.0), "AC-014-8: al volver al menú la velocidad es ×1")

	# Limpieza.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_STATS))
	tools.queue_free()
	TestMode.deactivate()
	TestMode.force = -1
	Engine.time_scale = 1.0
	check(SaveGame.path == "user://save.json" and not InputMap.has_action(&"test_panel"), "Al desactivar se restauran el guardado y el InputMap")
	print("Modo de pruebas: %d controles / %d fallos" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
