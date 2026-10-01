---
name: godot-remappable-controls
description: Agrega a un juego Godot 4 (GDScript) una pantalla de controles remapeables (teclas y botones de mando) sobre el InputMap, con guardado de preferencias. Usalo siempre que el usuario pida "remapear teclas", "cambiar los controles", "pantalla de controles", "rebind", "configurar teclado/mando", "que las teclas se puedan cambiar", o cuando una spec/constitución del juego prometa teclas remapeables y no exista la pantalla; también cuando otra feature (modo de pruebas, atajos de debug) necesite teclas que el jugador pueda cambiar. Nació en Former Walker (spec 015).
---

# Controles remapeables (Godot 4)

El InputMap es la fuente de verdad; una clase estática lo modifica, recuerda los valores de fábrica para restaurarlos y guarda **solo lo que difiere**. Una pantalla de controles (overlay) deja cambiar cada tecla y botón. Hay una implementación completa y testeada en `reference/` (scripts, test y spec de Former Walker); sirve para ver cómo encaja, no para copiar a ciegas: cambiá la lista de acciones y los textos.

## Antes de escribir código
Leé el `project.godot` (`[input]`) y el `CLAUDE.md`/specs del proyecto: qué acciones hay, cuáles tienen ejes de stick o gatillos (no se remapean), cómo se guarda (`user://`), cómo es la pausa (si consulta `Input.is_action_just_pressed(pause)` por sondeo importa para `Esc`), resolución base (la lista tiene que entrar, con scroll). Si el proyecto trabaja con specs, escribí primero la spec 015-style (en `reference/specs/`).

## Reglas de diseño (y por qué)
- **Teclas por posición física** (`physical_keycode`): WASD sigue siendo WASD en un teclado AZERTY o español.
- **Dos teclas + un botón de mando por acción.** Es lo que tienen los juegos reales (principal/alternativa) y mantiene la UI simple; los **ejes del stick/gatillos se conservan** y se muestran como «eje».
- **Conflicto = intercambio**: si la tecla ya la usa otra acción, esa recibe la que esta tenía. Una acción **del juego nunca queda sin ningún control**: si el cambio la dejaría vacía, se rechaza con un mensaje. Las acciones extra (debug, atajos) pueden quedar vacías (`register_extra`).
- **Guardar solo las diferencias** en un JSON versionado; restaurar una acción o todas deja el archivo vacío. Archivo dañado, otra versión, acciones desconocidas o valores que no son números se **ignoran sin errores**: leé con `JSON.new().parse(...)`, no con `JSON.parse_string` (que imprime ERROR en consola).
- **`Esc` cancela la captura; sin captura, cierra la pantalla de forma diferida** (`close.call_deferred()`). Si la pausa consulta Esc por sondeo, vería la pantalla ya cerrada en el mismo cuadro y alternaría la pausa; y la pausa debe ignorar su Esc mientras haya una pantalla encima.
- Modificadores solos (Shift/Ctrl/Alt/Meta) no son una tecla válida; Supr/Retroceso vacía la casilla.

## Piezas
- `ControlBindings` (RefCounted, estático): `actions()`, `label()`, `keys_of()/joy_of()`, `set_key/set_joy` (devuelven `{ok, swapped, reason}`), `clear_key/clear_joy`, `reset/reset_all`, `save`, `ensure_loaded`, `reload_saved`, `register_extra/clear_extra`, `key_text/joy_text/axis_text`. `path` es una variable estática: otros modos (p. ej. de pruebas) la apuntan a su propio archivo.
- `ControlsScreen` (Control armado por código): filas con etiqueta, dos casillas de tecla, una de mando y un botón ↺; fondo **opaco** (con alfa se transparenta el menú de atrás); `ScrollContainer` para listas largas; señal `closed`.
- Se abre desde el menú principal y desde la pausa (un botón «Controles» en cada una). Llamá `ControlBindings.ensure_loaded()` al arrancar el menú y la partida.

## Trampas (cada una costó tiempo)
- **No llames a un método estático `reload()`**: choca con `Script.reload()` y resetea los estáticos (la ruta vuelve al valor por defecto y el test escribe en el archivo real). Usá `reload_saved`.
- En headless, `DisplayServer.keyboard_get_keycode_from_physical` imprime ERROR: protegelo con `DisplayServer.get_name() != "headless"`.
- `Array.slice` sobre un `Array[int]` puede devolver sin tipo: reasignalo con `assign` a una variable tipada.
- Un lambda captura por valor: para un flag que el lambda deba cambiar, usá un array de un elemento.
- Los tests deben apuntar `path` a un archivo temporal de `user://` y borrarlo; si un test falla a mitad puede escribir en el archivo real. Revisá `user://` al terminar.
- Al sumar el botón al menú o la pausa, actualizá los tests que cuentan botones.

## Verificación
Tests headless (ver `reference/tests/controls.gd`): valores de fábrica, cambio inmediato, ejes conservados, solo diferencias guardadas, intercambio y rechazo, restaurar, persistencia (guardar → restaurar → recargar), archivos inválidos, captura con eventos simulados (`screen._input(event)`), Esc, y que menú y pausa la abran. Además **mirá la pantalla de verdad**: corré Godot con ventana (`--path . -s script.gd --resolution 1280x720`, sin `--headless`), armala en un script temporal y guardá `get_viewport().get_texture().get_image().save_png(...)`; así se ven solapamientos y transparencias que los tests no ven. Cerrá con la suite general del proyecto en verde y un commit solo con lo propio.

## Relacionadas
`godot-test-mode` usa esta pantalla para los atajos de pruebas; `godot-wiki` muestra una entrada «Controles» leída del InputMap.
