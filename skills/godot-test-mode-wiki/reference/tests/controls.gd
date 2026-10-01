extends SceneTree
## Spec 015: controles remapeables. Lógica de ControlBindings y pantalla de controles.
## Uso: Godot_console.exe --headless --path . -s tests/headless/controls.gd

const TMP := "user://test_input_bindings.json"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	SaveGame.enabled = false
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)


func motion_count(action: StringName) -> int:
	var n := 0
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion:
			n += 1
	return n


func key_event(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	e.keycode = code as Key
	e.pressed = true
	return e


func _run() -> void:
	ControlBindings.path = TMP
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	ControlBindings.ensure_loaded()
	ControlBindings.reset_all()

	# AC-015-1: acciones del juego, dos teclas y un botón.
	var actions := ControlBindings.actions()
	check(actions.size() >= 11, "Hay al menos las 11 acciones del juego")
	var all_exist := true
	for a in actions:
		all_exist = all_exist and InputMap.has_action(a)
	check(all_exist, "Cada acción existe en el InputMap")
	check(ControlBindings.keys_of(&"jump") == [KEY_SPACE, KEY_W] and ControlBindings.joy_of(&"jump") == [0], "Valores de fábrica de Saltar: Espacio, W y botón A")

	# AC-015-2 / 015-4: cambio inmediato, por posición física.
	var motion_before := motion_count(&"move_left")
	var result := ControlBindings.set_key(&"jump", 0, KEY_Z)
	check(result["ok"] and ControlBindings.keys_of(&"jump")[0] == KEY_Z, "Cambiar la tecla de Saltar se aplica al InputMap")
	var found_physical := false
	for e in InputMap.action_get_events(&"jump"):
		if e is InputEventKey and e.physical_keycode == KEY_Z:
			found_physical = true
	check(found_physical, "La tecla queda como posición física")
	var moved := ControlBindings.set_key(&"move_left", 1, KEY_Q)
	check(moved["ok"] and motion_count(&"move_left") == motion_before, "Los ejes del stick se conservan al remapear el movimiento")
	ControlBindings.save()
	var saved := JSON.parse_string(FileAccess.get_file_as_string(TMP)) as Dictionary
	var bindings: Dictionary = saved["bindings"]
	check(bindings.has("jump") and bindings.has("move_left") and bindings.size() == 2, "El archivo guarda solo las acciones modificadas")

	# AC-015-3: intercambio y rechazo.
	var attack_before := ControlBindings.keys_of(&"attack")[0]
	var swap := ControlBindings.set_key(&"attack", 0, KEY_Z)
	check(swap["ok"] and swap["swapped"] == &"jump" and ControlBindings.keys_of(&"jump")[0] == attack_before, "Una tecla usada por otra acción se intercambia")
	check(ControlBindings.clear_key(&"craft", 0) and not ControlBindings.clear_joy(&"craft", 0), "Se puede vaciar una casilla pero no dejar a Pulir sin control")
	ControlBindings.reset(&"craft")
	var same := ControlBindings.set_key(&"move_right", 0, KEY_Z)
	check(same["ok"] and ControlBindings.keys_of(&"move_right")[0] == KEY_Z, "Tomar una tecla ocupada también la quita de la otra acción")
	check(not ControlBindings.set_key(&"jump", 0, KEY_SHIFT)["ok"], "Un modificador solo no es una tecla válida")
	var dup := ControlBindings.set_key(&"jump", 0, ControlBindings.keys_of(&"jump")[1])
	check(dup["ok"] and ControlBindings.keys_of(&"jump")[0] != ControlBindings.keys_of(&"jump")[1], "Repetir la tecla de la otra casilla las intercambia")

	# Botones de mando.
	var joy := ControlBindings.set_joy(&"jump", 0, 3)
	check(joy["ok"] and ControlBindings.joy_of(&"jump")[0] == 3 and ControlBindings.joy_of(&"craft")[0] != 3, "Un botón usado por otra acción se intercambia")

	# AC-015-5: restaurar.
	ControlBindings.reset_all()
	var clean := true
	for a in ControlBindings.actions():
		clean = clean and ControlBindings.is_default(a)
	ControlBindings.save()
	var after := JSON.parse_string(FileAccess.get_file_as_string(TMP)) as Dictionary
	check(clean and (after["bindings"] as Dictionary).is_empty(), "Restaurar todo deja los valores de fábrica y el archivo sin diferencias")

	# AC-015-2: persistencia (guardar, restaurar y volver a leer).
	ControlBindings.set_key(&"attack", 0, KEY_P)
	ControlBindings.save()
	ControlBindings.reset_all()
	check(ControlBindings.keys_of(&"attack")[0] != KEY_P, "Tras restaurar, la tecla cambiada ya no está")
	ControlBindings.reload_saved()
	check(ControlBindings.keys_of(&"attack")[0] == KEY_P, "Recargar lee las preferencias guardadas")
	ControlBindings.reset_all()

	# AC-015-6: archivos inválidos.
	for garbage in ["no es json", "{\"version\": 99, \"bindings\": {\"jump\": {\"keys\": [90, 0], \"joy\": [0]}}}",
			"{\"version\": 1, \"bindings\": {\"accion_inventada\": {\"keys\": [65]}, \"jump\": {\"keys\": [\"x\", null], \"joy\": [\"y\"]}}}",
			"{\"version\": 1, \"bindings\": 5}"]:
		var file := FileAccess.open(TMP, FileAccess.WRITE)
		file.store_string(garbage)
		file.close()
		ControlBindings.reload_saved()
		var ok := true
		for a in ControlBindings.actions():
			ok = ok and ControlBindings.is_default(a)
		check(ok, "Archivo inválido ignorado: " + garbage.substr(0, 28))

	# AC-015-1 / 015-8: la pantalla.
	var screen := ControlsScreen.new()
	root.add_child(screen)
	await process_frame
	check(screen._buttons.size() == ControlBindings.actions().size() * (ControlBindings.KEY_SLOTS + ControlBindings.JOY_SLOTS), "La pantalla tiene una casilla por cada tecla y botón de cada acción")
	screen._begin_capture(&"jump", &"key", 0)
	check(screen.is_capturing(), "Al elegir una casilla espera una tecla")
	screen._input(key_event(KEY_ESCAPE))
	check(not screen.is_capturing() and is_instance_valid(screen), "Esc cancela la captura sin cerrar la pantalla")
	screen._begin_capture(&"jump", &"key", 0)
	screen._input(key_event(KEY_Y))
	check(ControlBindings.keys_of(&"jump")[0] == KEY_Y and not screen.is_capturing(), "La pantalla aplica la tecla apretada")
	screen._begin_capture(&"jump", &"joy", 0)
	var button_event := InputEventJoypadButton.new()
	button_event.button_index = JOY_BUTTON_X
	button_event.pressed = true
	screen._input(button_event)
	check(ControlBindings.joy_of(&"jump")[0] == JOY_BUTTON_X, "La pantalla aplica el botón de mando apretado")
	screen._begin_capture(&"jump", &"key", 1)
	screen._input(key_event(KEY_DELETE))
	check(ControlBindings.keys_of(&"jump")[1] == 0, "Supr vacía la casilla elegida")
	screen._on_reset_all()
	var screen_clean := true
	for a in ControlBindings.actions():
		screen_clean = screen_clean and ControlBindings.is_default(a)
	check(screen_clean, "«Restaurar todo» de la pantalla devuelve los valores de fábrica")
	var closed := [false]
	screen.closed.connect(func() -> void: closed[0] = true)
	screen._input(key_event(KEY_ESCAPE))
	await process_frame
	check(closed[0], "Esc sin captura cierra la pantalla")

	# Menú principal y pausa abren la pantalla.
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	menu._on_controls()
	check(menu._controls != null, "El menú principal abre los controles")
	menu.queue_free()
	var pause := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	root.add_child(pause)
	pause._on_controls()
	check(pause._controls != null, "La pausa abre los controles")
	pause.queue_free()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("Controles remapeables: %d controles / %d fallos" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
