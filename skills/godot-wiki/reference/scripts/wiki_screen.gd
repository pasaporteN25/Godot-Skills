class_name WikiScreen
extends Control
## Pantalla de la wiki (spec 016): pestañas de categoría arriba, lista de entradas a la izquierda y el detalle
## a la derecha. Es genérica: dibuja lo que `Wiki` le da (categorías → entradas → bloques) y no sabe qué es un
## enemigo. Se abre desde el menú principal y desde la pausa; `Esc` o «Volver» la cierra.

signal closed

const LIST_WIDTH := 178.0
const DETAIL_WIDTH := 410.0
const ICON_MAX := 96.0
const FONT := 10
const HEADING_COLOR := Color(0.91, 0.77, 0.42)
const LOCKED_COLOR := Color(0.55, 0.57, 0.65)

var categories: Array[WikiCategory] = []
var current_category: int = -1
var current_entry: WikiEntry

var _tabs: HBoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := ColorRect.new()
	background.color = Color(0.04, 0.05, 0.1, 1.0)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	column.add_child(top)
	var title := Label.new()
	title.text = "Wiki"
	title.add_theme_font_size_override("font_size", 16)
	title.custom_minimum_size.x = 48.0
	top.add_child(title)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tabs)
	_button(top, "Volver", close, 56.0)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size.x = LIST_WIDTH
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 1)
	list_scroll.add_child(_list)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size.x = DETAIL_WIDTH
	_detail.add_theme_constant_override("separation", 4)
	_detail_scroll.add_child(_detail)

	categories = Wiki.categories()
	for i in categories.size():
		var category := categories[i]
		var tab := _button(_tabs, "%s %d/%d" % [category.title, category.unlocked_count(), category.entries.size()], show_category.bind(i), 0.0)
		tab.toggle_mode = true
		tab.name = String(category.id)
	if not categories.is_empty():
		show_category(0)


func _button(parent: Control, text: String, callback: Callable, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 9)
	b.custom_minimum_size = Vector2(width, 20.0)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func show_category(index: int) -> void:
	if index < 0 or index >= categories.size():
		return
	current_category = index
	for i in _tabs.get_child_count():
		(_tabs.get_child(i) as Button).set_pressed_no_signal(i == index)
	for child in _list.get_children():
		child.queue_free()
	var category := categories[index]
	for entry in category.entries:
		var b := Button.new()
		b.text = entry.title
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.flat = true
		b.add_theme_font_size_override("font_size", FONT)
		b.custom_minimum_size = Vector2(0.0, 18.0)
		if entry.locked:
			b.add_theme_color_override("font_color", LOCKED_COLOR)
		b.pressed.connect(show_entry.bind(entry))
		_list.add_child(b)
	if not category.entries.is_empty():
		show_entry(category.entries[0])


func show_entry(entry: WikiEntry) -> void:
	current_entry = entry
	for child in _detail.get_children():
		child.queue_free()
	_detail_scroll.scroll_vertical = 0
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_detail.add_child(header)
	if entry.icon != null:
		header.add_child(_icon_rect(entry))
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(names)
	var title := Label.new()
	title.text = entry.title
	title.add_theme_font_size_override("font_size", 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 200.0
	names.add_child(title)
	if entry.subtitle != "":
		var subtitle := Label.new()
		subtitle.text = entry.subtitle
		subtitle.add_theme_font_size_override("font_size", FONT)
		subtitle.add_theme_color_override("font_color", LOCKED_COLOR)
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		names.add_child(subtitle)
	for block in entry.blocks:
		_add_block(block)


## Dibujo con la escala entera más grande que entre en `ICON_MAX`; en silueta si la entrada está cerrada.
func _icon_rect(entry: WikiEntry) -> Control:
	var size := entry.icon.get_size()
	var scale := clampf(floorf(ICON_MAX / maxf(maxf(size.x, size.y), 1.0)), 1.0, 4.0)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.15, 0.24)
	style.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", style)
	var rect := TextureRect.new()
	rect.texture = entry.icon
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = size * scale
	if entry.locked:
		rect.modulate = Color(0.0, 0.0, 0.0, 0.85)
	frame.add_child(rect)
	return frame


func _add_block(block: Dictionary) -> void:
	match String(block.get("tipo", "")):
		WikiEntry.KIND_HEADING:
			var label := _label(String(block["texto"]), 12)
			label.add_theme_color_override("font_color", HEADING_COLOR)
			_detail.add_child(label)
		WikiEntry.KIND_TEXT:
			_detail.add_child(_label(String(block["texto"]), FONT))
		WikiEntry.KIND_FACTS:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 12)
			grid.add_theme_constant_override("v_separation", 1)
			for row: Array in block.get("filas", []):
				var name_label := _label(String(row[0]), FONT)
				name_label.add_theme_color_override("font_color", LOCKED_COLOR)
				name_label.custom_minimum_size.x = 190.0
				grid.add_child(name_label)
				var value_label := _label(String(row[1]), FONT)
				value_label.custom_minimum_size.x = 190.0
				grid.add_child(value_label)
			_detail.add_child(grid)
		WikiEntry.KIND_TABLE:
			var rows: Array = block.get("filas", [])
			if rows.is_empty():
				return
			var table := GridContainer.new()
			table.columns = (rows[0] as Array).size()
			table.add_theme_constant_override("h_separation", 12)
			table.add_theme_constant_override("v_separation", 1)
			for r in rows.size():
				for cell: Variant in rows[r]:
					var label := _label(String(cell), FONT)
					label.custom_minimum_size.x = DETAIL_WIDTH / float(table.columns) - 12.0
					if r == 0:
						label.add_theme_color_override("font_color", HEADING_COLOR)
					table.add_child(label)
			_detail.add_child(table)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = DETAIL_WIDTH - 12.0
	return label


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		# Diferido: la pausa consulta Esc por sondeo y no debe verlo ya cerrado en este mismo cuadro.
		close.call_deferred()


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()
