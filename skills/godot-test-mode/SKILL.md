---
name: godot-test-mode
description: 'Agrega a un juego Godot 4 (GDScript) un modo de pruebas/admin para probar niveles y escenarios sin jugarlos ni morir: saltar a cualquier etapa, sala, oleada o jefe con equipo inicial, invulnerabilidad, matar enemigos, abrir salidas, fases de jefe, velocidad del juego, cajas de golpe y daño, y estadísticas por nivel, en un ejecutable/feature aparte con guardado propio. Usalo siempre que el usuario pida "modo admin", "modo debug", "modo de pruebas", "cheats", "panel de debug", "poder probar sin jugar todo", "saltar a un nivel/jefe/oleada", "god mode", "no tener que morir para testear" o "afinar la dificultad probando jefes" en un juego Godot, aunque no use esos términos.'
---

# Modo de pruebas / admin (Godot 4)

Resuelve un problema concreto: revisar un jefe, una sala del tercer arco o un patrón de daño exige hoy jugar todo lo anterior y a veces morir a propósito. Hay una implementación completa y testeada en `reference/` (scripts, test y spec de Former Walker, un plataformas); TDv1/JuegoA (tower defense) tiene una versión más chica del mismo diseño (D-028). No la copies a ciegas: las partes que dependen del juego (`TestActions`, `TestPanel`, `JumpScreen`) se reescriben leyendo el proyecto nuevo; las genéricas (`TestMode`, `TestStats`, `TestOverlay`, el esqueleto de `TestTools`) se adaptan con pocos cambios.

## Antes de escribir código
1. **Leé el proyecto** (su `CLAUDE.md`, constitución/specs si es SDD): cómo se guarda (`SaveGame`), qué autoloads hay, cómo se encadenan menú → partida → niveles, dónde viven los datos (Resources por enemigo/jefe/arma), qué acciones hay en el InputMap y la resolución base (para que el panel entre). Si trabaja con specs y tareas, **escribí primero la spec y las tareas** (ver `reference/specs/014-test-mode.md`).
2. **Preguntá lo que cambia el diseño**, con recomendación en cada pregunta: ¿se entrega el ejecutable de pruebas a otras personas? ¿qué acciones se quieren? ¿hay remapeo de teclas (si no, ver `godot-remappable-controls`)? ¿cajas de colisión con overlay propio o con el de Godot? Si ya contestó, no repreguntes.
3. **Identificá el estado interno que las acciones deben tocar** (cambiar de sala, vencer enemigos, fases de jefe) y exponé 3–5 métodos públicos chicos en el núcleo (`go_to_room`, `skip_wave`, `unlock_exits`, `complete_now`, `clear_pending_waves`) en lugar de llamar a privados desde afuera.

## Principios de diseño (y por qué)
- **Sin contraseña ni combinación secreta.** En un juego de un jugador el guardado es un archivo editable: una clave no protege nada. Importa que el jugador normal **no vea** las herramientas y que las pruebas **no ensucien** su progreso. Por eso: la feature `pruebas` (preset de exportación aparte con `custom_features="pruebas"` y `runnable=false`) o el argumento `--pruebas`; guardado, controles y estadísticas **en archivos propios**; cartel fijo «MODO PRUEBAS».
- **Un autoload inerte.** `TestTools` existe en el build normal pero no crea nada si `TestMode.enabled()` es falso. Así no hay que excluir scripts del export (excluirlos rompe el autoload). El script del autoload va **sin `class_name`** (no puede llamarse igual que el autoload).
- **Toda acción es una función estática testeable** (`TestActions`), sin interfaz; panel y atajos solo la llaman.
- **Cambios mínimos al núcleo**: un flag `test_god` en el jugador, esos pocos métodos públicos del runner, un estático de salto (`Launch.test_jump`) y un gancho en `Game._ready`.

## Qué significa cada pieza según el género
La referencia es de un plataformas; traducí las acciones al juego que tenés delante antes de proponerlas:

| Pieza | Plataformas / metroidvania (Former Walker) | Tower defense (TDv1) | Otros |
|---|---|---|---|
| «Saltar a…» | arco → etapa → sala o jefe, con nivel, plata y arma | nivel → **oleada N** con oro y vidas elegidos | roguelike: semilla + piso; carreras: pista + vuelta |
| Invulnerable | el jugador no pierde vida (sí la reacción) | vidas infinitas | lo que haga perder la partida |
| Matar a todos | sin botín, vaciando oleadas pendientes | sin oro (o con, si se prueba la economía) | igual |
| Atajos de flujo | ir a la meta, abrir salidas | ganar / perder ya, saltar oleada | terminar el nivel |
| Velocidad | ×0,25 … ×4 | ×0,25 … ×4 (lento sirve para ver combos y efectos) | igual |
| Overlay | cajas de golpe y daño | alcances de torres y caminos | colisiones del género |
| Estadísticas | daño, desgaste, plata, muertes, tiempo | vidas perdidas, oro, oleada alcanzada | lo que use el balance |

Si el proyecto ya tiene un bot de balance (`tools/balance*.gd`), las estadísticas del modo de pruebas deben medir **lo mismo y con los mismos nombres** que su informe, para poder comparar una partida a mano con la del bot.

## Piezas
- **`TestMode`**: `enabled()` (feature o argumento; `force` −1/0/1 para tests), `activate()` (redirige `SaveGame.path` y el archivo de controles, registra los atajos `test_*`), `deactivate()` para tests. Atajos por defecto en F1–F4 y dígitos (el juego normal no los usa; un test comprueba que no choquen).
- **`TestTools` (autoload)**: cartel arriba a la derecha, panel, atajos (`_unhandled_input` con `is_action_pressed`), banderas (invulnerable, congelar enemigos/jefe, overlay, FPS), estadísticas por etapa detectando el cambio de etapa **sondeando** el nodo actual cada cuadro (más robusto que cablear señales), y reposición de `Engine.time_scale` a ×1 al volver al menú.
- **`TestActions`**: saltar a arco/etapa/sala/jefe con equipo inicial (nivel con sus mejoras, plata, espada, patrono); teletransportar y recorrer salas; matar a todos **sin botín y descartando las oleadas pendientes** (si no, la siguiente oleada reaparece); abrir salidas/atajos; hacer aparecer enemigos; jefes: siguiente fase / 1 de vida / congelar; curar, plata, filo, empañar, subir de nivel gratis; velocidades ×0,25…×4.
- **Invulnerable** = el jugador sigue recibiendo la reacción (empuje, señal `hurt`) pero no pierde vida: las estadísticas cuentan el daño que *habría* recibido.
- **«Saltar a…»** en el menú principal: arco → etapa → sala (o jefe) + equipo; deja los datos en el estático y `Game._ready` los aplica, sin tocar el flujo normal.
- **`TestPanel`**: `CanvasLayer` con `TabContainer` (Jugador / Mapa / Enemigos / Jefes / Mundo / Stats), fuente chica, botones con `focus_mode = FOCUS_NONE` (el teclado sigue siendo del juego). Los `CheckBox` sin ícono no muestran su estado: usá botones `toggle_mode` con texto «…: SÍ/no». El panel va **debajo** del cartel para que no se pisen.
- **`TestOverlay`**: nodo `top_level` que recorre el árbol de la etapa cada cuadro y dibuja los `CollisionShape2D` rectangulares con color por tipo (enemigo, contacto, jugador, tajo, peligros). Overlay propio y no `debug_collisions_hint`: funciona en cualquier build y se puede colorear.
- **`TestStats`**: daño recibido, filo/desgaste, plata ganada, muertes y tiempo por pasada; se vuelcan a un JSON de pruebas para comparar con informes de balance.

## Trampas (cada una costó tiempo)
- Las pantallas a pantalla completa (salto, controles) con fondo **opaco**: con alfa se transparenta el menú.
- Los tests deben apuntar guardado, controles, estadísticas y progreso a archivos temporales de `user://` y borrarlos; verificá `user://` al terminar (un test que falla a mitad puede escribir en el real).
- Si el juego tiene oleadas/arenas, «matar a todos» debe vaciar las pendientes y registrarlas como derrotadas.
- Al sumar botones al menú, actualizá los tests que los cuentan.
- Un lambda captura por valor: para un flag que el lambda cambie, usá un array de un elemento.
- Exportá el preset de pruebas (`--headless --export-release "Windows (pruebas)" build/…exe`) y arrancá el ejecutable unos segundos para ver que carga.

## Verificación
Escribí los tests en el formato que ya usa el proyecto (GUT, gdUnit4 o scripts `extends SceneTree`) y **confirmá que el comando de «hecho» del proyecto los corre**: en Former Walker `test_mode.gd` quedó fuera de `run.gd` y nadie lo ejecutaba al cerrar tareas (ver `godot-headless-tests`). Tests headless (ver `reference/tests/test_mode.gd`): apagado = nada (autoload sin hijos, menú sin «Saltar a…»); guardado aparte (comparar el archivo real antes y después); atajos sin choques; saltos a todos los arcos; teletransporte con cámara; matar a todos sin monedas; invulnerabilidad (contacto y ondas); jefes (fases, 1 de vida); estadísticas; cartel/overlay/congelar; preset de exportación. Además **mirá la interfaz de verdad**: corré Godot con ventana (`--path . -s script.gd --resolution 1280x720`), armá las pantallas en un script temporal y guardá `get_viewport().get_texture().get_image().save_png(...)`. Cerrá con la suite general en verde (corre minutos: segundo plano), docs actualizadas (spec, tareas, backlog) y un commit solo con lo propio.

## Relacionadas
`godot-remappable-controls` (los atajos de pruebas se remapean con esa pantalla), `godot-wiki` (en modo de pruebas la wiki muestra todo abierto) y `godot-headless-tests` (suite completa y CI).
