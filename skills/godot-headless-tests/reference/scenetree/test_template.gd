extends SceneTree
## Plantilla de un test headless sin framework (el formato de Former Walker). Copiar a tests/headless/<tema>.gd;
## all.gd lo encuentra solo. Uso suelto: Godot_console.exe --headless --path . -s tests/headless/<tema>.gd

const TMP := "user://test_<tema>.json"  # nunca el archivo real del jugador

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	# Apagar todo lo que escriba en user:// o haga ruido (adaptar a los autoloads del proyecto).
	# SaveGame.enabled = false
	_run.call_deferred()  # diferido: los autoloads ya están listos y se puede usar `await`


func check(ok: bool, label: String) -> void:
	checks += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)


func _run() -> void:
	# var old_path := Algo.path
	# Algo.path = TMP
	_test_ejemplo()
	# await _test_con_escena()
	_cleanup()
	# Algo.path = old_path
	print("\n<Tema>: %d controles / %d fallos" % [checks, failures.size()])  # última línea = resumen
	for f in failures:
		print("  FALLÓ: %s" % f)
	quit(0 if failures.is_empty() else 1)  # el código de salida es lo que mira all.gd y el CI


func _test_ejemplo() -> void:
	check(1 + 1 == 2, "la suma funciona")


## Una escena se instancia en `root` y se espera un cuadro para que corran sus _ready.
func _test_con_escena() -> void:
	# var scene := (load("res://scenes/x.tscn") as PackedScene).instantiate()
	# root.add_child(scene)
	# await process_frame
	# check(..., "...")
	# scene.queue_free()
	# await process_frame
	pass


func _cleanup() -> void:
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
