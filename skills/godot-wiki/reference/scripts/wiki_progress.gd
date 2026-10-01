class_name WikiProgress
extends RefCounted
## Qué descubrió el jugador (spec 016): enemigos vistos, jefes enfrentados, patronos equipados, espadas
## empuñadas y lugares visitados. Se guarda aparte de la partida: sobrevive a «Nueva partida». En el modo de
## pruebas todo está abierto.

const VERSION := 1
const ENEMY: StringName = &"enemy"
const BOSS: StringName = &"boss"
const PATRON: StringName = &"patron"
const SWORD: StringName = &"sword"
const PLACE: StringName = &"place"

static var path: String = "user://wiki_progress.json"
static var _seen: Dictionary = {}
static var _loaded: bool = false


## Anota que el jugador descubrió `id` de la clase `kind`. Guarda solo si es la primera vez y el guardado
## está habilitado (las pruebas automáticas lo apagan).
static func mark(kind: StringName, id: StringName) -> void:
	_ensure_loaded()
	var ids: Dictionary = _seen.get(kind, {})
	if ids.has(id):
		return
	ids[id] = true
	_seen[kind] = ids
	if SaveGame.enabled:
		_save()


static func is_seen(kind: StringName, id: StringName) -> bool:
	if TestMode.enabled():
		return true
	_ensure_loaded()
	return (_seen.get(kind, {}) as Dictionary).has(id)


## Cuántos ids de esa clase hay descubiertos.
static func count(kind: StringName) -> int:
	_ensure_loaded()
	return (_seen.get(kind, {}) as Dictionary).size()


## Olvida lo descubierto en memoria (y vuelve a leer el archivo la próxima vez). Lo usan las pruebas y el
## modo de pruebas al cambiar de archivo.
static func forget() -> void:
	_seen = {}
	_loaded = false


## Borra también el archivo.
static func erase_file() -> void:
	forget()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_seen = {}
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = json.data
	if int(data.get("version", 0)) != VERSION or typeof(data.get("seen")) != TYPE_DICTIONARY:
		return
	for kind: String in data["seen"]:
		var ids := {}
		var listed: Variant = data["seen"][kind]
		if typeof(listed) == TYPE_ARRAY:
			for id: Variant in listed:
				ids[StringName(str(id))] = true
		_seen[StringName(kind)] = ids


static func _save() -> void:
	var out := {}
	for kind: StringName in _seen:
		var ids: Array = []
		for id: StringName in _seen[kind]:
			ids.append(String(id))
		ids.sort()
		out[String(kind)] = ids
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar el progreso de la wiki en %s" % path)
		return
	file.store_string(JSON.stringify({"version": VERSION, "seen": out}))
