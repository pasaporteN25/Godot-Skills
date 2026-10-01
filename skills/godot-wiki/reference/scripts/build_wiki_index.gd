extends SceneTree
## Regenera `resources/wiki/appearances.json` (qué enemigos salen en qué etapas, spec 016).
## Uso: Godot_console.exe --headless --path . -s tools/build_wiki_index.gd


func _initialize() -> void:
	var index := WikiIndex.build()
	var file := FileAccess.open(WikiIndex.PATH, FileAccess.WRITE)
	file.store_string(WikiIndex.to_json(index))
	print("Índice de la wiki: %d enemigos, %d jefes" % [(index["enemies"] as Dictionary).size(), (index["bosses"] as Dictionary).size()])
	quit()
