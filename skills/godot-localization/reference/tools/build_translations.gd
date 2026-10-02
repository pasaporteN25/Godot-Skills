extends SceneTree
## Regenera `translations/es.pot` (plantilla) y sincroniza cada `translations/<idioma>.po`: agrega los textos nuevos con
## la traducción vacía y quita los que ya no existen (spec 017). Después hay que traducir lo vacío.
## Uso: Godot_console.exe --headless --path . -s tools/build_translations.gd
##      (con `-- --check` no escribe: falla si algo está desactualizado o sin traducir)

const LANGS_DIR := "res://translations/"


func _initialize() -> void:
	var check := OS.get_cmdline_user_args().has("--check")
	var entries := TranslationCatalog.extract()
	var problems := 0
	problems += _write(TranslationCatalog.POT_PATH, TranslationCatalog.write_po(entries, {}, ""), check)
	for code in Loc.codes():
		if code == Loc.SOURCE:
			continue
		var path := LANGS_DIR + code + ".po"
		var current := TranslationCatalog.read_po(path)
		problems += _write(path, TranslationCatalog.write_po(entries, current, code), check)
		var missing := 0
		for entry in entries:
			if String(current.get(entry["msgid"], "")) == "":
				missing += 1
		print("%s: %d textos, %d sin traducir" % [code, entries.size(), missing])
		if check:
			problems += missing
	print("Textos traducibles: %d" % entries.size())
	quit(1 if check and problems > 0 else 0)


func _write(path: String, text: String, check: bool) -> int:
	var old := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if old == text:
		return 0
	if check:
		print("Desactualizado: %s" % path)
		return 1
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	print("Escrito: %s" % path)
	return 0
