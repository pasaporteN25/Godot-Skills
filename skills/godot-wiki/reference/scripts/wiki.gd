class_name Wiki
extends RefCounted
## La wiki del juego (spec 016). Arma las categorías y sus entradas leyendo los DATOS: un enemigo nuevo en
## `resources/enemies/`, un jefe en `resources/bosses/`, un patrono en un arco o una espada en `SwordCatalog`
## aparecen solos. La pantalla (WikiScreen) no sabe qué es un enemigo: dibuja lo que esta clase le da.
##
## Para sumar una categoría: una función que devuelve sus entradas y una línea en `_providers()`.

const NOTES_PATH := "res://resources/wiki/notes.json"
const ARTICLES_DIR := "res://resources/wiki/articles/"
const ENEMIES_DIR := "res://resources/enemies/"
const BOSSES_DIR := "res://resources/bosses/"
const LOCKED_TITLE := "???"
const LOCKED_TEXT := "Todavía no te cruzaste con esto. Aparece acá cuando lo encuentres en una partida."
const GUIDE_ORDER_DEFAULT := 100

## Tipo de enemigo (por la escena que lo mueve): nombre y cómo enfrentarlo. Los datos que lo cambian
## (coraza, armadura, inmunidad) se agregan aparte desde la definición.
const ARCHETYPES := {
	"clock_moth": ["Volador", "Va y viene con un vaivén vertical. Pegale cuando pasa a tu altura o aplastalo desde arriba con el Yunque."],
	"marsh_crab": ["Caminante", "Patrulla, se esconde un rato (escondido ni se lo puede golpear ni daña) y vuelve a salir. Golpealo cuando emerge."],
	"scorch_beetle": ["Corredor", "Recorre el suelo, da la vuelta en los bordes y acelera si te ve a tu altura. Esperalo en un borde y cortalo cuando gire."],
	"sulfur_cloud": ["Gas", "Flota hacia vos. No hace daño, pero empaña la hoja (daño a la mitad). La espada lo atraviesa: pulí para limpiarla o disipalo con el Yunque."],
	"will_o_wisp": ["Llama", "Flota hacia vos y calienta la espada hasta ablandar la plata (pega menos y pierde filo). Un golpe de Yunque lo apaga; no lo dejes cerca mucho tiempo."],
	"shadow": ["Sombra", "No hace daño: se pega a Platero y le roba plata, y después se va. La espada la atraviesa; dispersala con el Yunque o dejala atrás con la Pluma."],
	"bronze_guard": ["Élite con escudo", "El escudo cubre el frente: un tajo de cara rebota y mella la espada. Rodealo y pegale por la espalda, o caele encima con el Yunque."],
	"slag_sentinel": ["Lanzador", "Quieto, te apunta y tira escoria; avisa con un destello. Bloqueá el proyectil con la guardia (un bloqueo perfecto lo devuelve) o esquivalo."],
	"reflection": ["Reflejo", "Copia tus movimientos con un poco de retraso y cae de un solo golpe."],
}

static var _notes: Dictionary = {}
static var _notes_loaded: bool = false
static var _places: Dictionary = {}


## Las categorías con sus entradas, en orden. `is_seen` es una función (clase, id) → bool que dice si el
## jugador ya descubrió algo; sin función se usa `WikiProgress.is_seen`. Una categoría sin entradas se omite.
static func categories(is_seen: Callable = Callable()) -> Array[WikiCategory]:
	var seen := is_seen if is_seen.is_valid() else WikiProgress.is_seen
	var result: Array[WikiCategory] = []
	for provider: Dictionary in _providers():
		var build: Callable = provider["build"]
		var entries: Array[WikiEntry] = build.call(seen)
		if not entries.is_empty():
			result.append(WikiCategory.new(provider["id"], provider["title"], entries))
	return result


static func _providers() -> Array[Dictionary]:
	return [
		{"id": &"enemigos", "title": "Enemigos", "build": _enemy_entries},
		{"id": &"jefes", "title": "Jefes", "build": _boss_entries},
		{"id": &"patronos", "title": "Patronos", "build": _patron_entries},
		{"id": &"espadas", "title": "Espadas", "build": _sword_entries},
		{"id": &"lugares", "title": "Lugares", "build": _place_entries},
		{"id": &"guia", "title": "Guía", "build": _guide_entries},
	]


# --- datos y textos -----------------------------------------------------------------

static func _note(kind: String, id: StringName) -> Dictionary:
	if not _notes_loaded:
		_notes_loaded = true
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(NOTES_PATH)) == OK and typeof(json.data) == TYPE_DICTIONARY:
			_notes = json.data
	var group: Variant = _notes.get(kind, {})
	if typeof(group) != TYPE_DICTIONARY:
		return {}
	return (group as Dictionary).get(String(id), {})


## Todos los .tres de una carpeta (también en el ejecutable exportado, donde se listan como `.tres.remap`).
static func _load_all(dir: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var files := DirAccess.get_files_at(dir)
	files.sort()
	for file in files:
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var resource := load(dir + name)
			if resource != null:
				result.append(resource)
	return result


static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


static func _hearts(value: float) -> String:
	if value <= 0.0:
		return "no daña"
	return "%s %s" % [_number(value), "corazón" if is_equal_approx(value, 1.0) else "corazones"]


## Primer cuadro de `idle`, recortado a lo que se dibuja (los lienzos de los jefes tienen mucho margen vacío).
static func _portrait(frames: SpriteFrames) -> Texture2D:
	if frames == null or not frames.has_animation(&"idle") or frames.get_frame_count(&"idle") == 0:
		return null
	var frame := frames.get_frame_texture(&"idle", 0)
	var image := frame.get_image()
	if image == null:
		return frame
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return frame
	return ImageTexture.create_from_image(image.get_region(used))


static func _locked_entry(id: StringName, icon: Texture2D) -> WikiEntry:
	var entry := WikiEntry.new()
	entry.id = id
	entry.title = LOCKED_TITLE
	entry.locked = true
	entry.icon = icon
	entry.add_text(LOCKED_TEXT)
	return entry


## Etapa → {arco, etapa, número} para «dónde aparece» y la categoría Lugares.
static func _place_table() -> Dictionary:
	if _places.is_empty():
		var campaign := load(WikiIndex.CAMPAIGN_PATH) as CampaignDefinition
		for arc in campaign.arcs:
			var number := 0
			for stage in WikiIndex.stages_of(arc):
				number += 1
				_places[stage.id] = {"arc": arc, "stage": stage, "number": number}
	return _places


static func _stage_label(stage_id: StringName) -> String:
	var table := _place_table()
	if not table.has(stage_id):
		return String(stage_id)
	var info: Dictionary = table[stage_id]
	return "%s · %s" % [(info["arc"] as ArcDefinition).display_name, (info["stage"] as StageDefinition).display_name]


static func _stage_ids(kind: String, id: StringName) -> Array[StringName]:
	var index := WikiIndex.load_saved()
	var found: Array[StringName] = []
	var listed: Variant = (index.get(kind, {}) as Dictionary).get(String(id), [])
	if typeof(listed) == TYPE_STRING:
		listed = [listed]
	for stage_id: Variant in listed:
		found.append(StringName(str(stage_id)))
	return found


# --- enemigos ------------------------------------------------------------------------

static func _enemy_entries(is_seen: Callable) -> Array[WikiEntry]:
	var enemies: Array[EnemyDefinition] = []
	for resource in _load_all(ENEMIES_DIR):
		var definition := resource as EnemyDefinition
		if definition != null and not String(definition.id).ends_with("_body"):
			enemies.append(definition)
	# Del más débil al más fuerte; a igual vida, por id, para que el orden no cambie.
	enemies.sort_custom(func(a: EnemyDefinition, b: EnemyDefinition) -> bool:
		return a.max_hp < b.max_hp or (a.max_hp == b.max_hp and String(a.id) < String(b.id)))
	var entries: Array[WikiEntry] = []
	for definition in enemies:
		if is_seen.call(WikiProgress.ENEMY, definition.id):
			entries.append(enemy_entry(definition))
		else:
			entries.append(_locked_entry(definition.id, _portrait(definition.sprite_frames)))
	return entries


static func _archetype_of(definition: EnemyDefinition) -> Array:
	if definition.scene == null:
		return ["", ""]
	var key := definition.scene.resource_path.get_file().get_basename()
	return ARCHETYPES.get(key, ["", ""])


static func enemy_entry(definition: EnemyDefinition) -> WikiEntry:
	var entry := WikiEntry.new()
	entry.id = definition.id
	entry.title = definition.display_name
	entry.icon = _portrait(definition.sprite_frames)
	var archetype := _archetype_of(definition)
	entry.subtitle = String(archetype[0])
	var note := _note("enemy", definition.id)
	if note.has("texto"):
		entry.add_text(String(note["texto"]))
	var facts: Array = [
		["Vida", _number(definition.max_hp)],
		["Armadura", _number(definition.armor) if definition.armor > 0.0 else "ninguna"],
		["Daño por contacto", _hearts(definition.contact_damage)],
		["Velocidad", "%s px/s" % _number(definition.move_speed)],
	]
	var silver := _silver_text(definition.loot)
	if silver != "":
		facts.append(["Plata que suelta", silver])
	if definition.hardness != 1.0:
		facts.append(["Dureza", "×%s de desgaste en la espada" % _number(definition.hardness)])
	facts.append(["La espada lo atraviesa", "sí" if definition.sword_immune else "no"])
	facts.append(["Se puede aplastar con el Yunque", "sí" if definition.stompable else "no"])
	if definition.armored_start:
		facts.append(["Coraza empañada", "sí: la espada rebota hasta pulirla"])
	entry.add_facts(facts)

	entry.add_heading("Cómo enfrentarlo")
	var tips: Array[String] = []
	if String(archetype[1]) != "":
		tips.append(String(archetype[1]))
	if definition.armored_start:
		tips.append("Su coraza empañada hace rebotar la espada: pulila (L) o golpealo con el Yunque para abrirla.")
	if definition.armor >= 40.0:
		tips.append("Tiene mucha armadura: el Yunque y el martillo ignoran la mitad, así que rinden más que el tajo.")
	if definition.hardness > 1.0:
		tips.append("Es duro: cada golpe de espada gasta más filo.")
	if definition.climb_walls:
		tips.append("Trepa por las paredes.")
	if tips.is_empty():
		tips.append("Un tajo de espada alcanza; el Yunque desde arriba también sirve.")
	entry.add_text("\n".join(tips))
	_add_appearances(entry, "enemies", definition.id, note)
	return entry


static func _silver_text(loot: LootTable) -> String:
	if loot == null:
		return ""
	var low := 0
	var high := 0
	for item in loot.entries:
		if item.item == &"silver":
			low += item.min_amount
			high += item.max_amount
	if high <= 0:
		return ""
	return str(low) if low == high else "%d–%d" % [low, high]


static func _add_appearances(entry: WikiEntry, kind: String, id: StringName, note: Dictionary) -> void:
	var stages := _stage_ids(kind, id)
	for extra: Variant in note.get("tambien_en", []):
		if not stages.has(StringName(str(extra))):
			stages.append(StringName(str(extra)))
	entry.add_heading("Dónde aparece")
	if stages.is_empty():
		entry.add_text("No aparece en una etapa fija: acompaña a otro enemigo o jefe.")
		return
	var lines: Array[String] = []
	for stage_id in stages:
		lines.append(_stage_label(stage_id))
	entry.add_text("\n".join(lines))


# --- jefes ---------------------------------------------------------------------------

static func _boss_entries(is_seen: Callable) -> Array[WikiEntry]:
	var bosses: Array[BossDefinition] = []
	for resource in _load_all(BOSSES_DIR):
		var definition := resource as BossDefinition
		if definition != null:
			bosses.append(definition)
	# En el orden en que aparecen en la campaña; los que no están en una etapa, al final.
	bosses.sort_custom(func(a: BossDefinition, b: BossDefinition) -> bool:
		return _boss_order(a) < _boss_order(b))
	var entries: Array[WikiEntry] = []
	for definition in bosses:
		var portrait := _portrait(definition.enemy.sprite_frames) if definition.enemy != null else null
		if is_seen.call(WikiProgress.BOSS, definition.id):
			entries.append(boss_entry(definition))
		else:
			entries.append(_locked_entry(definition.id, portrait))
	return entries


static func _boss_order(definition: BossDefinition) -> int:
	var stages := _stage_ids("bosses", definition.id)
	if stages.is_empty():
		return 999
	var campaign := load(WikiIndex.CAMPAIGN_PATH) as CampaignDefinition
	var order := 0
	for arc in campaign.arcs:
		for stage in WikiIndex.stages_of(arc):
			if stage.id == stages[0]:
				return order
			order += 1
	return 999


static func boss_entry(definition: BossDefinition) -> WikiEntry:
	var entry := WikiEntry.new()
	entry.id = definition.id
	entry.title = definition.display_name
	var body := definition.enemy
	entry.icon = _portrait(body.sprite_frames) if body != null else null
	var stages := _stage_ids("bosses", definition.id)
	var kind := "Jefe"
	if not stages.is_empty() and _place_table().has(stages[0]):
		var stage: StageDefinition = _place_table()[stages[0]]["stage"]
		match stage.kind:
			StageDefinition.Kind.SUBBOSS: kind = "Subjefe"
			StageDefinition.Kind.INTERLUDE: kind = "Prueba del interludio"
	entry.subtitle = kind
	var note := _note("boss", definition.id)
	if note.has("texto"):
		entry.add_text(String(note["texto"]))
	if definition.intro_text != "":
		entry.add_text("«%s»" % definition.intro_text)
	var phases: Array[String] = []
	for phase in definition.phases:
		phases.append(_number(phase.hp))
	var facts: Array = [["Fases", str(definition.phases.size())], ["Vida de cada fase", " / ".join(phases)]]
	if body != null:
		facts.append(["Armadura", _number(body.armor) if body.armor > 0.0 else "ninguna"])
		facts.append(["Daño por contacto", _hearts(body.contact_damage)])
		if body.hardness != 1.0:
			facts.append(["Dureza", "×%s de desgaste en la espada" % _number(body.hardness)])
	entry.add_facts(facts)
	if note.has("consejo"):
		entry.add_heading("Cómo vencerlo")
		entry.add_text(String(note["consejo"]))
	entry.add_heading("Dónde está")
	var places: Array[String] = []
	for stage_id in stages:
		places.append(_stage_label(stage_id))
	entry.add_text("\n".join(places) if not places.is_empty() else "No está en una etapa fija.")
	return entry


# --- patronos ------------------------------------------------------------------------

static func _patron_entries(is_seen: Callable) -> Array[WikiEntry]:
	var patrons: Array[PatronDefinition] = []
	var arcs_of := {}
	var campaign := load(WikiIndex.CAMPAIGN_PATH) as CampaignDefinition
	for arc in campaign.arcs:
		for patron in arc.patrons:
			if not arcs_of.has(patron.id):
				patrons.append(patron)
				arcs_of[patron.id] = []
			(arcs_of[patron.id] as Array).append(arc.display_name)
	var entries: Array[WikiEntry] = []
	for patron in patrons:
		if is_seen.call(WikiProgress.PATRON, patron.id):
			entries.append(patron_entry(patron, arcs_of[patron.id]))
		else:
			entries.append(_locked_entry(patron.id, patron.icon))
	return entries


static func patron_entry(patron: PatronDefinition, arcs: Array = []) -> WikiEntry:
	var entry := WikiEntry.new()
	entry.id = patron.id
	entry.title = patron.display_name
	entry.icon = patron.icon
	entry.subtitle = "Patrono · %s" % _verb_text(patron.verb)
	var note := _note("patron", patron.id)
	if note.has("texto"):
		entry.add_text(String(note["texto"]))
	if patron.description != "":
		entry.add_heading("Qué hace")
		entry.add_text(patron.description)
	var facts: Array = []
	if patron.ability != null:
		facts.append(["Reutilización de la habilidad (I)", "%s s" % _number(patron.ability.cooldown)])
	if not arcs.is_empty():
		facts.append(["Se puede elegir en", ", ".join(PackedStringArray(arcs))])
	if not facts.is_empty():
		entry.add_facts(facts)
	return entry


static func _verb_text(verb: StringName) -> String:
	match verb:
		&"sword": return "espada"
		&"silver": return "plata"
		&"world": return "mundo"
		&"jump": return "salto"
		&"defense": return "defensa"
	return String(verb)


# --- espadas -------------------------------------------------------------------------

static func _sword_entries(is_seen: Callable) -> Array[WikiEntry]:
	var swords: Array[SwordDefinition] = []
	for id: StringName in SwordCatalog.PATHS:
		swords.append(SwordCatalog.get_definition(id))
	# La heredada primero; el resto por filo máximo.
	swords.sort_custom(func(a: SwordDefinition, b: SwordDefinition) -> bool: return a.max_edge < b.max_edge)
	var entries: Array[WikiEntry] = []
	for sword in swords:
		if is_seen.call(WikiProgress.SWORD, sword.id):
			entries.append(sword_entry(sword))
		else:
			entries.append(_locked_entry(sword.id, null))
	return entries


static func sword_entry(sword: SwordDefinition) -> WikiEntry:
	var entry := WikiEntry.new()
	entry.id = sword.id
	entry.title = sword.display_name
	entry.subtitle = "Espada de plata"
	var note := _note("sword", sword.id)
	if note.has("texto"):
		entry.add_text(String(note["texto"]))
	entry.add_facts([
		["Filo máximo", _number(sword.max_edge)],
		["Piso del filo (al afilar)", _number(sword.floor_edge)],
		["Daño base", _number(sword.base_damage)],
		["Desgaste por golpe", _number(sword.wear_per_hit)],
		["Metal que quita afilar", "hasta %s" % _number(sword.sharpen_loss)],
		["Costo de afilar", "%d de plata" % sword.sharpen_cost],
		["Penetración de armadura", "%d %%" % roundi(sword.armor_penetration * 100.0)],
		["Alcance del tajo", "%d × %d px" % [int(sword.hitbox_size.x), int(sword.hitbox_size.y)]],
	])
	return entry


# --- lugares -------------------------------------------------------------------------

static func _place_entries(is_seen: Callable) -> Array[WikiEntry]:
	var campaign := load(WikiIndex.CAMPAIGN_PATH) as CampaignDefinition
	var entries: Array[WikiEntry] = []
	for arc in campaign.arcs:
		var visited := is_seen.call(WikiProgress.PLACE, arc.id) as bool
		if visited:
			entries.append(place_entry(arc, is_seen))
		else:
			entries.append(_locked_entry(arc.id, null))
	return entries


static func place_entry(arc: ArcDefinition, is_seen: Callable) -> WikiEntry:
	var entry := WikiEntry.new()
	entry.id = arc.id
	entry.title = arc.display_name
	entry.subtitle = "%d a. C." % arc.year_bc
	var note := _note("place", arc.id)
	if note.has("texto"):
		entry.add_text(String(note["texto"]))
	entry.add_heading("Etapas")
	var rows: Array = [["Etapa", "Tipo"]]
	for stage in WikiIndex.stages_of(arc):
		var known := is_seen.call(WikiProgress.PLACE, stage.id) as bool
		rows.append([stage.display_name if known else LOCKED_TITLE, _stage_kind_text(stage.kind) if known else ""])
	entry.add_table(rows)
	var patrons: Array[String] = []
	for patron in arc.patrons:
		patrons.append(patron.display_name)
	if not patrons.is_empty():
		entry.add_heading("Patronos")
		entry.add_text(", ".join(PackedStringArray(patrons)))
	return entry


static func _stage_kind_text(kind: StageDefinition.Kind) -> String:
	match kind:
		StageDefinition.Kind.SUBBOSS: return "subjefe"
		StageDefinition.Kind.BOSS: return "jefe"
		StageDefinition.Kind.INTERLUDE: return "interludio"
	return "etapa"


# --- guía ----------------------------------------------------------------------------

static func _guide_entries(_is_seen: Callable) -> Array[WikiEntry]:
	var articles: Array[Dictionary] = []
	for file in DirAccess.get_files_at(ARTICLES_DIR):
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".json"):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(ARTICLES_DIR + name)) != OK or typeof(json.data) != TYPE_DICTIONARY:
			push_warning("Artículo de la wiki ilegible: %s" % name)
			continue
		var data: Dictionary = json.data
		data["id"] = name.get_basename()
		articles.append(data)
	articles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa := int(a.get("orden", GUIDE_ORDER_DEFAULT))
		var ob := int(b.get("orden", GUIDE_ORDER_DEFAULT))
		return oa < ob or (oa == ob and String(a["id"]) < String(b["id"])))
	var entries: Array[WikiEntry] = []
	for data in articles:
		entries.append(article_entry(data))
	entries.append(controls_entry())
	return entries


static func article_entry(data: Dictionary) -> WikiEntry:
	var entry := WikiEntry.new()
	entry.id = StringName(String(data.get("id", "")))
	entry.title = String(data.get("titulo", entry.id))
	entry.subtitle = String(data.get("subtitulo", ""))
	for block: Dictionary in data.get("bloques", []):
		match String(block.get("tipo", "")):
			WikiEntry.KIND_HEADING: entry.add_heading(String(block.get("texto", "")))
			WikiEntry.KIND_TEXT: entry.add_text(String(block.get("texto", "")))
			WikiEntry.KIND_FACTS: entry.add_facts(block.get("filas", []))
			WikiEntry.KIND_TABLE: entry.add_table(block.get("filas", []))
	return entry


## Las teclas actuales (con los cambios del jugador), leídas del InputMap.
static func controls_entry() -> WikiEntry:
	ControlBindings.ensure_loaded()
	var entry := WikiEntry.new()
	entry.id = &"controles"
	entry.title = "Controles"
	entry.subtitle = "Teclado y mando; se cambian en «Controles»"
	var rows: Array = [["Acción", "Teclas", "Mando"]]
	for action in ControlBindings.GAME_ACTIONS:
		var keys: Array[String] = []
		for code in ControlBindings.keys_of(action):
			if code != 0:
				keys.append(ControlBindings.key_text(code))
		var joy := ControlBindings.joy_text(ControlBindings.joy_of(action)[0])
		var axis := ControlBindings.axis_text(action)
		if axis != "":
			joy = axis if joy == "—" else "%s + %s" % [joy, axis]
		rows.append([ControlBindings.label(action), " / ".join(PackedStringArray(keys)) if not keys.is_empty() else "—", joy])
	entry.add_table(rows)
	return entry
