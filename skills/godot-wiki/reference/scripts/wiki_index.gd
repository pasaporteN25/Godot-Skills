class_name WikiIndex
extends RefCounted
## Índice «dónde aparece» de la wiki (spec 016): qué enemigos salen en qué etapas y en cuál está cada jefe.
## Se genera recorriendo las salas (`tools/build_wiki_index.gd`) y se guarda en `resources/wiki/appearances.json`;
## un test comprueba que el archivo siga al día.

const PATH := "res://resources/wiki/appearances.json"
const CAMPAIGN_PATH := "res://resources/campaigns/main_campaign.tres"


## Etapas de un arco en orden, con su interludio al final si lo tiene.
static func stages_of(arc: ArcDefinition) -> Array[StageDefinition]:
	var stages: Array[StageDefinition] = []
	stages.assign(arc.stages)
	if arc.interlude != null:
		stages.append(arc.interlude)
	return stages


## Recorre todas las salas de la campaña y arma el índice: {"enemies": {id: [etapas]}, "bosses": {id: etapa}}.
static func build() -> Dictionary:
	var campaign := load(CAMPAIGN_PATH) as CampaignDefinition
	var enemies := {}
	var bosses := {}
	for arc in campaign.arcs:
		for stage in stages_of(arc):
			for definition in stage.rooms:
				var room := definition.scene.instantiate() as Room
				room.scan()
				for spawner in room.encounter_spawners:
					if spawner.table == null:
						continue
					for entry in spawner.table.entries:
						if entry.definition != null:
							var list: Array = enemies.get(String(entry.definition.id), [])
							if not list.has(String(stage.id)):
								list.append(String(stage.id))
							enemies[String(entry.definition.id)] = list
				for spawner in room.boss_spawners:
					if spawner.boss != null:
						bosses[String(spawner.boss.id)] = String(stage.id)
				room.free()
	for id in enemies:
		(enemies[id] as Array).sort()
	return {"version": 1, "enemies": enemies, "bosses": bosses}


static func to_json(index: Dictionary) -> String:
	return JSON.stringify(index, "\t", true) + "\n"


## El índice guardado (vacío si falta o está dañado).
static func load_saved() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PATH)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data
