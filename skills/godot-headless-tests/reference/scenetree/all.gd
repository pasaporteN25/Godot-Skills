extends SceneTree
## Corre TODOS los tests headless de esta carpeta: primero `run.gd` y después el resto en orden alfabético.
## Cada uno va en su propio proceso de Godot (no comparten estáticos ni autoloads, igual que al correrlos a
## mano). Un test falla si sale con código distinto de 0 o si su salida tiene un error de script: un script
## que no compila puede terminar con código 0 sin haber probado nada, y uno que se rompe en plena corrida no
## llega a su `quit()` y quedaría colgado para siempre (por eso se lo corta).
## Uso: Godot_console.exe --headless --path . -s tests/headless/all.gd
##      solo algunos:      ... -s tests/headless/all.gd -- solo=wiki,controls
##      otro límite (seg): ... -s tests/headless/all.gd -- limite=1200

const DIR := "res://tests/headless/"
const FIRST := "run.gd"
const SELF := "all.gd"
const BAD_LINES: Array[String] = ["SCRIPT ERROR", "Parse Error", "Failed to load script"]
## Segundos máximos por test (run.gd tarda unos 200).
const DEFAULT_LIMIT := 900
## Tras un error de script, segundos de gracia para juntar la salida antes de cortar el proceso.
const GRACE_AFTER_ERROR := 3.0
## Registros de cada test mientras corre (se borran al terminar).
const LOG_DIR := "user://test_all_logs/"


func _initialize() -> void:
	var names := _test_names(_arg("solo").split(",", false))
	var limit := float(_arg("limite")) if _arg("limite").is_valid_int() else float(DEFAULT_LIMIT)
	var failed: Array[String] = []
	var total_start := Time.get_ticks_msec()
	for test_name in names:
		var start := Time.get_ticks_msec()
		var result := _run_test(DIR + test_name, limit)
		var text: String = result["output"]
		var bad := _bad_lines(text)
		var ok: bool = result["code"] == 0 and bad.is_empty() and result["cut"] == ""
		var seconds := (Time.get_ticks_msec() - start) / 1000.0
		var summary: String = result["cut"] if result["cut"] != "" else _summary(text)
		print("%s %s (%.0f s) :: %s" % ["OK   " if ok else "FALLÓ", test_name, seconds, summary])
		if not ok:
			failed.append(test_name)
			print("----- salida de %s (código %d) -----" % [test_name, result["code"]])
			print(text)
			for line in bad:
				print("  >> %s" % line)
			print("----- fin de %s -----" % test_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_DIR))
	var minutes := (Time.get_ticks_msec() - total_start) / 60000.0
	if failed.is_empty():
		print("\nTODOS OK: %d tests (%.1f min)" % [names.size(), minutes])
	else:
		print("\nFALLARON %d de %d: %s (%.1f min)" % [failed.size(), names.size(), ", ".join(failed), minutes])
	quit(0 if failed.is_empty() and not names.is_empty() else 1)


## Corre un test en otro proceso; su salida va a un archivo de registro (`--log-file`; los errores se escriben al
## instante). Lo corta si se pasa del límite o si, tras un error de script, no termina solo (un error en tiempo
## de ejecución deja al test sin llegar a `quit()`). Devuelve {code, output, cut}: `cut` explica el corte.
## No se usan pipes: si el test escribe mucho, el pipe se llena y el test se traba.
func _run_test(path: String, limit: float) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	var log_path := ProjectSettings.globalize_path(LOG_DIR + path.get_file().get_basename() + ".log")
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	var args := PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", log_path, "-s", path,
	])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		return {"code": -1, "output": "", "cut": "no se pudo lanzar Godot"}
	var start := Time.get_ticks_msec()
	var error_at := -1.0
	var cut := ""
	while OS.is_process_running(pid):
		OS.delay_msec(100)
		var elapsed := (Time.get_ticks_msec() - start) / 1000.0
		if error_at < 0.0 and not _bad_lines(_read_log(log_path)).is_empty():
			error_at = elapsed
		if error_at >= 0.0 and elapsed - error_at > GRACE_AFTER_ERROR:
			cut = "cortado: error de script y el test no terminó"
		elif elapsed > limit:
			cut = "cortado: pasó el límite de %d s" % int(limit)
		if cut != "":
			OS.kill(pid)
			# Esperar a que muera: mientras tanto el registro sigue abierto y no se puede borrar.
			var waited := 0
			while OS.is_process_running(pid) and waited < 5000:
				OS.delay_msec(50)
				waited += 50
			break
	var code := OS.get_process_exit_code(pid) if cut == "" else -1
	var output := _read_log(log_path)
	DirAccess.remove_absolute(log_path)
	return {"code": code, "output": output, "cut": cut}


func _read_log(log_path: String) -> String:
	var file := FileAccess.open(log_path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


## Los .gd de la carpeta (sin este), con `run.gd` primero. Con `solo=`, solo los que contengan alguno de esos
## nombres.
func _test_names(only: PackedStringArray) -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(DIR):
		if file.get_extension() != "gd" or file == SELF:
			continue
		if not only.is_empty() and not _matches(file, only):
			continue
		names.append(file)
	names.sort()
	if names.has(FIRST):
		names.erase(FIRST)
		names.push_front(FIRST)
	if names.is_empty():
		print("No hay tests que correr en %s (filtro: %s)" % [DIR, ", ".join(only)])
	return names


func _matches(file: String, only: PackedStringArray) -> bool:
	for part in only:
		if file.get_basename().contains(part):
			return true
	return false


## Valor de un argumento `nombre=valor` después de `--` (vacío si no está).
func _arg(arg_name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(arg_name + "="):
			return arg.trim_prefix(arg_name + "=")
	return ""


func _bad_lines(text: String) -> Array[String]:
	var found: Array[String] = []
	for line in text.split("\n"):
		for bad in BAD_LINES:
			if line.contains(bad):
				found.append(line.strip_edges())
				break
	return found


## La última línea con texto que no sea un aviso del motor al salir (fugas, «at: …»): es el resumen del test.
func _summary(text: String) -> String:
	var lines := text.split("\n")
	for i in range(lines.size() - 1, -1, -1):
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("at:") or line.begins_with("ERROR:") or line.begins_with("WARNING:"):
			continue
		return line
	return "(sin salida)"
