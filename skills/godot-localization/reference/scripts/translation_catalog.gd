class_name TranslationCatalog
extends RefCounted
## Catálogo de textos traducibles (spec 017). Recorre los scripts, los Resources, las escenas y los JSON de la
## wiki, junta los textos en español (que son sus propias claves) y escribe/lee los archivos `.po`.
## Lo usan `tools/build_translations.gd` (regenera `es.pot` y sincroniza `en.po`) y `tests/headless/i18n.gd`.
##
## Qué cuenta como texto traducible:
##  - un literal dentro de `tr("…")` o `Loc.t("…")` en `scripts/` (menos `scripts/test/`: el modo de pruebas no se traduce);
##  - todos los literales de las sentencias que siguen a una línea `# i18n`, hasta la primera línea en blanco
##    (constantes y tablas de texto), salvo los que son claves de diccionario (`"clave": …`) o StringName (`&"…"`);
##  - los campos de texto de los `.tres` y los `.tscn` (`TEXT_FIELDS`);
##  - `texto`, `consejo`, `titulo`, `subtitulo` y las celdas de `filas` de los JSON de la wiki.

const POT_PATH := "res://translations/es.pot"
const SCRIPT_DIRS: Array[String] = ["res://scripts/"]
const SKIP_DIRS: Array[String] = ["res://scripts/test/"]
const DATA_DIRS: Array[String] = ["res://resources/", "res://scenes/"]
const WIKI_NOTES := "res://resources/wiki/notes.json"
const WIKI_ARTICLES := "res://resources/wiki/articles/"
const MARKER := "# i18n"
## Las dos formas de traducir: `tr(…)` en un Node y `Loc.t(…)` donde no hay instancia (funciones estáticas).
const CALLS: Array[String] = ["tr(", "Loc.t("]
## Propiedades de `.tres`/`.tscn` cuyo valor (texto o lista de textos) se traduce.
const TEXT_FIELDS: Array[String] = [
	"display_name", "description", "intro_text", "completion_line", "hades_lines", "ending_pages", "outcome_pages", "ending_hint",
	"text",
]
const WIKI_TEXT_KEYS: Array[String] = ["texto", "consejo", "titulo", "subtitulo"]


## Todos los textos: [{msgid, ref}] sin repetir, en un orden estable (por archivo y posición).
static func extract() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen := {}
	var add := func(msgid: String, ref: String) -> void:
		if msgid.is_empty() or not _has_letter(msgid) or seen.has(msgid):
			return
		seen[msgid] = true
		found.append({"msgid": msgid, "ref": ref})
	for dir in SCRIPT_DIRS:
		for file in _files(dir, ["gd"]):
			for text in script_texts(FileAccess.get_file_as_string(file)):
				add.call(text, file)
	for dir in DATA_DIRS:
		for file in _files(dir, ["tres", "tscn"]):
			for text in resource_texts(FileAccess.get_file_as_string(file)):
				add.call(text, file)
	for text in _wiki_notes_texts():
		add.call(text, WIKI_NOTES)
	for file in _files(WIKI_ARTICLES, ["json"]):
		for text in _wiki_article_texts(file):
			add.call(text, file)
	return found


# --- scripts -------------------------------------------------------------------------------

## Los textos de un script: `tr("…")` y los bloques marcados con `# i18n`.
static func script_texts(source: String) -> Array[String]:
	var texts: Array[String] = []
	var lines := source.split("\n")
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		if line.strip_edges().begins_with("#") and line.strip_edges() != MARKER:
			i += 1
			continue
		if line.strip_edges() == MARKER:
			# Cubre todas las sentencias seguidas hasta la primera línea en blanco.
			i += 1
			while i < lines.size() and lines[i].strip_edges() != "":
				var end := _statement_end(lines, i)
				texts.append_array(_literals("\n".join(lines.slice(i, end + 1)), true))
				i = end + 1
			continue
		var from := 0
		while true:
			var at := _find_tr(line, from)
			if at < 0:
				break
			var parsed := _read_string(line, at)
			if parsed.is_empty():
				break
			texts.append(parsed["value"])
			from = int(parsed["end"])
		i += 1
	return texts


## Índice de la comilla del literal que abre el primer `tr(` o `Loc.t(` desde `from`, o -1.
static func _find_tr(line: String, from: int) -> int:
	var best := -1
	for needle in CALLS:
		var at := from
		while true:
			at = line.find(needle, at)
			if at < 0:
				break
			var before := line[at - 1] if at > 0 else " "
			var rest := at + needle.length()
			while rest < line.length() and line[rest] in [" ", "\t"]:
				rest += 1
			# `tr(` y no `attr(`/`str(`; el argumento tiene que ser un literal.
			if not (before.is_valid_identifier() or before == "_" or before == ".") and rest < line.length() and line[rest] == '"':
				best = rest if best < 0 else mini(best, rest)
				break
			at += needle.length()
	return best


## Última línea de la sentencia que empieza en `start` (los paréntesis y corchetes tienen que cerrarse).
static func _statement_end(lines: PackedStringArray, start: int) -> int:
	var depth := 0
	for i in range(start, lines.size()):
		depth += _bracket_delta(lines[i])
		if depth <= 0:
			return i
	return lines.size() - 1


## Suma de aperturas menos cierres fuera de los literales de una línea.
static func _bracket_delta(line: String) -> int:
	var delta := 0
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "#":
			break
		if c == '"':
			var parsed := _read_string(line, i)
			i = int(parsed["end"]) if not parsed.is_empty() else line.length()
			continue
		if c in ["(", "[", "{"]:
			delta += 1
		elif c in [")", "]", "}"]:
			delta -= 1
		i += 1
	return delta


## Los literales de un trozo de código. Con `skip_keys` se omiten las claves de diccionario y los StringName.
static func _literals(code: String, skip_keys: bool) -> Array[String]:
	var result: Array[String] = []
	var i := 0
	while i < code.length():
		var c := code[i]
		if c == "#":
			i = code.find("\n", i)
			if i < 0:
				break
			continue
		if c != '"':
			i += 1
			continue
		var parsed := _read_string(code, i)
		if parsed.is_empty():
			break
		var end := int(parsed["end"])
		var is_name := i > 0 and code[i - 1] == "&"
		var next := end
		while next < code.length() and code[next] in [" ", "\t"]:
			next += 1
		var is_key := next < code.length() and code[next] == ":"
		if not (skip_keys and (is_name or is_key)):
			result.append(parsed["value"])
		i = end
	return result


# --- datos ---------------------------------------------------------------------------------

## Los textos de un `.tres` o `.tscn`: el valor (o lista de valores) de `TEXT_FIELDS`.
static func resource_texts(source: String) -> Array[String]:
	var texts: Array[String] = []
	var lines := source.split("\n")
	var i := 0
	while i < lines.size():
		var line: String = lines[i]
		var field := _text_field(line)
		if field == "":
			i += 1
			continue
		# El valor puede seguir en las líneas siguientes (textos con saltos de línea): se une hasta cerrar.
		var end := i
		var joined := line
		while not _balanced(joined) and end + 1 < lines.size():
			end += 1
			joined += "\n" + lines[end]
		texts.append_array(_literals(joined.substr(field.length() + 3), true))
		i = end + 1
	return texts


static func _text_field(line: String) -> String:
	for field in TEXT_FIELDS:
		if line.begins_with(field + " = "):
			return field
	return ""


## ¿Están cerradas las comillas y los corchetes de un valor de recurso?
static func _balanced(value: String) -> bool:
	var in_string := false
	var depth := 0
	var i := 0
	while i < value.length():
		var c := value[i]
		if in_string:
			if c == "\\":
				i += 1
			elif c == '"':
				in_string = false
		elif c == '"':
			in_string = true
		elif c in ["(", "[", "{"]:
			depth += 1
		elif c in [")", "]", "}"]:
			depth -= 1
		i += 1
	return not in_string and depth <= 0


static func _wiki_notes_texts() -> Array[String]:
	var texts: Array[String] = []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(WIKI_NOTES)) != OK:
		return texts
	_collect_wiki(json.data, texts)
	return texts


static func _wiki_article_texts(file: String) -> Array[String]:
	var texts: Array[String] = []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file)) == OK:
		_collect_wiki(json.data, texts)
	return texts


## Recorre un JSON de la wiki: los valores de `WIKI_TEXT_KEYS` y las celdas de `filas`.
static func _collect_wiki(node: Variant, texts: Array[String]) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for key: String in node:
			var value: Variant = node[key]
			if key in WIKI_TEXT_KEYS and typeof(value) == TYPE_STRING:
				texts.append(value)
			elif key == "filas" and typeof(value) == TYPE_ARRAY:
				for row: Variant in value:
					for cell: Variant in row:
						if typeof(cell) == TYPE_STRING:
							texts.append(cell)
			else:
				_collect_wiki(value, texts)
	elif typeof(node) == TYPE_ARRAY:
		for item: Variant in node:
			_collect_wiki(item, texts)


# --- archivos .po --------------------------------------------------------------------------

## Lee un `.po`: {msgid: msgstr}. Entiende las líneas de continuación y los escapes; ignora comentarios.
static func read_po(path: String) -> Dictionary:
	var entries := {}
	if not FileAccess.file_exists(path):
		return entries
	var msgid := ""
	var msgstr := ""
	var target := ""
	var have := false
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("msgid "):
			if have and msgid != "":
				entries[msgid] = msgstr
			msgid = _unquote(line.trim_prefix("msgid "))
			msgstr = ""
			target = "id"
			have = true
		elif line.begins_with("msgstr "):
			msgstr = _unquote(line.trim_prefix("msgstr "))
			target = "str"
		elif line.begins_with('"'):
			if target == "id":
				msgid += _unquote(line)
			elif target == "str":
				msgstr += _unquote(line)
	if have and msgid != "":
		entries[msgid] = msgstr
	return entries


## El texto de un `.po`: cabecera y, por cada texto, su archivo de origen, el original y la traducción.
static func write_po(entries: Array[Dictionary], translations: Dictionary, language: String) -> String:
	var out := 'msgid ""\nmsgstr ""\n"Project-Id-Version: Former Walker\\n"\n"Language: %s\\n"\n' % language
	out += '"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n'
	for entry in entries:
		var msgid: String = entry["msgid"]
		out += "\n#: %s\nmsgid %s\nmsgstr %s\n" % [String(entry["ref"]).trim_prefix("res://"), _quote(msgid), _quote(String(translations.get(msgid, "")))]
	return out


## Cuántos marcadores de formato (`%s`, `%d`, `%.1f`, `%%`…) tiene un texto, en orden.
static func placeholders(text: String) -> Array[String]:
	var result: Array[String] = []
	var regex := RegEx.create_from_string("%[-+ #0]*\\d*(?:\\.\\d+)?[sdfxXoeEgGcv%]")
	for m in regex.search_all(text):
		result.append(m.get_string())
	return result


# --- utilidades ----------------------------------------------------------------------------

static func _files(dir: String, extensions: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for skip in SKIP_DIRS:
		if dir.begins_with(skip):
			return result
	var listed := DirAccess.get_files_at(dir)
	listed.sort()
	for file in listed:
		var name := file.trim_suffix(".remap")
		if name.get_extension() in extensions:
			result.append(dir + name)
	var subdirs := DirAccess.get_directories_at(dir)
	subdirs.sort()
	for sub in subdirs:
		if not sub.begins_with("."):
			result.append_array(_files(dir + sub + "/", extensions))
	return result


static func _has_letter(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		# Letras latinas (con acentos): no cuentan los signos como «…», «—» o «×».
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 192 and c <= 591 and c != 215 and c != 247):
			return true
	return false


## Lee el literal que empieza en `text[at]` (una comilla): {value, end} con `end` después de la comilla de cierre.
static func _read_string(text: String, at: int) -> Dictionary:
	var value := ""
	var i := at + 1
	while i < text.length():
		var c := text[i]
		if c == "\\" and i + 1 < text.length():
			var n := text[i + 1]
			value += {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(n, n)
			i += 2
			continue
		if c == '"':
			return {"value": value, "end": i + 1}
		value += c
		i += 1
	return {}


static func _unquote(quoted: String) -> String:
	var parsed := _read_string(quoted.strip_edges(), quoted.strip_edges().find('"'))
	return String(parsed.get("value", ""))


static func _quote(text: String) -> String:
	return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")
