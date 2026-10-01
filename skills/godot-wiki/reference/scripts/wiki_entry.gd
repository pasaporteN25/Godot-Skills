class_name WikiEntry
extends RefCounted
## Una entrada de la wiki (spec 016): un enemigo, un jefe, un patrono, un artículo… La pantalla no sabe de qué
## es: solo dibuja su título, su dibujo y sus bloques. Es puro dato, así se prueba sin ventanas.
##
## Un bloque es un diccionario con la clave "tipo":
##   {"tipo": "titulo", "texto": "…"}                      un subtítulo
##   {"tipo": "texto", "texto": "…"}                       un párrafo
##   {"tipo": "datos", "filas": [["Vida", "40"], …]}       pares nombre / valor
##   {"tipo": "tabla", "filas": [["Etapa", "Tipo"], …]}    la primera fila es el encabezado

const KIND_HEADING := "titulo"
const KIND_TEXT := "texto"
const KIND_FACTS := "datos"
const KIND_TABLE := "tabla"

var id: StringName = &""
var title: String = ""
var subtitle: String = ""
## Dibujo de la entrada (vacío = sin dibujo). Se muestra con escala entera y filtro nearest.
var icon: Texture2D
var blocks: Array[Dictionary] = []
## Entrada cerrada del bestiario: todavía no se descubrió. No lleva ningún dato real, solo el aviso; el
## dibujo se ve en silueta.
var locked: bool = false


func add_heading(text: String) -> WikiEntry:
	blocks.append({"tipo": KIND_HEADING, "texto": text})
	return self


func add_text(text: String) -> WikiEntry:
	blocks.append({"tipo": KIND_TEXT, "texto": text})
	return self


func add_facts(rows: Array) -> WikiEntry:
	blocks.append({"tipo": KIND_FACTS, "filas": rows})
	return self


func add_table(rows: Array) -> WikiEntry:
	blocks.append({"tipo": KIND_TABLE, "filas": rows})
	return self


## Todo el texto de la entrada junto (para los tests y para un buscador futuro).
func plain_text() -> String:
	var parts: PackedStringArray = [title, subtitle]
	for block: Dictionary in blocks:
		if block.has("texto"):
			parts.append(String(block["texto"]))
		for row: Variant in block.get("filas", []):
			parts.append(" ".join(PackedStringArray(row)))
	return "\n".join(parts)
