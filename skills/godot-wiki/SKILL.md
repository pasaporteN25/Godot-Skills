---
name: godot-wiki
description: Agrega a un juego Godot 4 (GDScript) una wiki/bestiario/enciclopedia dentro del juego que se arma leyendo los datos (Resources) y por eso nunca se desactualiza: enemigos, jefes, armas, patronos o lugares con sus números reales, entradas cerradas hasta descubrirlas, índice "dónde aparece" y artículos de guía. Usalo siempre que el usuario pida "wiki", "bestiario", "enciclopedia", "codex", "glosario del juego", "pantalla con los enemigos y sus datos", "que el juego explique sus reglas" o "documentación dentro del juego" en un juego Godot, aunque no use esos términos. Nació en Former Walker (spec 016), con el patrón tomado de TDv1/JuegoA.
---

# Wiki / bestiario dentro del juego (Godot 4)

La pantalla es **genérica**: dibuja categorías → entradas → bloques y no sabe qué es un enemigo. Lo que sabe de enemigos, jefes, armas, etc. está en una clase `Wiki` que arma las entradas **leyendo los Resources**: sumar un `.tres` lo agrega solo, y los números (vida, armadura, daño, fases…) salen de los datos, así que no hay una segunda copia que se desincronice. Hay una implementación completa y testeada en `reference/` (scripts, test, spec y datos de Former Walker). No la copies a ciegas: `Wiki` (los proveedores por categoría) se reescribe leyendo el proyecto nuevo; el modelo, el progreso, el índice y la pantalla se adaptan con pocos cambios.

## Antes de escribir código
1. **Leé el proyecto** (su `CLAUDE.md`, specs): qué tipos de contenido hay y cómo se definen (`EnemyDefinition`, `BossDefinition`…), dónde viven los `.tres`, cómo se descubre cada cosa en el juego (dónde nace un enemigo, un jefe, un arma equipada…), cómo se guarda y qué resolución base tiene (la pantalla debe entrar). Si trabaja con specs y tareas, **escribí primero la spec** (`reference/specs/016-wiki.md`) y las tareas.
2. **Preguntá lo que cambia el diseño**, con recomendación: ¿qué categorías? ¿entradas cerradas hasta descubrirlas (bestiario) o todo abierto? ¿el progreso se guarda aparte de la partida? ¿hay spoilers que cuidar? Si ya contestó, no repreguntes.

## Principios de diseño (y por qué)
- **Los datos son la fuente.** Los textos escritos a mano (notas, consejos, artículos) explican reglas y **no repiten números** que ya viven en un Resource.
- **Una entrada cerrada no lleva ningún dato real** (ni el nombre): así un error de la pantalla no puede filtrar spoilers. Muestra «???», un aviso y el dibujo en silueta. Se prueba: el texto de lo cerrado no contiene dígitos ni nombres reales.
- **Progreso aparte de la partida**: lo descubierto sobrevive a «Nueva partida». Se marca con **un gancho por tipo** donde el juego ya crea la cosa (`Enemy._ready`, jefe `_setup`, equipar patrono/arma, entrar a etapa). En memoria siempre; al disco solo si el guardado está habilitado (los tests lo apagan). En modo de pruebas todo abierto.
- **Cada categoría es una función** que devuelve entradas más una línea en `_providers()`: sumar una categoría no toca la pantalla.

## Piezas
- `WikiEntry` (id, título, subtítulo, ícono, `locked`, bloques `titulo`/`texto`/`datos`/`tabla`, `plain_text()` para tests y un buscador futuro), `WikiCategory` (con contador de abiertas), `Wiki` (proveedores), `WikiProgress` (descubierto, `mark`/`is_seen`/`forget`), `WikiScreen` (pestañas con contador `abiertas/total`, lista a la izquierda, detalle con scroll a la derecha, `Esc` y «Volver» cierran de forma diferida).
- **Enemigos**: dibujo (primer cuadro de `idle`, **recortado a su rect usado** con `Image.get_used_rect`), tipo por arquetipo (una tabla escena → nombre y consejo), datos del Resource, consejos según banderas del dato (coraza, armadura alta, inmunidad…), nota propia y «dónde aparece».
- **Jefes / armas / patronos / lugares**: lo equivalente (fases y vida por fase, frase de entrada, consejo, estadísticas, etapas visitadas).
- **«Dónde aparece»**: recorrer las escenas de las salas es lento → un **índice generado** (`tools/build_wiki_index.gd` → JSON versionado) y un **test que falla si quedó viejo** (`to_json(build()) == archivo`). Si algo no figura en las tablas (p. ej. un enemigo que invoca un jefe), la nota admite `tambien_en`.
- **Guía**: artículos `articles/*.json` con `orden`, más una entrada «Controles» leída del InputMap (refleja los remapeos; ver `godot-remappable-controls`). Evitá spoilers en lo que está abierto por defecto.
- Texto a mano en `notes.json` por clase e id (`texto`, `consejo`, `tambien_en`); formato en `reference/data/`.
- Retratos con escala entera y filtro nearest; en silueta (modulate negro sobre un marco claro, `PanelContainer` con `StyleBoxFlat`) si está cerrado: el negro sobre fondo casi negro no se ve.

## Trampas (cada una costó tiempo)
- `Callable` de un método estático: usá `WikiProgress.is_seen` directamente, no `Callable(Clase, "metodo")`.
- Un test que abra la wiki debe apuntar `WikiProgress.path` a un archivo temporal y borrarlo, y comprobar que con el guardado apagado no escribe.
- Al sumar botones al menú o la pausa, actualizá los tests que los cuentan. La pausa debe ignorar Esc mientras la wiki está abierta.
- Los artículos de la Guía no deben nombrar jefes o lugares posteriores (se filtrarían al abrir la Guía en la primera hora); revisalo con el test «lo cerrado no lleva nombres» ampliado a la Guía si el juego es sensible a spoilers.
- Un lambda captura por valor; el listado de `.tres` en un export aparece como `.tres.remap`: quitá el sufijo `.remap` al listar carpetas.

## Verificación
Tests headless (ver `reference/tests/wiki.gd`): categorías y cantidad de entradas igual a la de archivos de datos; lo cerrado sin nombres ni números; descubrir abre la entrada (y solo esa); los datos coinciden con el Resource y cambian si el Resource cambia; índice al día; progreso persistente, aparte del guardado, tolerante a archivos dañados; modo de pruebas todo abierto; «Controles» refleja un remapeo; **un `.tres` nuevo aparece solo**; la pantalla abre desde el menú y la pausa y cierra con Esc. Además **mirá la pantalla de verdad**: Godot con ventana (`--path . -s script.gd --resolution 1280x720`), un script temporal que marque algunas cosas como vistas y guarde `get_viewport().get_texture().get_image().save_png(...)`. Cerrá con la suite general en verde (segundo plano), docs actualizadas y un commit solo con lo propio.

## Relacionadas
`godot-remappable-controls` (entrada «Controles») y `godot-test-mode` (todo abierto en modo de pruebas).
