class_name Loc
extends RefCounted
## Idioma del juego (spec 017). El texto fuente es el español: cada texto del juego es su propia clave y
## `translations/<código>.po` lo traduce (`tr("…")`). Sumar un idioma = un `.po` más, una línea en `LANGUAGES` y una
## línea en `[internationalization]` de project.godot.
##
## Qué idioma arranca: `--lang=xx` > preferencia guardada > idioma del sistema si hay traducción > español.
## Cuando Godot corre un script suelto (`-s`: tests y herramientas) arranca SIEMPRE en español, salvo `--lang`, para
## que la suite no dependa del idioma de la computadora (ni de la preferencia del jugador).

const SOURCE := "es"
## Nombre de cada idioma escrito en ese idioma (no se traduce).
const LANGUAGES := {"es": "Español", "en": "English"}
const ARG := "--lang="
const VERSION := 1

static var path: String = "user://language.json"
static var enabled: bool = true
static var _loaded: bool = false
static var _current: String = SOURCE


## Aplica el idioma de arranque la primera vez. Lo llama el autoload `Localization`.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var code := _arg_language()
	if code == "":
		code = SOURCE if is_script_run() else _saved_or_system()
	_apply(code if LANGUAGES.has(code) else SOURCE)


## Códigos disponibles, en orden.
static func codes() -> Array[String]:
	var result: Array[String] = []
	for code: String in LANGUAGES:
		result.append(code)
	return result


static func current() -> String:
	ensure_loaded()
	return _current


## El nombre del idioma actual, en ese idioma.
static func current_name() -> String:
	return String(LANGUAGES[current()])


## Cambia el idioma al instante y lo guarda (si el guardado está habilitado). Devuelve false si no existe.
static func set_language(code: String) -> bool:
	ensure_loaded()
	if not LANGUAGES.has(code):
		return false
	_apply(code)
	_save()
	return true


## El idioma que sigue en la lista (para un botón que alterna).
static func next_code() -> String:
	var all := codes()
	return all[(all.find(current()) + 1) % all.size()]


## Seudolocalización de Godot: cada texto sale con acentos raros y entre corchetes. Lo que se ve normal quedó
## escrito a mano sin pasar por `tr`; lo que se corta no entra en la pantalla. Solo para revisar.
static func set_pseudo(on: bool) -> void:
	TranslationServer.pseudolocalization_enabled = on


## Traduce un texto. Es lo que hace `tr()` de un Node, para donde no hay instancia (funciones estáticas,
## RefCounted). `tools/build_translations.gd` reconoce las dos formas.
static func t(text: String) -> String:
	return TranslationServer.translate(text)


## ¿Godot corre un script suelto (`-s`) en vez del juego?
static func is_script_run() -> bool:
	var args := OS.get_cmdline_args()
	return args.has("-s") or args.has("--script")


## Para las pruebas: vuelve a decidir el idioma de arranque la próxima vez.
static func reset() -> void:
	_loaded = false
	_current = SOURCE


static func _apply(code: String) -> void:
	_current = code
	TranslationServer.set_locale(code)


static func _arg_language() -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(ARG):
			return arg.trim_prefix(ARG)
	return ""


static func _saved_or_system() -> String:
	var saved := _read_saved()
	if saved != "":
		return saved
	var system := OS.get_locale_language()
	return system if LANGUAGES.has(system) else SOURCE


## El código guardado, o "" si no hay archivo, está dañado o nombra un idioma que no existe.
static func _read_saved() -> String:
	if not enabled or not FileAccess.file_exists(path):
		return ""
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return ""
	var data: Dictionary = json.data
	var code := str(data.get("language", ""))
	return code if int(data.get("version", 0)) == VERSION and LANGUAGES.has(code) else ""


static func _save() -> void:
	if not enabled:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar el idioma en %s" % path)
		return
	file.store_string(JSON.stringify({"version": VERSION, "language": _current}))
