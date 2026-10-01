extends SceneTree
## Corre TODOS los tests headless de esta carpeta: primero `run.gd` y después el resto en orden alfabético.
## Cada uno va en su propio proceso de Godot (no comparten estáticos ni autoloads, igual que al correrlos a
## mano). Un test falla si sale con código distinto de 0 o si su salida tiene un error de script: un script
## que no compila puede terminar con código 0 sin haber probado nada.
## Uso: Godot_console.exe --headless --path . -s tests/headless/all.gd
##      (solo algunos: ... -s tests/headless/all.gd -- solo=wiki,controls)

const DIR := "res://tests/headless/"
const FIRST := "run.gd"
const SELF := "all.gd"
const BAD_LINES: Array[String] = ["SCRIPT ERROR", "Parse Error", "Failed to load script"]


func _initialize() -> void:
	var names := _test_names(_only_filter())
	var exe := OS.get_executable_path()
	var root := ProjectSettings.globalize_path("res://")
	var failed: Array[String] = []
	var total_start := Time.get_ticks_msec()
	for test_name in names:
		var start := Time.get_ticks_msec()
		var output: Array = []
		var code := OS.execute(exe, ["--headless", "--path", root, "-s", DIR + test_name], output, true)
		var text := "".join(output)
		var bad := _bad_lines(text)
		var ok := code == 0 and bad.is_empty()
		var seconds := (Time.get_ticks_msec() - start) / 1000.0
		print("%s %s (%.0f s) :: %s" % ["OK   " if ok else "FALLÓ", test_name, seconds, _summary(text)])
		if not ok:
			failed.append(test_name)
			print("----- salida de %s (código %d) -----" % [test_name, code])
			print(text)
			for line in bad:
				print("  >> %s" % line)
			print("----- fin de %s -----" % test_name)
	var minutes := (Time.get_ticks_msec() - total_start) / 60000.0
	if failed.is_empty():
		print("\nTODOS OK: %d tests (%.1f min)" % [names.size(), minutes])
	else:
		print("\nFALLARON %d de %d: %s (%.1f min)" % [failed.size(), names.size(), ", ".join(failed), minutes])
	quit(0 if failed.is_empty() and not names.is_empty() else 1)


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


func _only_filter() -> PackedStringArray:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("solo="):
			return arg.trim_prefix("solo=").split(",", false)
	return PackedStringArray()


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
