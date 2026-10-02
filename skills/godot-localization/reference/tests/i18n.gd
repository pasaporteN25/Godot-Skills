extends SceneTree
## Spec 017: idiomas. Catálogo de textos, traducción al inglés, selector, preferencia guardada y pantallas en inglés.
## Uso: Godot_console.exe --headless --path . -s tests/headless/i18n.gd

const LANG_TMP := "user://test_language.json"
const PROGRESS_TMP := "user://test_i18n_wiki_progress.json"
## Nombres de personajes, dioses, criaturas y lugares míticos: no se traducen (decisión del usuario).
const PROPER_NOUNS: Array[String] = [
	"Platero", "Argantonio", "Cronos", "Hades", "Tartessos", "Briareo", "Hipno", "Hefesto", "Artemisa", "Brontes",
	"Cloto", "Láquesis", "Átropos", "Tharsis", "Ogigia", "Caronte", "Zeus", "Heracles", "Umbral", "Moiras", "Oniros",
	"Leteo", "Polemarco", "Hecatónquiro",
]

var failures: Array[String] = []
var checks := 0
var catalog: Array[Dictionary] = []
var english: Dictionary = {}


func _initialize() -> void:
	SaveGame.enabled = false
	AudioSettings.enabled = false
	Loc.enabled = false
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	TestMode.force = 0
	WikiProgress.path = PROGRESS_TMP
	WikiProgress.erase_file()
	catalog = TranslationCatalog.extract()
	english = TranslationCatalog.read_po("res://translations/en.po")
	_test_startup_is_spanish()
	_test_catalog()
	_test_translations()
	_test_proper_nouns()
	_test_loc_api()
	_test_persistence()
	await _test_menus()
	await _test_ending()
	_test_wiki()
	_test_pseudo()
	Loc.set_language("es")
	Loc.set_pseudo(false)
	_cleanup()
	print("\nIdiomas: %d controles / %d fallos" % [checks, failures.size()])
	for f in failures:
		print("  FALLÓ: %s" % f)
	quit(0 if failures.is_empty() else 1)


# --- arranque --------------------------------------------------------------------------------

func _test_startup_is_spanish() -> void:
	# AC-017-5: un script suelto arranca en español sea cual sea el idioma de la computadora.
	check(Loc.is_script_run(), "AC-017-5: Godot corre un script suelto (-s)")
	check(Loc.current() == "es" and TranslationServer.get_locale().begins_with("es"), "AC-017-5: un script suelto arranca en español")
	check(Loc.t("Nueva partida") == "Nueva partida", "AC-017-5: en español los textos salen tal cual")
	check(Loc._arg_language() == "", "AC-017-5: sin --lang no hay idioma forzado")


# --- catálogo --------------------------------------------------------------------------------

func _test_catalog() -> void:
	check(catalog.size() > 300, "El catálogo junta los textos del juego (%d)" % catalog.size())
	# AC-017-2: la plantilla y el inglés están al día.
	var pot := FileAccess.get_file_as_string(TranslationCatalog.POT_PATH)
	check(pot == TranslationCatalog.write_po(catalog, {}, ""), "AC-017-2: es.pot coincide con lo que extrae la herramienta (correr tools/build_translations.gd)")
	var wanted := {}
	for entry in catalog:
		wanted[entry["msgid"]] = true
	var missing: Array[String] = []
	for msgid: String in wanted:
		if not english.has(msgid):
			missing.append(msgid.left(40))
	var obsolete: Array[String] = []
	for msgid: String in english:
		if not wanted.has(msgid):
			obsolete.append(msgid.left(40))
	check(missing.is_empty(), "AC-017-2: todo texto del juego está en en.po (faltan: %s)" % ", ".join(missing.slice(0, 3)))
	check(obsolete.is_empty(), "AC-017-2: en.po no tiene textos que ya no existen (sobran: %s)" % ", ".join(obsolete.slice(0, 3)))
	# El extractor entiende lo que dice entender.
	var sample := TranslationCatalog.script_texts('var a := tr("Uno")\n# i18n\nconst X := "Dos"\nconst Y := {"k": "Tres", &"n": 5}\n\nvar b := "Cuatro"\nvar c := Loc.t("Cinco %d") % 3\n# tr("Comentario")\n')
	check(sample == ["Uno", "Dos", "Tres", "Cinco %d"], "El extractor: tr, Loc.t y bloques «# i18n» (sin claves ni StringName): %s" % str(sample))
	check(TranslationCatalog.resource_texts('display_name = "A b"\nid = &"x"\nhades_lines = Array[String](["Uno", "Dos"])\nintro_text = "L1\nL2"\n') == ["A b", "Uno", "Dos", "L1\nL2"], "El extractor lee los campos de texto de un .tres (también varias líneas)")


func _test_translations() -> void:
	# AC-017-1: nada sin traducir y con los mismos marcadores de formato.
	var empty: Array[String] = []
	var bad_format: Array[String] = []
	var same_long: Array[String] = []
	var same_count := 0
	for entry in catalog:
		var msgid: String = entry["msgid"]
		var text: String = english.get(msgid, "")
		if text == "":
			empty.append(msgid.left(40))
			continue
		if TranslationCatalog.placeholders(msgid) != TranslationCatalog.placeholders(text):
			bad_format.append(msgid.left(40))
		if text == msgid:
			same_count += 1
			if msgid.split(" ", false).size() > 4:
				same_long.append(msgid.left(40))
	check(empty.is_empty(), "AC-017-1: ningún texto tiene la traducción vacía (%s)" % ", ".join(empty.slice(0, 3)))
	check(bad_format.is_empty(), "AC-017-1: los %%s/%%d coinciden con el original (%s)" % ", ".join(bad_format.slice(0, 3)))
	check(same_long.is_empty(), "AC-017-1: ninguna frase larga quedó igual que en español (%s)" % ", ".join(same_long.slice(0, 3)))
	print("  (%d textos iguales en los dos idiomas: nombres propios, teclas y siglas)" % same_count)


func _test_proper_nouns() -> void:
	# AC-017-3: los nombres propios siguen iguales.
	var lost: Array[String] = []
	for entry in catalog:
		var msgid: String = entry["msgid"]
		var text: String = english.get(msgid, "")
		for noun in PROPER_NOUNS:
			if msgid.contains(noun) and not text.contains(noun):
				lost.append("%s en «%s»" % [noun, msgid.left(30)])
	check(lost.is_empty(), "AC-017-3: los nombres propios no se traducen (%s)" % ", ".join(lost.slice(0, 3)))


# --- API de idioma ---------------------------------------------------------------------------

func _test_loc_api() -> void:
	check(Loc.codes() == ["es", "en"] and Loc.next_code() == "en", "Los idiomas son español e inglés y el siguiente de es es en")
	check(not Loc.set_language("xx") and Loc.current() == "es", "Un idioma que no existe se rechaza")
	check(Loc.set_language("en") and Loc.current() == "en" and Loc.current_name() == "English", "Cambiar a inglés es inmediato")
	check(Loc.t("Nueva partida") == "New game" and Loc.t("Volver") == "Back", "En inglés Loc.t traduce")
	check(Loc.t("Nivel %d: hacen falta %d de plata total (llevás %d)") % [1, 2, 3] == "Level 1: needs 2 total silver (you have 3)", "Un texto con datos se traduce y se formatea")
	check(Loc.t("Esto no está en el catálogo") == "Esto no está en el catálogo", "Un texto desconocido sale tal cual")
	check(Loc.next_code() == "es", "En inglés el siguiente idioma es es")
	check(Loc.set_language("es") and Loc.t("Nueva partida") == "Nueva partida", "Volver a español")
	for code in Loc.codes():
		if code != Loc.SOURCE:
			var registered := ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()) as PackedStringArray
			check(FileAccess.file_exists("res://translations/%s.po" % code) and registered.has("res://translations/%s.po" % code), "El idioma %s tiene su .po y está en project.godot" % code)


func _test_persistence() -> void:
	# AC-017-4: preferencia guardada.
	var old_path := Loc.path
	var old_enabled := Loc.enabled
	Loc.path = LANG_TMP
	Loc.enabled = true
	_delete(LANG_TMP)
	check(Loc._read_saved() == "", "AC-017-4: sin archivo no hay preferencia")
	Loc.set_language("en")
	check(FileAccess.file_exists(LANG_TMP) and Loc._read_saved() == "en", "AC-017-4: al elegir un idioma se guarda y se lee")
	Loc.set_language("es")
	check(Loc._read_saved() == "es", "AC-017-4: el último idioma elegido es el que queda")
	for garbage in ["no es json", "[1, 2]", '{"version": 1}', '{"version": 2, "language": "en"}', '{"version": 1, "language": "klingon"}', '{"version": 1, "language": 5}']:
		var file := FileAccess.open(LANG_TMP, FileAccess.WRITE)
		file.store_string(garbage)
		file.close()
		check(Loc._read_saved() == "", "AC-017-4: archivo inválido ignorado: " + garbage.substr(0, 28))
	Loc.enabled = false
	_delete(LANG_TMP)
	Loc.set_language("en")
	check(not FileAccess.file_exists(LANG_TMP), "AC-017-4: con el guardado apagado no se escribe nada")
	Loc.set_language("es")
	Loc.path = old_path
	Loc.enabled = old_enabled


# --- pantallas ---------------------------------------------------------------------------------

func _button_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in node.find_children("*", "Button", true, false):
		texts.append((child as Button).text)
	return texts


func _label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in node.find_children("*", "Label", true, false):
		texts.append((child as Label).text)
	return texts


func _test_menus() -> void:
	var old_path := Loc.path
	var old_enabled := Loc.enabled
	Loc.path = LANG_TMP
	Loc.enabled = true
	_delete(LANG_TMP)
	Loc.set_language("en")
	var menu := (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await frames(2)
	var buttons := _button_texts(menu)
	check(buttons == ["New game", "Continue", "Wiki", "Controls", "Language: English", "Quit"], "AC-017-6: el menú principal en inglés: %s" % str(buttons))
	check(_label_texts(menu).has("I used to walk. Now I jump.") and _label_texts(menu).has("FORMER WALKER"), "AC-017-6: el subtítulo se traduce y el título no")
	# Cambiar de idioma desde el menú lo vuelve a armar (y guarda la preferencia).
	menu._on_language()
	await frames(2)
	buttons = _button_texts(menu)
	check(Loc.current() == "es" and buttons == ["Nueva partida", "Continuar", "Wiki", "Controles", "Idioma: Español", "Salir"], "AC-017-6: el selector pasa a español y reconstruye el menú: %s" % str(buttons))
	check(Loc._read_saved() == "es", "AC-017-6: el selector guarda la preferencia")
	check(menu.get_child_count() == 2 or menu.get_child_count() == 3, "AC-017-6: el menú no acumula pantallas viejas (%d hijos)" % menu.get_child_count())
	menu._on_language()
	await frames(2)
	check(Loc.current() == "en" and menu._language_button.text == "Language: English", "AC-017-6: el selector vuelve a inglés")
	menu.queue_free()
	await frames(1)

	var pause := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	root.add_child(pause)
	await frames(2)
	var pause_texts := _button_texts(pause) + _label_texts(pause)
	check(pause_texts.has("Pause") and pause_texts.has("Volume") and pause_texts.has("Music") and pause_texts.has("Effects") and pause_texts.has("Main menu") and pause_texts.has("Quit"), "AC-017-6: la pausa en inglés: %s" % str(pause_texts))
	pause._on_controls()
	await frames(2)
	var controls_texts := _button_texts(pause._controls) + _label_texts(pause._controls)
	check(controls_texts.has("Controls") and controls_texts.has("Restore all") and controls_texts.has("Move left") and controls_texts.has("Jump") and controls_texts.has("Gamepad: A"), "AC-017-6: la pantalla de controles en inglés")
	var hint := ""
	for text in _label_texts(pause._controls):
		if text.begins_with("Click a slot"):
			hint = text
	check(hint != "", "AC-017-6: el cartel de ayuda de los controles se traduce")
	pause.queue_free()
	await frames(1)
	Loc.set_language("es")
	Loc.path = old_path
	Loc.enabled = old_enabled
	_delete(LANG_TMP)


func _test_ending() -> void:
	Loc.set_language("en")
	var ending := EndingScreen.new()
	ending.outcome = &"liberated"
	root.add_child(ending)
	await frames(1)
	check(ending._pages[0] == "Argantonio stopped holding up time. Tartessos, slowly, began to breathe.", "AC-017-6: el final en inglés traduce la página del desenlace")
	check(ending._pages.size() == 3 and ending._hint.text == "End of Arc I  ·  [Space] continue", "AC-017-6: el final en inglés traduce las demás páginas y la guía")
	ending.queue_free()
	await frames(1)
	var arc3 := ending_for_arc3()
	check(arc3.begins_with("Cronos went back to sleep."), "AC-017-6: el final del arco III (dato del arco) se traduce")
	Loc.set_language("es")


func ending_for_arc3() -> String:
	var arc := load("res://resources/arcs/arc_iii.tres") as ArcDefinition
	return tr(String(arc.outcome_pages[&"slept"]))


# --- wiki -------------------------------------------------------------------------------------

func _all_seen(_kind: StringName, _id: StringName) -> bool:
	return true


func _none_seen(_kind: StringName, _id: StringName) -> bool:
	return false


func _has_digit(text: String) -> bool:
	for ch in text:
		if ch >= "0" and ch <= "9":
			return true
	return false


## Cada texto suelto de una entrada: títulos, párrafos y celdas.
func _strings_of(entry: WikiEntry) -> Array[String]:
	var found: Array[String] = [entry.title, entry.subtitle]
	for block in entry.blocks:
		if block.has("texto"):
			found.append(String(block["texto"]))
		for row: Array in block.get("filas", []):
			for cell in row:
				found.append(String(cell))
	return found


func _test_wiki() -> void:
	Loc.set_language("en")
	var open := Wiki.categories(_all_seen)
	var titles: Array[String] = []
	for category in open:
		titles.append(category.title)
	check(titles == ["Enemies", "Bosses", "Patrons", "Swords", "Places", "Guide"], "AC-017-6: las categorías de la wiki en inglés: %s" % str(titles))
	# Nada de lo abierto queda en español.
	var leftovers: Array[String] = []
	for category in open:
		for entry in category.entries:
			for text in _strings_of(entry):
				for line in text.split("\n"):
					if english.has(line) and english[line] != line:
						leftovers.append(line.left(40))
	check(leftovers.is_empty(), "AC-017-1: la wiki abierta no deja textos en español (%s)" % ", ".join(leftovers.slice(0, 3)))
	var moth := _entry(open, &"enemigos", &"clock_moth")
	check(moth != null and moth.title == "Clock moth" and moth.subtitle == "Flyer", "La entrada de un enemigo en inglés: título y tipo")
	check(_fact(moth, "Health") != "" and _fact(moth, "Contact damage") != "" and _fact(moth, "The sword passes through it") in ["yes", "no"], "La entrada de un enemigo en inglés: datos")
	var controls := _entry(open, &"guia", &"controles")
	check(controls != null and controls.title == "Controls" and String(controls.blocks[0]["filas"][0][0]) == "Action", "AC-017-7: «Controles» en inglés")
	# AC-017-7: lo cerrado no filtra nombres ni números, tampoco en inglés.
	var closed := Wiki.categories(_none_seen)
	var names: Array[String] = []
	for resource in Wiki._load_all(Wiki.ENEMIES_DIR):
		names.append(Loc.t((resource as EnemyDefinition).display_name))
	for resource in Wiki._load_all(Wiki.BOSSES_DIR):
		names.append(Loc.t((resource as BossDefinition).display_name))
	var leaks := false
	var all_locked := true
	for category in closed:
		if category.id == &"guia":
			continue
		for entry in category.entries:
			all_locked = all_locked and entry.locked and entry.title == Wiki.LOCKED_TITLE
			var plain := entry.plain_text()
			leaks = leaks or _has_digit(plain) or plain.contains("Todavía")
			for name in names:
				leaks = leaks or plain.contains(name)
	check(all_locked and not leaks, "AC-017-7: en inglés lo cerrado es «???» y no lleva nombres ni números")
	Loc.set_language("es")
	var spanish := Wiki.categories(_all_seen)
	check(_entry(spanish, &"enemigos", &"clock_moth").title == "Polilla-reloj", "En español la wiki sigue igual")


func _entry(categories: Array[WikiCategory], category_id: StringName, entry_id: StringName) -> WikiEntry:
	for category in categories:
		if category.id == category_id:
			return category.find(entry_id)
	return null


func _fact(entry: WikiEntry, label: String) -> String:
	for block in entry.blocks:
		for row: Array in block.get("filas", []):
			if row.size() == 2 and String(row[0]) == label:
				return String(row[1])
	return ""


# --- seudolocalización -----------------------------------------------------------------------

func _test_pseudo() -> void:
	Loc.set_language("en")
	Loc.set_pseudo(true)
	var pseudo := Loc.t("Nueva partida")
	check(pseudo != "New game" and pseudo.begins_with("["), "AC-017-9: la seudolocalización de Godot marca los textos (%s)" % pseudo)
	Loc.set_pseudo(false)
	check(Loc.t("Nueva partida") == "New game", "AC-017-9: se puede apagar")
	Loc.set_language("es")


func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	_delete(LANG_TMP)
	WikiProgress.erase_file()
