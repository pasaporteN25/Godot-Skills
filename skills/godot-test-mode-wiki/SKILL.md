---
name: godot-test-mode-wiki
description: Agrega a un juego Godot 4 (GDScript) un modo de pruebas/admin (saltar a niveles, jefes o salas, invulnerabilidad, matar enemigos, velocidad, cajas de colisión, estadísticas por nivel), una wiki/bestiario dentro del juego alimentada por los datos (Resources) y una pantalla de controles remapeables. Usalo siempre que el usuario pida "modo admin", "modo debug", "modo de pruebas", "cheats", "poder probar niveles/escenarios sin jugarlos ni morir", "wiki", "bestiario", "enciclopedia", "codex", "remapear teclas/controles" o "panel de debug" en un juego Godot, aunque no nombre esos términos exactos; también para portar este patrón de un proyecto a otro (ya existe en Former Walker y en TDv1/JuegoA).
---

# Modo de pruebas + wiki + controles remapeables (Godot 4)

Patrón probado en dos juegos (Former Walker, un plataformas de acción, y TDv1/JuegoA, un tower defense). Resuelve tres necesidades que aparecen juntas: **probar contenido sin jugarlo entero**, **documentar el contenido dentro del juego sin que se desactualice**, y **que las teclas (también las de pruebas) se puedan cambiar**.

Hay una implementación completa y testeada en `reference/` (scripts, tests y specs de Former Walker). No la copies a ciegas: sirve para ver *cómo* encajan las piezas; las partes que dependen del juego (`TestActions`, `TestPanel`, `Wiki`) se reescriben leyendo el proyecto nuevo. Las partes genéricas (`ControlBindings`, `ControlsScreen`, `WikiEntry`, `WikiCategory`, `WikiProgress`, `TestMode`, `TestStats`, `TestOverlay`) se pueden adaptar con pocos cambios.

## Antes de escribir código

1. **Leé el proyecto** (su `CLAUDE.md`, constitución/specs si es SDD): cómo se guarda (`SaveGame`), qué autoloads hay, cómo se encadenan menú → partida → niveles, dónde viven los datos (Resources `.tres` por enemigo/jefe/arma…), qué acciones hay en el `InputMap`, resolución base (para que el panel entre) y cómo se corren los tests headless. Si el proyecto trabaja con specs y tareas, **escribí primero la spec y las tareas** y recién después implementá; en Former Walker se hizo así (specs 014, 015 y 016 en `reference/specs/`).
2. **Preguntá lo que cambia el diseño**, con una recomendación en cada pregunta: ¿se entrega el ejecutable de pruebas a otras personas? ¿qué se quiere poder hacer (lista de acciones)? ¿hay remapeo de teclas ya? ¿qué categorías tiene la wiki? Si el usuario ya contestó en la conversación, no repreguntes.
3. **Identificá el "estado interno" que las acciones necesitan tocar** (cambiar de sala, vencer enemigos, fases de jefe). Preferí exponer 3–5 métodos públicos chicos en el núcleo (`go_to_room`, `skip_wave`, `unlock_exits`, `complete_now`) antes que llamar a privados desde afuera.

## Principios de diseño (y por qué)

- **Sin contraseña ni combinación secreta.** En un juego de un jugador el guardado es un archivo editable: una clave no protege nada. Lo que importa es que el jugador normal **no vea** las herramientas y que las pruebas **no ensucien** su progreso. Por eso: la feature `pruebas` (preset de exportación aparte con `custom_features="pruebas"`, `runnable=false`) o el argumento `--pruebas`; guardado, controles y estadísticas **en archivos propios**; cartel fijo «MODO PRUEBAS».
- **Un autoload inerte.** `TestTools` existe en el build normal pero no crea nada si `TestMode.enabled()` es falso. Así no hay que excluir scripts del export (excluirlos rompe el autoload).
- **Toda acción es una función estática testeable** (`TestActions`), sin interfaz. El panel y los atajos solo la llaman: así se prueba en headless y se reutiliza.
- **Los números salen de los datos.** La wiki lee los Resources; los textos escritos a mano (notas, consejos, artículos) no repiten números que viven en un dato.
- **Una entrada cerrada de la wiki no lleva ningún dato real** (ni el nombre): así un error de la pantalla no puede filtrar spoilers, y se prueba (sin dígitos ni nombres en su texto).

## Piezas, en el orden en que conviene hacerlas

### 1. `ControlBindings` + `ControlsScreen` (si el juego no tiene remapeo)
El InputMap es la fuente de verdad; la clase lo modifica, guarda solo lo que difiere de fábrica y restaura. Reglas que valen la pena: teclas por **posición física**; dos teclas + un botón de mando por acción; **conflicto = intercambio**, y una acción del juego nunca queda sin control; ejes del stick se conservan; archivo dañado/otra versión se ignora sin errores (usá `JSON.new().parse`, no `JSON.parse_string`, que imprime ERROR en consola); `Esc` cancela la captura y cierra la pantalla **de forma diferida** (si la pausa consulta Esc por sondeo, no debe verlo ya cerrado en el mismo cuadro). Las acciones extra del modo de pruebas se agregan con `register_extra` como opcionales (pueden quedar vacías). Ver `reference/scripts/control_bindings.gd` y `controls_screen.gd`.

### 2. `TestMode` + `TestTools` (autoload) + `TestActions`
- `TestMode.enabled()`: `OS.has_feature("pruebas")` o argumento; `force` (−1/0/1) para tests automáticos; `activate()` redirige `SaveGame.path` y `ControlBindings.path` y registra los atajos `test_*` (F1–F4 y dígitos: el juego normal no los usa; un test comprueba que no choquen).
- `TestTools`: cartel, panel, atajos (`_unhandled_input` con `is_action_pressed`), banderas (invulnerable, congelar, overlay, FPS), estadísticas por etapa (detecta el cambio de etapa **sondeando** el nodo actual cada cuadro: más robusto que cablear señales), reposición de `Engine.time_scale` al volver al menú.
- Acciones típicas: saltar a arco/etapa/sala/jefe con equipo inicial; teletransportar a cualquier sala; matar a todos **sin botín y descartando las oleadas pendientes** (si no, la siguiente oleada reaparece); abrir salidas/atajos; hacer aparecer enemigos (congelados o no); jefes: siguiente fase / 1 de vida / congelar; curar, plata, filo, subir de nivel gratis; velocidades ×0,25…×4.
- **Invulnerable** = sigue emitiendo daño y reacción pero no resta vida (un flag en el jugador, 3 líneas): las estadísticas cuentan el daño que *habría* recibido.
- En el menú principal, «Saltar a…» deja los datos en un estático (`Launch.test_jump`) y el juego los aplica en un gancho de `_ready`: no hay que tocar el flujo normal.

### 3. Panel de pruebas
`CanvasLayer` con `TabContainer` (Jugador / Mapa / Enemigos / Jefes / Mundo / Stats), fuentes chicas, botones con `focus_mode = FOCUS_NONE` (el teclado sigue siendo del juego). Lecciones: los `CheckBox` sin ícono no muestran su estado → usá botones `toggle_mode` con texto «…: SÍ/no»; poné el cartel arriba a la derecha y el panel debajo para que no se pisen; las pantallas a pantalla completa con fondo **opaco** (con alfa se transparenta el menú de atrás).

### 4. `TestOverlay` (cajas de golpe y de daño)
Nodo `top_level` que recorre el árbol de la etapa cada cuadro y dibuja los `CollisionShape2D` rectangulares con color por tipo (enemigo, contacto, jugador, tajo, peligros). Overlay propio y no `debug_collisions_hint`: funciona en cualquier build y se puede colorear.

### 5. Wiki
- Modelo: `WikiEntry` (título, subtítulo, ícono, `locked`, bloques `titulo/texto/datos/tabla`), `WikiCategory`, `Wiki` (un proveedor por categoría que **lee los Resources**), `WikiProgress` (qué se descubrió; archivo **aparte** de la partida para que sobreviva a «Nueva partida»; en memoria si el guardado está apagado; todo abierto en modo de pruebas), `WikiScreen` genérica.
- Descubrimiento: **un gancho por tipo** donde el juego ya crea la cosa (`Enemy._ready`, jefe `_setup`, equipar patrono/arma, entrar a etapa).
- «Dónde aparece»: recorrer las escenas de las salas es lento → un **índice generado** (`tools/build_wiki_index.gd` → JSON versionado) y un **test que falla si quedó viejo** (`to_json(build()) == archivo`).
- Retratos: primer cuadro de la animación `idle`, **recortado a su rect usado** (`Image.get_used_rect`) y en silueta (modulate negro sobre un marco claro) si está cerrado. Escala entera, filtro nearest.
- Texto a mano en `notes.json` (por clase e id: `texto`, `consejo`, `tambien_en`) y artículos `articles/*.json` con `orden`. Una entrada «Controles» leída del InputMap refleja los remapeos. Evitá spoilers en lo abierto por defecto.

### 6. Tests y verificación visual
- Tests headless que cubren cada criterio de aceptación (ver `reference/tests/`): apagado = nada; guardado aparte (comparar el archivo real antes/después); saltos a todos los arcos; teletransporte; matar a todos sin monedas; invulnerabilidad; jefes; estadísticas; cartel/overlay; wiki cerrada/abierta/progreso/índice; remapeo con archivos temporales.
- **Mirá la interfaz de verdad**: corré Godot **con ventana** (`--path . -s script.gd --resolution 1280x720`, sin `--headless`), armá las pantallas en un script temporal y guardá `get_viewport().get_texture().get_image().save_png(...)`; después abrí las PNG. Así se vieron los problemas de solapamiento, transparencia y casillas invisibles que los tests no ven. Borrá el script temporal.
- Si el proyecto tiene preset de exportación, exportá el de pruebas (`--headless --export-release "Windows (pruebas)" build/…exe`) y arrancalo unos segundos para ver que carga.

## Trampas conocidas (cada una costó tiempo)

- `ControlBindings.reload()` **no funciona**: choca con `Script.reload()` y resetea los estáticos. Llamalo `reload_saved`.
- Un autoload no puede llamarse igual que un `class_name`: poné el script del autoload sin `class_name`.
- En headless, `DisplayServer.keyboard_get_keycode_from_physical` imprime ERROR: protegelo con `DisplayServer.get_name() != "headless"`.
- Los tests deben apuntar `path` de cada archivo (guardado, controles, wiki, estadísticas) a `user://` temporales y borrarlos; un test que falla a mitad puede escribir en el archivo real (pasó con los controles). Verificá `user://` al terminar.
- `Array.slice` sobre un array tipado puede devolver sin tipo: reasignalo con `assign` a una variable `Array[int]`.
- Un lambda captura variables por valor: para un flag que el lambda cambie, usá un array de un elemento.
- Si el juego tiene oleadas/arenas, «matar a todos» tiene que vaciar las oleadas pendientes y registrar esos puntos como derrotados.
- Al sumar un botón al menú principal o a la pausa, actualizá los tests que cuentan botones.

## Cierre

Antes de dar algo por hecho: tests nuevos en verde **y** la suite general del proyecto en verde (corre minutos; ponela en segundo plano), capturas revisadas, documentación actualizada (spec, tareas, backlog) y un commit que incluya solo lo propio (en proyectos con otro agente produciendo arte, dejá sus archivos sin tocar). Si algún criterio de aceptación de la spec cambió al implementar, actualizá la spec y decilo.
