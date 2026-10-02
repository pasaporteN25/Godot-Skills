extends SceneTree
## Capturas para revisar los idiomas (spec 017): menú, pausa, controles, wiki, Umbral y una etapa con jefe, con el render real.
## Requiere ventana (NO usar --headless). El idioma sale de `--lang=xx`; con `--pseudo` se usa la seudolocalización de Godot.
##   Godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 -s tools/capture_i18n.gd -- --lang=en
## Guarda PNG en %TEMP%\fw_i18n\<idioma>\.

const RUNNER := "res://scenes/stage/stage_runner.tscn"
const PLAYER := "res://scenes/player/player.tscn"

var _dir: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("captura: ", name)


## Pone una pantalla de pantalla completa sobre la raíz, la captura y la quita.
func _shot_screen(name: String, screen: Control, parent: Node = root) -> void:
	parent.add_child(screen)
	await _frames(3)
	await _save(name)
	screen.queue_free()
	await _frames(2)


func _run() -> void:
	SaveGame.enabled = false
	AudioSettings.enabled = false
	Loc.enabled = false
	var pseudo := OS.get_cmdline_user_args().has("--pseudo")
	if pseudo:
		Loc.set_pseudo(true)
	var language := Loc.current() + ("_pseudo" if pseudo else "")
	_dir = OS.get_environment("TEMP") + "/fw_i18n/" + language
	DirAccess.make_dir_recursive_absolute(_dir)

	await _shot_screen("01_menu", (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as Control)
	var pause := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	root.add_child(pause)
	await _frames(2)
	pause._panel.visible = true
	await _save("02_pause")
	pause._on_controls()
	await _frames(3)
	await _save("03_controls")
	pause.queue_free()
	await _frames(2)

	# La wiki con todo abierto: una entrada de cada categoría.
	TestMode.force = 1
	var wiki := WikiScreen.new()
	root.add_child(wiki)
	await _frames(3)
	var categories := wiki.categories
	for i in categories.size():
		wiki.show_category(i)
		await _frames(2)
		var entries: Array = categories[i].entries
		for pick in [0, entries.size() - 1]:
			wiki.show_entry(entries[pick])
			await _frames(2)
			await _save("04_wiki_%s_%d" % [categories[i].id, pick])
	wiki.queue_free()
	await _frames(2)
	TestMode.force = 0

	# Una etapa con jefe (cartel de la etapa, diálogo de entrada) y el Umbral.
	var runner := (load(RUNNER) as PackedScene).instantiate() as StageRunner
	runner.player_scene = load(PLAYER)
	runner.stage = load("res://resources/stages/arc1_boss.tres")
	root.add_child(runner)
	await _frames(3)
	runner._enter_room(&"arena", &"start")
	await _frames(3)
	runner.player.global_position = Vector2(900, 416)
	await _frames(60)
	await _save("05_boss_stage")
	runner.queue_free()
	await _frames(2)
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(90)
	await _save("06_game_start")
	# El Umbral: el aviso de cada zona y una frase de Hades.
	game.go_umbral()
	await _frames(30)
	var hub: UmbralHub = game.hub
	hub.player.global_position = Vector2(UmbralHub.FORGE_X, UmbralHub.GROUND_Y)
	await _frames(20)
	await _save("07_umbral_forge")
	hub.player.global_position = Vector2(UmbralHub.HADES_X, UmbralHub.GROUND_Y)
	await _frames(20)
	hub._on_talk()
	await _frames(20)
	await _save("08_umbral_hades")
	hub.player.global_position = Vector2(UmbralHub.SHRINE_X, UmbralHub.GROUND_Y)
	await _frames(20)
	await _save("09_umbral_shrine")
	game.queue_free()
	quit()
