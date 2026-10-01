class_name JumpScreen
extends Control
## "Saltar a…" del modo de pruebas (spec 014): elegir arco, etapa y sala, y con qué equipo empezar.
## Deja el salto en `Launch.test_jump` y abre el juego; `Game` lo aplica con `TestActions.start_jump`.

const CAMPAIGN_PATH := "res://resources/campaigns/main_campaign.tres"
## Equipo sugerido por arco: nivel, plata, espada.
const KIT_BY_ARC: Array[Dictionary] = [
	{"level": 0, "silver": 0, "sword": &"heirloom_falcata"},
	{"level": 4, "silver": 200, "sword": &"sky_silver"},
	{"level": 8, "silver": 400, "sword": &"sky_silver"},
]

var campaign: CampaignDefinition
var arc_option: OptionButton
var stage_option: OptionButton
var room_option: OptionButton
var level_spin: SpinBox
var silver_spin: SpinBox
var hearts_spin: SpinBox
var sword_option: OptionButton
var patron_option: OptionButton
var _go_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	campaign = load(CAMPAIGN_PATH) as CampaignDefinition
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.1, 1.0)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(400.0, 0.0)
	column.add_theme_constant_override("separation", 3)
	center.add_child(column)
	var title := Label.new()
	title.text = "Saltar a… (modo de pruebas)"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	arc_option = _option_row(column, "Arco")
	stage_option = _option_row(column, "Etapa")
	room_option = _option_row(column, "Sala")
	level_spin = _spin_row(column, "Nivel de Platero", 0, 10)
	silver_spin = _spin_row(column, "Plata", 0, 9999)
	hearts_spin = _spin_row(column, "Corazones extra", 0, 8)
	sword_option = _option_row(column, "Espada")
	patron_option = _option_row(column, "Patrono")

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)
	_go_button = _button(bottom, "Ir", _on_go)
	_button(bottom, "Volver", close)

	for arc in campaign.arcs:
		arc_option.add_item(arc.display_name if arc.display_name != "" else String(arc.id))
	for sword_id: StringName in SwordCatalog.PATHS:
		sword_option.add_item(String(sword_id))
		sword_option.set_item_metadata(sword_option.item_count - 1, sword_id)
	arc_option.item_selected.connect(_on_arc_selected)
	stage_option.item_selected.connect(_on_stage_selected)
	_on_arc_selected(0)


func _option_row(parent: Control, text: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 120.0
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", 10)
	row.add_child(option)
	return option


func _spin_row(parent: Control, text: String, low: int, high: int) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 120.0
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = 1
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.get_line_edit().add_theme_font_size_override("font_size", 10)
	row.add_child(spin)
	return spin


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	MenuSkin.apply_button(b)
	b.text = text
	b.custom_minimum_size = Vector2(120.0, 24.0)
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func current_arc() -> ArcDefinition:
	return campaign.arcs[maxi(arc_option.selected, 0)]


## Al cambiar de arco: lista sus etapas (y el interludio, si tiene), sus patronos y el equipo sugerido.
func _on_arc_selected(_index: int) -> void:
	var arc := current_arc()
	stage_option.clear()
	for i in arc.stages.size():
		var stage := arc.stages[i]
		var kind := ""
		match stage.kind:
			StageDefinition.Kind.SUBBOSS: kind = " · subjefe"
			StageDefinition.Kind.BOSS: kind = " · jefe"
		stage_option.add_item("%s%s" % [stage.display_name, kind])
	if arc.interlude != null:
		stage_option.add_item("Interludio: %s" % arc.interlude.display_name)
	patron_option.clear()
	patron_option.add_item("Ninguno")
	patron_option.set_item_metadata(0, &"")
	for patron in arc.patrons:
		patron_option.add_item(patron.display_name if patron.display_name != "" else String(patron.id))
		patron_option.set_item_metadata(patron_option.item_count - 1, patron.id)
	var kit := KIT_BY_ARC[mini(arc_option.selected, KIT_BY_ARC.size() - 1)]
	level_spin.value = kit["level"]
	silver_spin.value = kit["silver"]
	for i in sword_option.item_count:
		if sword_option.get_item_metadata(i) == kit["sword"]:
			sword_option.select(i)
	stage_option.select(0)
	_on_stage_selected(0)


func _on_stage_selected(index: int) -> void:
	var arc := current_arc()
	room_option.clear()
	if index >= arc.stages.size():
		room_option.add_item("(escena del interludio)")
		room_option.disabled = true
		return
	room_option.disabled = false
	room_option.add_item("Inicio de la etapa")
	room_option.set_item_metadata(0, &"")
	for room in arc.stages[index].rooms:
		room_option.add_item("%s (%s)" % [room.display_name if room.display_name != "" else String(room.id), room.id])
		room_option.set_item_metadata(room_option.item_count - 1, room.id)


## Datos del salto elegido, tal como los recibe `TestActions.start_jump`.
func jump_data() -> Dictionary:
	var arc := current_arc()
	var stage_index := stage_option.selected
	var interlude := stage_index >= arc.stages.size()
	var room: StringName = &""
	if not interlude and room_option.selected >= 0:
		room = room_option.get_item_metadata(room_option.selected)
	return {
		"arc": arc_option.selected,
		"stage": -1 if interlude else stage_index,
		"room": room,
		"level": int(level_spin.value),
		"silver": int(silver_spin.value),
		"hearts": int(hearts_spin.value),
		"sword": sword_option.get_item_metadata(sword_option.selected) if sword_option.selected >= 0 else &"",
		"patron": patron_option.get_item_metadata(patron_option.selected) if patron_option.selected >= 0 else &"",
	}


func _on_go() -> void:
	Launch.test_jump = jump_data()
	Launch.load_save = false
	get_tree().change_scene_to_file(MainMenu.GAME_SCENE)


func close() -> void:
	queue_free()
