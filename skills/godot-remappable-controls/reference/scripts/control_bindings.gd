class_name ControlBindings
extends RefCounted
## Teclas y botones de mando remapeables (spec 015). La fuente de verdad es el InputMap; esta clase lo
## modifica, recuerda los valores de fábrica para restaurarlos y guarda solo lo que cambió.
##
## Cada acción tiene `KEY_SLOTS` teclas (por posición física, independiente de la distribución del teclado) y
## `JOY_SLOTS` botones de mando. Los ejes del stick no se remapean y se conservan tal cual.

const VERSION := 1
const KEY_SLOTS := 2
const JOY_SLOTS := 1

const GAME_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"jump", &"attack", &"block", &"fall_soft", &"fall_hard",
	&"craft", &"patron_ability", &"interact", &"pause",
]
const LABELS := {
	&"move_left": "Mover a la izquierda",
	&"move_right": "Mover a la derecha",
	&"jump": "Saltar",
	&"attack": "Espada",
	&"block": "Guardia (mantener)",
	&"fall_soft": "Pluma (en el aire)",
	&"fall_hard": "Yunque (en el aire)",
	&"craft": "Pulir",
	&"patron_ability": "Habilidad del patrono",
	&"interact": "Interactuar",
	&"pause": "Pausa",
}
const JOY_NAMES := {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "Atrás", 5: "Guía", 6: "Inicio", 7: "Stick izq.", 8: "Stick der.",
	9: "LB", 10: "RB", 11: "D-pad ↑", 12: "D-pad ↓", 13: "D-pad ←", 14: "D-pad →",
}
const MODIFIER_KEYS: Array[int] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

## Archivo de preferencias; el modo de pruebas usa otro (TestMode.activate).
static var path: String = "user://input_bindings.json"
## Acciones extra con su etiqueta (las agrega el modo de pruebas con `register_extra`).
static var _extra: Array[StringName] = []
static var _extra_labels: Dictionary = {}
static var _defaults: Dictionary = {}
static var _loaded: bool = false


## Acciones que se muestran y se pueden remapear, en orden.
static func actions() -> Array[StringName]:
	var all: Array[StringName] = GAME_ACTIONS.duplicate()
	all.append_array(_extra)
	return all


static func label(action: StringName) -> String:
	if LABELS.has(action):
		return String(LABELS[action])
	return String(_extra_labels.get(action, String(action)))


## ¿Es una acción que puede quedar sin ningún control? Las del juego, no.
static func is_optional(action: StringName) -> bool:
	return _extra.has(action)


## Suma una acción (con teclas por defecto) al InputMap y a la pantalla de controles. Repetir es inofensivo.
static func register_extra(action: StringName, text: String, default_keys: Array[int]) -> void:
	if _extra.has(action):
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for code in default_keys:
			InputMap.action_add_event(action, _key_event(code))
	_extra.append(action)
	_extra_labels[action] = text
	_capture_default(action)
	if _loaded:
		_apply_saved_for(action)


## Quita todas las acciones extra (para pruebas que activan y desactivan el modo de pruebas).
static func clear_extra() -> void:
	for action in _extra:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		_defaults.erase(action)
	_extra.clear()
	_extra_labels.clear()


## Carga las preferencias guardadas la primera vez (y recuerda los valores de fábrica antes de tocarlos).
static func ensure_loaded() -> void:
	if _loaded:
		return
	capture_defaults()
	_loaded = true
	_apply_saved(_read_saved())


static func is_loaded() -> bool:
	return _loaded


## Fuerza otra lectura (si cambió `path`, por ejemplo).
static func reload_saved() -> void:
	capture_defaults()
	_loaded = true
	for action in actions():
		_restore_default(action)
	_apply_saved(_read_saved())


static func capture_defaults() -> void:
	for action in actions():
		_capture_default(action)


static func _capture_default(action: StringName) -> void:
	if _defaults.has(action) or not InputMap.has_action(action):
		return
	_defaults[action] = {"keys": keys_of(action), "joy": joy_of(action)}


# --- lectura ------------------------------------------------------------------

## Teclas (posición física) de la acción en sus casillas; 0 = casilla vacía.
static func keys_of(action: StringName) -> Array[int]:
	var out: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = (event as InputEventKey).physical_keycode
			if code == 0:
				code = (event as InputEventKey).keycode
			out.append(code)
	while out.size() < KEY_SLOTS:
		out.append(0)
	return _first(out, KEY_SLOTS)


## Botones de mando de la acción en sus casillas; -1 = casilla vacía.
static func joy_of(action: StringName) -> Array[int]:
	var out: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			out.append((event as InputEventJoypadButton).button_index)
	while out.size() < JOY_SLOTS:
		out.append(-1)
	return _first(out, JOY_SLOTS)


static func _first(values: Array[int], count: int) -> Array[int]:
	var out: Array[int] = []
	out.assign(values.slice(0, count))
	return out


static func default_keys(action: StringName) -> Array[int]:
	var d: Dictionary = _defaults.get(action, {})
	var keys: Array[int] = []
	keys.assign(d.get("keys", [0, 0]))
	return keys


static func default_joy(action: StringName) -> Array[int]:
	var d: Dictionary = _defaults.get(action, {})
	var joy: Array[int] = []
	joy.assign(d.get("joy", [-1]))
	return joy


static func is_default(action: StringName) -> bool:
	return keys_of(action) == default_keys(action) and joy_of(action) == default_joy(action)


static func key_text(code: int) -> String:
	if code == 0:
		return "—"
	var keycode: int = 0
	if DisplayServer.get_name() != "headless":
		keycode = DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	var text := OS.get_keycode_string(keycode if keycode != 0 else code)
	return text if text != "" else "Tecla %d" % code


## Marca de que la acción también usa un eje del stick o un gatillo (no remapeable); vacío si no.
static func axis_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			return "eje"
	return ""


static func joy_text(button: int) -> String:
	if button < 0:
		return "—"
	return String(JOY_NAMES.get(button, "Botón %d" % button))


# --- cambios ------------------------------------------------------------------

## Pone la tecla `code` en la casilla `slot` de la acción. Si otra acción ya la usa, intercambian: esa
## recibe la tecla que ésta tenía. Devuelve {"ok": bool, "swapped": acción intercambiada o &"", "reason": texto}.
static func set_key(action: StringName, slot: int, code: int) -> Dictionary:
	if slot < 0 or slot >= KEY_SLOTS or code == 0 or MODIFIER_KEYS.has(code):
		return {"ok": false, "swapped": &"", "reason": "tecla no válida"}
	var mine := keys_of(action)
	var old := mine[slot]
	if old == code:
		return {"ok": true, "swapped": &"", "reason": ""}
	var swapped: StringName = &""
	for other in actions():
		if other == action:
			continue
		var theirs := keys_of(other)
		var at := theirs.find(code)
		if at < 0:
			continue
		theirs[at] = old
		if not is_optional(other) and not _has_any(theirs, joy_of(other)):
			return {"ok": false, "swapped": &"", "reason": "%s se quedaría sin control" % label(other)}
		_apply(other, theirs, joy_of(other))
		swapped = other
	# Repetida en la otra casilla de la misma acción: se intercambian de lugar.
	var same := mine.find(code)
	if same >= 0:
		mine[same] = old
	mine[slot] = code
	_apply(action, mine, joy_of(action))
	return {"ok": true, "swapped": swapped, "reason": ""}


static func set_joy(action: StringName, slot: int, button: int) -> Dictionary:
	if slot < 0 or slot >= JOY_SLOTS or button < 0:
		return {"ok": false, "swapped": &"", "reason": "botón no válido"}
	var mine := joy_of(action)
	var old := mine[slot]
	if old == button:
		return {"ok": true, "swapped": &"", "reason": ""}
	var swapped: StringName = &""
	for other in actions():
		if other == action:
			continue
		var theirs := joy_of(other)
		var at := theirs.find(button)
		if at < 0:
			continue
		theirs[at] = old
		if not is_optional(other) and not _has_any(keys_of(other), theirs):
			return {"ok": false, "swapped": &"", "reason": "%s se quedaría sin control" % label(other)}
		_apply(other, keys_of(other), theirs)
		swapped = other
	mine[slot] = button
	_apply(action, keys_of(action), mine)
	return {"ok": true, "swapped": swapped, "reason": ""}


## Vacía una casilla de tecla. No deja sin control a una acción del juego.
static func clear_key(action: StringName, slot: int) -> bool:
	var mine := keys_of(action)
	if slot < 0 or slot >= KEY_SLOTS:
		return false
	mine[slot] = 0
	if not is_optional(action) and not _has_any(mine, joy_of(action)):
		return false
	_apply(action, mine, joy_of(action))
	return true


static func clear_joy(action: StringName, slot: int) -> bool:
	var mine := joy_of(action)
	if slot < 0 or slot >= JOY_SLOTS:
		return false
	mine[slot] = -1
	if not is_optional(action) and not _has_any(keys_of(action), mine):
		return false
	_apply(action, keys_of(action), mine)
	return true


static func reset(action: StringName) -> void:
	_restore_default(action)


static func reset_all() -> void:
	for action in actions():
		_restore_default(action)


static func _restore_default(action: StringName) -> void:
	if _defaults.has(action):
		_apply(action, default_keys(action), default_joy(action))


static func _has_any(keys: Array[int], joy: Array[int]) -> bool:
	for k in keys:
		if k != 0:
			return true
	for b in joy:
		if b >= 0:
			return true
	return false


static func _key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	return event


## Reemplaza las teclas y los botones de la acción, conservando los ejes del stick.
static func _apply(action: StringName, keys: Array[int], joy: Array[int]) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	for code in keys:
		if code != 0:
			InputMap.action_add_event(action, _key_event(code))
	for button in joy:
		if button >= 0:
			var event := InputEventJoypadButton.new()
			event.button_index = button as JoyButton
			InputMap.action_add_event(action, event)


# --- guardado -----------------------------------------------------------------

## Escribe en `path` solo las acciones que difieren de fábrica.
static func save() -> void:
	var changed := {}
	for action in actions():
		if not is_default(action):
			changed[String(action)] = {"keys": keys_of(action), "joy": joy_of(action)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudieron guardar los controles en %s" % path)
		return
	file.store_string(JSON.stringify({"version": VERSION, "bindings": changed}))


static func _read_saved() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != VERSION:
		return {}
	var bindings: Variant = parsed.get("bindings", {})
	return bindings if typeof(bindings) == TYPE_DICTIONARY else {}


static func _apply_saved(bindings: Dictionary) -> void:
	for action in actions():
		_apply_saved_entry(action, bindings)


static func _apply_saved_for(action: StringName) -> void:
	_apply_saved_entry(action, _read_saved())


## Aplica una entrada guardada si es válida: ignora acciones desconocidas y valores que no son enteros.
static func _apply_saved_entry(action: StringName, bindings: Dictionary) -> void:
	var entry: Variant = bindings.get(String(action), null)
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var keys: Array[int] = []
	var joy: Array[int] = []
	for value: Variant in entry.get("keys", []):
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			keys.append(int(value))
	for value: Variant in entry.get("joy", []):
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			joy.append(int(value))
	while keys.size() < KEY_SLOTS:
		keys.append(0)
	while joy.size() < JOY_SLOTS:
		joy.append(-1)
	keys = _first(keys, KEY_SLOTS)
	joy = _first(joy, JOY_SLOTS)
	if not is_optional(action) and not _has_any(keys, joy):
		return
	_apply(action, keys, joy)
