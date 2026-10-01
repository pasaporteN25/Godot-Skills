extends SceneTree
## Spec 016: wiki del juego. Entradas desde los datos, bestiario cerrado, progreso, índice y pantalla.
## Uso: Godot_console.exe --headless --path . -s tests/headless/wiki.gd

const PROGRESS_TMP := "user://test_wiki_progress.json"
const BINDINGS_TMP := "user://test_wiki_bindings.json"
const NEW_ENEMY := "res://resources/enemies/zz_test_enemy.tres"

var failures: Array[String] = []
var checks := 0


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


func all_seen(_kind: StringName, _id: StringName) -> bool:
	return true


func none_seen(_kind: StringName, _id: StringName) -> bool:
	return false


func by_id(categories: Array[WikiCategory], id: StringName) -> WikiCategory:
	for c in categories:
		if c.id == id:
			return c
	return null


func fact(entry: WikiEntry, name: String) -> String:
	for block in entry.blocks:
		for row: Array in block.get("filas", []):
			if row.size() == 2 and String(row[0]) == name:
				return String(row[1])
	return ""


func count_files(dir: String, skip_body: bool) -> int:
	var n := 0
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres") and not (skip_body and file.ends_with("_body.tres")):
			n += 1
	return n


func has_digit(text: String) -> bool:
	for ch in text:
		if ch >= "0" and ch <= "9":
			return true
	return false


func _run() -> void:
	TestMode.force = 0
	WikiProgress.path = PROGRESS_TMP
	WikiProgress.erase_file()

	# AC-016-1: categorías y entradas desde los datos.
	var open := Wiki.categories(all_seen)
	var ids: Array[StringName] = []
	for c in open:
		ids.append(c.id)
	check(ids == [&"enemigos", &"jefes", &"patronos", &"espadas", &"lugares", &"guia"], "AC-016-1: seis categorías en orden")
	check(by_id(open, &"enemigos").entries.size() == count_files("res://resources/enemies/", true), "AC-016-1: un enemigo menor por cada .tres (sin los cuerpos de jefe)")
	check(by_id(open, &"jefes").entries.size() == count_files("res://resources/bosses/", false), "AC-016-1: un jefe por cada .tres")
	check(by_id(open, &"espadas").entries.size() == SwordCatalog.PATHS.size(), "AC-016-1: una espada por cada entrada del catálogo")
	var complete := true
	for c in open:
		for e in c.entries:
			complete = complete and not e.locked and e.title != "" and not e.blocks.is_empty()
	check(complete, "AC-016-1: todas las entradas abiertas tienen título y contenido")

	# AC-016-2: lo cerrado no filtra nada.
	var closed := Wiki.categories(none_seen)
	var leaks := false
	var all_locked := true
	for c in closed:
		if c.id == &"guia":
			continue
		for e in c.entries:
			all_locked = all_locked and e.locked and e.title == Wiki.LOCKED_TITLE
			var plain := e.plain_text()
			leaks = leaks or has_digit(plain)
	for resource in Wiki._load_all(Wiki.ENEMIES_DIR):
		var def := resource as EnemyDefinition
		for c in closed:
			if c.id == &"guia":
				continue
			for e in c.entries:
				leaks = leaks or e.plain_text().contains(def.display_name)
	check(all_locked and not leaks, "AC-016-2: lo cerrado es «???» y no lleva nombres ni números")
	check(not by_id(closed, &"guia").entries[0].locked, "AC-016-2: la Guía nunca está cerrada")
	check(by_id(closed, &"enemigos").find(&"clock_moth").icon != null, "AC-016-2: lo cerrado conserva el dibujo (para la silueta)")

	# AC-016-3: se abre al descubrirlo.
	var before := Wiki.categories()
	check(by_id(before, &"enemigos").unlocked_count() == 0 and by_id(before, &"jefes").unlocked_count() == 0, "AC-016-3: sin descubrir, todo está cerrado")
	var world := Node2D.new()
	root.add_child(world)
	var moth_def := load("res://resources/enemies/clock_moth.tres") as EnemyDefinition
	var moth := moth_def.scene.instantiate() as Enemy
	moth.definition = moth_def
	world.add_child(moth)
	var boss_def := load("res://resources/bosses/polemarch.tres") as BossDefinition
	var boss := boss_def.scene.instantiate() as BossController
	boss.definition = boss_def.enemy
	boss.boss = boss_def
	world.add_child(boss)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	world.add_child(player)
	await frames(2)
	player.patron.equip(load("res://resources/patrons/hephaestus.tres"))
	player.equip_sword(load("res://resources/swords/sky_silver.tres"))
	var runner := (load("res://scenes/stage/stage_runner.tscn") as PackedScene).instantiate() as StageRunner
	runner.stage = load("res://resources/stages/arc1_stage1.tres")
	runner.session = GameSession.new(load("res://resources/arcs/arc_i.tres"), load("res://resources/levels/arc_i_levels.tres"))
	root.add_child(runner)
	await frames(2)
	var after := Wiki.categories()
	check(by_id(after, &"enemigos").find(&"clock_moth") != null and not by_id(after, &"enemigos").find(&"clock_moth").locked, "AC-016-3: ver a la polilla abre su entrada")
	check(by_id(after, &"enemigos").find(&"marsh_crab").locked, "AC-016-3: un enemigo no visto sigue cerrado")
	check(not by_id(after, &"jefes").find(&"polemarch").locked and by_id(after, &"jefes").find(&"hypnos").locked, "AC-016-3: entrar a la arena abre al jefe (y solo a ese)")
	check(not by_id(after, &"patronos").find(&"hephaestus").locked and by_id(after, &"patronos").find(&"artemis").locked, "AC-016-3: equipar un patrono abre el suyo")
	check(not by_id(after, &"espadas").find(&"heirloom_falcata").locked and not by_id(after, &"espadas").find(&"sky_silver").locked, "AC-016-3: empuñar una espada abre la suya")
	check(not by_id(after, &"lugares").find(&"arc_i").locked and by_id(after, &"lugares").find(&"arc_ii").locked, "AC-016-3: entrar a una etapa abre el arco")
	var arc_entry := by_id(after, &"lugares").find(&"arc_i")
	var visible_stages := 0
	for block in arc_entry.blocks:
		for row: Array in block.get("filas", []):
			if String(row[0]) == "1. El pueblo":
				visible_stages += 1
	check(visible_stages == 1, "AC-016-3: de un arco abierto solo se nombran las etapas visitadas")

	# AC-016-4: los datos salen del Resource.
	var hoplite := load("res://resources/enemies/dream_hoplite.tres") as EnemyDefinition
	var hoplite_entry := Wiki.enemy_entry(hoplite)
	check(fact(hoplite_entry, "Vida") == Wiki._number(hoplite.max_hp) and fact(hoplite_entry, "Armadura") == Wiki._number(hoplite.armor), "AC-016-4: vida y armadura del Hoplita coinciden con su Resource")
	var original_armor := hoplite.armor
	hoplite.armor = 77.0
	check(fact(Wiki.enemy_entry(hoplite), "Armadura") == "77", "AC-016-4: si el Resource cambia, la wiki cambia")
	hoplite.armor = original_armor
	var boss_entry := Wiki.boss_entry(boss_def)
	check(fact(boss_entry, "Fases") == str(boss_def.phases.size()) and fact(boss_entry, "Armadura") == Wiki._number(boss_def.enemy.armor), "AC-016-4: fases y armadura del jefe coinciden")
	check(boss_entry.plain_text().contains("Maratón") or boss_entry.plain_text().contains("Polemarco"), "AC-016-4: el jefe lleva su nombre y su frase")
	var sword_entry := Wiki.sword_entry(load("res://resources/swords/sky_silver.tres"))
	check(fact(sword_entry, "Filo máximo") == "120" and fact(sword_entry, "Daño base") == "13", "AC-016-4: los datos de la espada salen de su Resource")
	var shadow_entry := Wiki.enemy_entry(load("res://resources/enemies/shadow.tres"))
	check(fact(shadow_entry, "La espada lo atraviesa") == "sí" and shadow_entry.plain_text().contains("roba plata"), "AC-016-4: las banderas del dato (inmune a la espada) aparecen")

	# AC-016-5: índice «dónde aparece».
	check(WikiIndex.to_json(WikiIndex.build()) == FileAccess.get_file_as_string(WikiIndex.PATH), "AC-016-5: appearances.json está al día (si falla: tools/build_wiki_index.gd)")
	var moth_entry := Wiki.enemy_entry(moth_def)
	check(moth_entry.plain_text().contains("Arco I — Tartessos · 1. El pueblo"), "AC-016-5: «dónde aparece» nombra la etapa real")
	check(Wiki.enemy_entry(load("res://resources/enemies/reflection.tres")).plain_text().contains("Arco I — Tartessos · Jefe: Argantonio"), "AC-016-5: el Reflejo figura en la arena de Argantonio (nota «tambien_en»)")

	# AC-016-6: progreso persistente y aparte de la partida.
	WikiProgress.erase_file()
	SaveGame.enabled = true
	WikiProgress.mark(WikiProgress.ENEMY, &"marsh_crab")
	check(FileAccess.file_exists(PROGRESS_TMP), "AC-016-6: descubrir algo escribe el archivo")
	WikiProgress.forget()
	check(WikiProgress.is_seen(WikiProgress.ENEMY, &"marsh_crab") and not WikiProgress.is_seen(WikiProgress.ENEMY, &"shadow"), "AC-016-6: el progreso se vuelve a leer del archivo")
	SaveGame.enabled = false
	var content := FileAccess.get_file_as_string(PROGRESS_TMP)
	WikiProgress.mark(WikiProgress.ENEMY, &"shadow")
	check(FileAccess.get_file_as_string(PROGRESS_TMP) == content and WikiProgress.is_seen(WikiProgress.ENEMY, &"shadow"), "AC-016-6: con el guardado apagado se anota en memoria pero no se escribe")
	var other_path := WikiProgress.path
	check(other_path != SaveGame.path and not FileAccess.get_file_as_string(PROGRESS_TMP).contains("\"silver\""), "AC-016-6: es un archivo distinto de la partida")
	var garbage := FileAccess.open(PROGRESS_TMP, FileAccess.WRITE)
	garbage.store_string("{no es json")
	garbage.close()
	WikiProgress.forget()
	check(not WikiProgress.is_seen(WikiProgress.ENEMY, &"marsh_crab"), "AC-016-6: un archivo dañado se ignora")

	# AC-016-7: modo de pruebas.
	TestMode.force = 1
	var test_cats := Wiki.categories()
	var any_locked := false
	for c in test_cats:
		any_locked = any_locked or c.unlocked_count() < c.entries.size()
	check(not any_locked, "AC-016-7: en modo de pruebas todo está abierto")
	TestMode.force = 0

	# AC-016-9: «Controles» refleja el InputMap.
	ControlBindings.path = BINDINGS_TMP
	ControlBindings.ensure_loaded()
	ControlBindings.reset_all()
	ControlBindings.set_key(&"jump", 0, KEY_Z)
	var controls := Wiki.controls_entry()
	var jump_row := ""
	for row: Array in (controls.blocks[0]["filas"] as Array):
		if String(row[0]) == "Saltar":
			jump_row = String(row[1])
	check(jump_row.contains("Z"), "AC-016-9: «Controles» muestra la tecla cambiada (%s)" % jump_row)
	ControlBindings.reset_all()
	if FileAccess.file_exists(BINDINGS_TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BINDINGS_TMP))

	# AC-016-10: un enemigo nuevo aparece solo.
	var fresh := EnemyDefinition.new()
	fresh.id = &"zz_test_enemy"
	fresh.display_name = "Enemigo de prueba"
	fresh.scene = moth_def.scene
	fresh.max_hp = 999.0
	ResourceSaver.save(fresh, NEW_ENEMY)
	var with_new := Wiki.categories(all_seen)
	var added := by_id(with_new, &"enemigos").find(&"zz_test_enemy")
	check(added != null and added.title == "Enemigo de prueba" and fact(added, "Vida") == "999", "AC-016-10: un .tres nuevo aparece en la wiki sin tocar otros archivos")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NEW_ENEMY))

	# AC-016-8: la pantalla.
	var screen := WikiScreen.new()
	root.add_child(screen)
	await frames(2)
	check(screen.categories.size() == 6 and screen._tabs.get_child_count() == 6, "AC-016-8: la pantalla tiene una pestaña por categoría")
	check(screen._list.get_child_count() == screen.categories[0].entries.size() and screen.current_entry != null, "AC-016-8: lista las entradas y muestra la primera")
	for i in screen.categories.size():
		screen.show_category(i)
		await frames(1)
	check(screen.current_category == 5 and screen._detail.get_child_count() > 1, "AC-016-8: cada categoría se puede abrir y dibuja su detalle")
	screen.show_category(1)
	await frames(1)
	var detail_has_icon := false
	for node in screen._detail.find_children("*", "TextureRect", true, false):
		detail_has_icon = detail_has_icon or (node as TextureRect).texture != null
	check(screen.current_entry.locked and detail_has_icon, "AC-016-8: una entrada cerrada se dibuja en silueta")
	var closed_flag := [false]
	screen.closed.connect(func() -> void: closed_flag[0] = true)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	screen._input(esc)
	await frames(2)
	check(closed_flag[0] and not is_instance_valid(screen), "AC-016-8: Esc cierra la pantalla")
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	menu._on_wiki()
	check(menu._wiki != null, "AC-016-8: el menú principal abre la wiki")
	menu.queue_free()
	var pause := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	root.add_child(pause)
	pause._on_wiki()
	check(pause._wiki != null, "AC-016-8: la pausa abre la wiki")
	pause.queue_free()
	await frames(1)

	# Limpieza.
	WikiProgress.erase_file()
	WikiProgress.path = "user://wiki_progress.json"
	WikiProgress.forget()
	TestMode.force = -1
	print("Wiki: %d controles / %d fallos" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
