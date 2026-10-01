class_name ControlsScreen
extends Control
## Pantalla de controles (spec 015): muestra las acciones con sus dos teclas y su botón de mando, y deja
## cambiarlos. Se abre desde el menú principal y desde la pausa; guarda al instante vía ControlBindings.

signal closed

var _rows: VBoxContainer
var _message: Label
var _capture: Dictionary = {}
var _buttons: Dictionary = {}
var _closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ControlBindings.ensure_loaded()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.1, 1.0)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)

	var title := Label.new()
	title.text = "Controles"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Clic en una casilla y apretá la tecla o botón nuevo · Esc cancela · Supr/Retroceso la vacía"
	hint.add_theme_font_size_override("font_size", 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	scroll.add_child(_rows)

	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 9)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.custom_minimum_size.y = 14.0
	column.add_child(_message)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)
	_button(bottom, "Restaurar todo", _on_reset_all, 120.0)
	_button(bottom, "Volver", close, 120.0)
	_rebuild()


func _button(parent: Control, text: String, callback: Callable, width: float = 0.0) -> Button:
	var b := Button.new()
	MenuSkin.apply_button(b)
	b.text = text
	b.add_theme_font_size_override("font_size", 9)
	b.custom_minimum_size = Vector2(width, 20.0)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


## Vuelve a dibujar todas las filas con los controles actuales.
func _rebuild() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_buttons.clear()
	for action in ControlBindings.actions():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_rows.add_child(row)
		var name_label := Label.new()
		name_label.text = ControlBindings.label(action)
		name_label.custom_minimum_size.x = 190.0
		name_label.add_theme_font_size_override("font_size", 10)
		row.add_child(name_label)
		var keys := ControlBindings.keys_of(action)
		for slot in ControlBindings.KEY_SLOTS:
			var kb := _slot_button(row, ControlBindings.key_text(keys[slot]), 100.0)
			kb.pressed.connect(_begin_capture.bind(action, &"key", slot))
			_buttons[[action, &"key", slot]] = kb
		var joy := ControlBindings.joy_of(action)
		for slot in ControlBindings.JOY_SLOTS:
			var joy_label := ControlBindings.joy_text(joy[slot])
			var axis := ControlBindings.axis_text(action)
			if axis != "":
				joy_label = axis if joy[slot] < 0 else "%s + %s" % [joy_label, axis]
			var jb := _slot_button(row, "Mando: " + joy_label, 110.0)
			jb.pressed.connect(_begin_capture.bind(action, &"joy", slot))
			_buttons[[action, &"joy", slot]] = jb
		var reset := _slot_button(row, "↺", 24.0)
		reset.disabled = ControlBindings.is_default(action)
		reset.pressed.connect(_on_reset.bind(action))


func _slot_button(parent: Control, text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 18.0)
	b.add_theme_font_size_override("font_size", 9)
	b.clip_text = true
	parent.add_child(b)
	return b


func is_capturing() -> bool:
	return not _capture.is_empty()


func _begin_capture(action: StringName, kind: StringName, slot: int) -> void:
	_capture = {"action": action, "kind": kind, "slot": slot}
	var button: Button = _buttons.get([action, kind, slot])
	if button != null:
		button.text = "Apretá una tecla…" if kind == &"key" else "Apretá un botón…"
	_message.text = "%s: esperando…" % ControlBindings.label(action)


func _cancel_capture() -> void:
	_capture = {}
	_message.text = ""
	_rebuild()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _capture.is_empty():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			# Diferido: la pausa consulta Esc por sondeo y no debe verlo ya cerrado en este mismo cuadro.
			close.call_deferred()
		return
	var kind: StringName = _capture["kind"]
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if kind != &"key":
			return
		match event.keycode:
			KEY_ESCAPE:
				_cancel_capture()
			KEY_BACKSPACE, KEY_DELETE:
				_finish(ControlBindings.clear_key(_capture["action"], _capture["slot"]), {}, "Casilla vaciada")
			_:
				var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				if ControlBindings.MODIFIER_KEYS.has(code):
					return
				_finish_set(ControlBindings.set_key(_capture["action"], _capture["slot"], code))
	elif event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		if kind != &"joy":
			return
		_finish_set(ControlBindings.set_joy(_capture["action"], _capture["slot"], event.button_index))


func _finish_set(result: Dictionary) -> void:
	var text := ""
	if result["ok"]:
		var swapped: StringName = result["swapped"]
		text = "Guardado" if swapped == &"" else "Guardado; intercambió con «%s»" % ControlBindings.label(swapped)
	_finish(result["ok"], result, text)


func _finish(ok: bool, result: Dictionary, text: String) -> void:
	_capture = {}
	if ok:
		ControlBindings.save()
		_message.text = text
	else:
		_message.text = "No se pudo: %s" % String(result.get("reason", "la acción quedaría sin control"))
	_rebuild()


func _on_reset(action: StringName) -> void:
	ControlBindings.reset(action)
	ControlBindings.save()
	_message.text = "«%s» restaurada" % ControlBindings.label(action)
	_rebuild()


func _on_reset_all() -> void:
	ControlBindings.reset_all()
	ControlBindings.save()
	_message.text = "Controles restaurados"
	_rebuild()


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()
