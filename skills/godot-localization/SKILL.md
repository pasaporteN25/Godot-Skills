---
name: godot-localization
description: 'Agrega soporte de idiomas (español → inglés y los que vengan) a un juego Godot 4 (GDScript) con el sistema de traducción del motor: el texto fuente es su propia clave, un extractor junta los textos de scripts, Resources, escenas y JSON, un .po por idioma, selector en el menú, preferencia guardada y tests que impiden textos sin traducir. También calcula cuánto cuesta antes de empezar. Usalo siempre que el usuario pida "multilenguaje", "traducir el juego", "inglés", "localización", "i18n", "agregar un idioma", "selector de idioma" o "cuánto cuesta traducirlo" en un juego Godot, aunque no use esos términos.'
---

# Idiomas en un juego Godot 4

El texto del juego queda escrito en su idioma original **y es su propia clave**: se muestra con `tr("…")`, y un `.po` por idioma lo traduce. No hay claves inventadas, el juego sigue legible sin traducciones y sumar un idioma es un archivo más. Hay una implementación completa y probada en `reference/` (Former Walker, español → inglés, 460 textos). Adaptá nombres y rutas; no la copies a ciegas.

## 1. Antes de escribir código: medir el costo
Contá, con `grep`, antes de prometer nada:
- **Literales de interfaz** en scripts (`"…"` con espacios o acentos, fuera de comentarios y rutas) y **cuáles llevan datos** (`"… %s …" % x`: cada uno hay que revisarlo, por el plural, el género y el orden de las palabras).
- Campos de texto de los **Resources** (`display_name`, `description`…), `text` de las **escenas**, **JSON** (wiki, diálogos) y arte con letras dibujadas (no se traduce por código).
- Palabras totales a traducir (en Former Walker: ~1.600 en scripts + ~2.400 de wiki + nombres ≈ 5.000; 460 textos únicos).

Estimación de trabajo (Former Walker, una sola persona + agente): infraestructura = chico; envolver textos y revisar formatos = lo más largo; datos y wiki (que arma frases por código) = mediano; traducir = minutos; **tests = mediano y es lo que más se subestima**. Qué decidir con el usuario (con recomendación):
1. **Nombres propios**: ¿se traducen? Recomendá no traducir personajes, dioses y lugares míticos; los lugares reales con nombre inglés estándar (Greece, Athens) sí. Dejalo por escrito en la spec y en un test.
2. **Alcance**: ¿el modo de pruebas / debug se traduce? Recomendá que no.
3. **Quién revisa**: el agente traduce, se aplica de inmediato y la persona revisa jugando.
Si el proyecto trabaja con specs y tareas, **escribí primero la spec** (`reference/specs/017-localization.md`) y las tareas.

## 2. Diseño (y por qué)
- **El idioma fuente es la clave.** Ventaja: nada que mantener aparte. Costo: corregir una errata en el original deja sin traducción al texto viejo → el test del catálogo lo detecta.
- **`tr()` en un Node, `Loc.t()` donde no hay instancia** (funciones `static`, `RefCounted`): `tr` no existe ahí. `Loc.t` llama a `TranslationServer.translate`.
- **Constantes de texto** (`const LINE_X := "…"`, tablas): una línea `# i18n` encima marca las sentencias hasta la primera línea en blanco; se muestran con `tr(CONSTANTE)`. Las claves de diccionario y los `&"StringName"` no se extraen.
- **Datos**: los Resources, las escenas y los JSON siguen en el idioma original; quien los muestra hace `tr(dato)`. El extractor sabe qué campos mirar (`TEXT_FIELDS`).
- **Nunca partas una frase** ni la pegues con `+`: el orden de las palabras cambia entre idiomas. `tr("Nivel %d: hacen falta %d") % [a, b]`, no `tr("Nivel") + " " + …`. Un texto con un salto de línea real adentro no se extrae: usá `"\n"`.
- **Los textos se evalúan al construir**: al cambiar de idioma hay que reconstruir la pantalla (el menú principal lo hace; las pantallas ya abiertas no).
- **Comparar texto mostrado con constantes** (`_dialogue.text in [LINE_A]`) debe comparar contra la versión traducida.
- **Qué idioma arranca**: `--lang=xx` > preferencia guardada > idioma del sistema si existe > original. **Un script suelto (`-s`) arranca siempre en el original** (salvo `--lang`): sin eso, los tests dependen del idioma de la computadora (CI en Linux = inglés) y de la preferencia de quien juega. Lo hace un autoload mínimo (`Localization`) que llama a `Loc.ensure_loaded()`.
- **Las preferencias** van en un JSON versionado (`user://language.json`); archivo dañado, de otra versión o con un idioma desconocido se ignora (`JSON.new().parse`, no `parse_string`). Con el guardado apagado (tests) no se escribe.

## 3. Piezas (`reference/`)
- `scripts/loc.gd` (`Loc`): `LANGUAGES`, `current()`, `set_language()`, `next_code()`, `t()`, `set_pseudo()`, idioma de arranque. **Casi genérico**: cambiar `SOURCE` y `LANGUAGES`.
- `scripts/localization.gd`: el autoload (sin `class_name`).
- `scripts/translation_catalog.gd`: extractor (scripts, `.tres`, `.tscn`, JSON de la wiki), lectura/escritura de `.po` y `placeholders()`. Cambiar `SCRIPT_DIRS`, `SKIP_DIRS`, `DATA_DIRS`, `TEXT_FIELDS` y las rutas de la wiki.
- `tools/build_translations.gd`: regenera `es.pot` y agrega al `en.po` los textos nuevos con la traducción vacía (y quita los que ya no existen). `-- --check` falla si algo está desactualizado o vacío (sirve en CI).
- `tests/i18n.gd`: arranque en el original, catálogo al día, nada vacío, mismos `%s/%d`, nombres propios intactos, selector, persistencia, pantallas en inglés, wiki cerrada sin spoilers en inglés, seudolocalización.
- `tools/capture_i18n.gd`: capturas del menú, la pausa, los controles, la wiki y una etapa con el render real, en cualquier idioma o con `--pseudo`.
- Config: en `project.godot` el autoload y `[internationalization]` con `locale/fallback` y `locale/translations=PackedStringArray("res://translations/en.po")`.

## 4. Cómo se traduce
1. Envolvé los textos (`tr`/`Loc.t`, `# i18n`), corré `tools/build_translations.gd`.
2. Traducí los vacíos de `en.po`. **Trabajo en lote sin retipear los originales**: generá una lista numerada (`N<TAB>texto`), traducí por número y aplicala con un script que busque cada `msgid` por su número. Evitá comillas dobles en la traducción (usá “ ”).
3. Glosario fijo desde el principio (en Former Walker: plata→silver, filo→edge, empañada→tarnished, pulir→polish, Yunque→Anvil). Mantené los marcadores `%s`/`%d` y su orden; el test lo comprueba.
4. Volvé a correr la herramienta con `--check` y los tests.

## 5. Trampas (cada una costó tiempo)
- **`tr()` en funciones estáticas no compila**: usá `Loc.t`.
- **Los tests y las herramientas con `-s` salen en el idioma del sistema** si no los forzás: el CI se rompe o, peor, pasa solo en tu máquina.
- **`Label.text`/`Button.text` se traducen solos al dibujar**, pero leer `.text` devuelve el texto que asignaste: asigná ya traducido y los tests leen inglés. Un texto formateado (`%`) **no** se traduce solo: `tr("… %d") % n`.
- **Region del idioma**: Godot resuelve `es_MX`→`es` y `en_US`→`en`; no hace falta un `.po` por región.
- Al sumar un botón al menú actualizá los tests que los cuentan (el selector de idioma suma uno).
- Un texto que sale de armar partes (`"%s · %s"`) tiene que traducir cada parte antes de unirla.
- Las pantallas de ancho fijo: el inglés suele ser más corto, pero **otros idiomas no**. Revisá con la seudolocalización de Godot (`TranslationServer.pseudolocalization_enabled = true`): agrega acentos y corchetes, así se ve lo que quedó sin `tr` y lo que se corta.
- Casillas con `clip_text`: «Gamepad: D-pad ← + axis» se cortaba donde «Mando: … + eje» entraba.
- El `.po` se importa a `.godot/`: en CI correr `--import` antes de los tests (y en una copia limpia, comprobar que el inglés carga).
- Modo de pruebas / mensajes de validación de datos / nombres de salas internos: no se traducen; decilo en la spec para que no parezcan olvidos.

## 6. Verificación
Corré el test de idiomas y la suite completa (`godot-headless-tests`) en el idioma original, y **mirá las pantallas de verdad** en el idioma nuevo y con `--pseudo` (`tools/capture_i18n.gd`, ventana real, `--resolution 1280x720`). Cerrá con docs (spec, tareas, CHANGELOG, la guía del agente: «los textos nuevos van con `tr`, corré el extractor») y un commit solo con lo propio.

## Relacionadas
`godot-headless-tests` (la suite fuerza el idioma original y corre `i18n.gd`), `godot-wiki` (la wiki arma frases por código: pasarlas por `Loc.t`, incluidos los datos de las tablas), `godot-remappable-controls` (los nombres de los botones del mando y las acciones se traducen) y `godot-test-mode` (queda sin traducir a propósito).
