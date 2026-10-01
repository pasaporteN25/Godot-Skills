# 014 — Modo de pruebas (admin)

**Estado:** Implementada (2026-10-01; decisiones del usuario abajo) · **Depende de:** 005, 009, 012, 013

## Problema

Para revisar un jefe, una sala del arco III o un patrón de daño hoy hay que jugar todo lo anterior y, a veces, morir a propósito. Eso frena el afinado de dificultad (T-105) y la revisión de arte en sala. Pasa lo mismo con la partida real: cualquier atajo "de desarrollo" que toque el guardado ensucia el progreso.

## Decisión de diseño (heredada de TDv1, D-028)

El modo de pruebas **no se protege con contraseña ni combinación secreta**: es un juego de un jugador cuyo guardado es un archivo editable, así que una clave no protegería nada. Lo que importa es que (1) el jugador normal **no lo vea** y (2) las pruebas **no ensucien** su progreso. Por eso:

- Solo existe cuando la feature `pruebas` está presente: en el preset de exportación **"Windows (pruebas)"** (`custom_features="pruebas"`, ejecutable `FormerWalker_pruebas.exe`) o al jugar desde el editor/consola con el argumento `-- --pruebas`. El ejecutable normal lleva el autoload `TestTools`, pero inerte: sin la feature no crea cartel, panel ni atajos, y el menú no muestra «Saltar a…».
- Usa su **propio guardado** (`user://save_pruebas.json`, `SaveGame.path`). El guardado y las preferencias reales no se tocan.
- Un cartel fijo **MODO PRUEBAS** en una esquina, en el menú y en la partida.

## Qué hace

### En el menú principal
- Botón **"Saltar a…"**: elegir arco → etapa → sala (con su `spawn`) o **jefe/subjefe** directamente. Arranca una sesión nueva con lo previo marcado como completo y desbloqueado.
- **Equipamiento inicial** para esa sesión: nivel de Platero, plata, espada (`SwordDefinition`) y su filo, patrono, corazones extra. Valores por defecto razonables para el arco elegido.
- Se pueden elegir los arcos II y III sin pasar por las puertas del sueño.

### En la partida (tecla `F1`, panel que pausa o no según la opción)
| Grupo | Acciones |
|---|---|
| Platero | invulnerable (sí/no) · curar · plata +100/+1000 · filo al máximo · aturdir/empañar la espada · cambiar de patrono · subir de nivel |
| Navegación | **teletransportar a cualquier sala de la etapa** (lista de `RoomDefinition`) · ir a la meta · abrir todos los atajos · volver al Umbral |
| Enemigos | **matar a todos** (sin botín ni plata) · saltar oleada de arena · desbloquear salidas · hacer aparecer cualquier `EnemyDefinition` junto a Platero (con opción de congelarlo) |
| Jefes | pasar a la siguiente fase · bajar al jefe a 1 HP · congelar su patrón |
| Mundo | velocidad ×0,25 / ×0,5 / ×1 / ×2 / ×4 · mostrar cajas de golpe y de daño (spec 010) · mostrar FPS |

Los efectos de las acciones **no se cuentan** en estadísticas ni en el guardado real: el guardado de pruebas es descartable.

### Fuera de alcance
- Editor de niveles y wiki (propuestas B-6, specs aparte).
- Tramposo "en línea" o protección contra edición del guardado.
- Sustituir los tests headless: el modo de pruebas es para personas.

## Cómo se construye (sin tocar el núcleo)

- `TestMode` (`RefCounted`, estático): `enabled()` = `OS.has_feature("pruebas") or "--pruebas" in OS.get_cmdline_user_args()`. Al arrancar apunta `SaveGame.path` a `save_pruebas.json`. Todo lo demás consulta `TestMode.enabled()`; el panel y el botón ni se instancian si es false.
- `Game.enter_stage_at(arc_index, stage_index, room_id, spawn_id)` y un helper de sesión que marca etapas previas como completas: son los únicos cambios en el núcleo; reutilizan `StageRunner._enter_room`.
- `TestPanel` (escena de UI en `scenes/ui/`) hecho con `Control` estándar; cada acción es una función pequeña sobre `Game`, `StageRunner`, `Player` y `Enemy` ya existentes. Las listas (arcos, etapas, salas, enemigos, espadas, patronos) salen de los **Resources** por datos: contenido nuevo aparece solo.
- Velocidad con `Engine.time_scale`; se restaura al salir del panel, al volver al menú y al cerrar.
- Las acciones de enemigos usan los mismos métodos del juego (`_take_damage`, `defeated` solo para limpiar sala sin botín).

## Criterios de aceptación

- [x] **AC-014-1** Sin la feature `pruebas` ni el argumento, no hay botón, panel, cartel ni atajo `F1`; `TestMode.enabled()` es false.
- [x] **AC-014-2** Con la feature, `SaveGame.path` es `user://save_pruebas.json` y `user://save.json` no cambia aunque se guarde en el Umbral.
- [x] **AC-014-3** "Saltar a…" permite empezar en cualquier etapa de los tres arcos (en una sala elegida o en el jefe) sin completar las anteriores.
- [x] **AC-014-4** El teletransporte lleva a cualquier sala de la etapa activa y respeta cámara, cierres de arena y encuentros de esa sala.
- [x] **AC-014-5** "Matar a todos" despeja la sala sin soltar plata ni contar derrotas para botín; las arenas se abren.
- [x] **AC-014-6** "Invulnerable" evita todo daño (contacto, ondas, esporas, Manecillas) sin impedir la reacción visual; al desactivarlo vuelve el comportamiento normal.
- [x] **AC-014-7** Cada jefe permite pasar de fase y quedar a 1 HP; el flujo posterior (final, Umbral) sigue funcionando.
- [x] **AC-014-8** La velocidad se muestra en el cartel (×N) y vuelve a ×1 al volver al menú. (Cerrar el panel no la cambia: se puede jugar a ×0,5 con el panel cerrado.)
- [x] **AC-014-9** Test headless (`tests/headless/test_mode.gd`) cubre AC-014-1, 2, 3 y 5.
- [x] **AC-014-10** El preset "Windows (pruebas)" exporta un `.exe` distinto con la feature y el preset normal no la incluye.
- [x] **AC-014-11** El panel muestra y vuelca a `pruebas_stats.json` daño recibido, filo gastado, plata ganada, muertes y tiempo por etapa.
- [x] **AC-014-12** Cada acción del panel tiene su acción `test_*` en InputMap con tecla por defecto; un test comprueba que ninguna choca con las acciones del juego.

## Decisiones (2026-10-01, usuario)

1. **Cajas de colisión:** overlay propio que dibuja el `size` de cada `Enemy`, su hurtbox y las cajas de la espada; funciona en cualquier build de pruebas.
2. **Estadísticas por etapa: sí.** Línea con daño recibido, filo gastado, plata ganada, muertes y tiempo, en el panel y volcada a `user://pruebas_stats.json` para comparar con `docs/balance/report.md`.
3. **Atajos de teclado: sí, y remapeables.** Cada acción del panel tiene una acción de InputMap (`test_*`) con tecla por defecto (`F2` matar a todos, `F3` invulnerable, `F4` curar, `F5` teletransporte…). Remapear exige una pantalla de controles que hoy no existe ni para el juego normal (la constitución ya pide teclas remapeables): se hace como **spec 015** para todas las acciones y el modo de pruebas la reutiliza. Hasta entonces, las teclas por defecto quedan fijas.
4. **Distribución:** el ejecutable de pruebas no se entrega a otras personas; no hace falta versión en el cartel ni endurecer el guardado.

## Cómo se usa

- **Desde el editor o la consola:** `Godot_v4.7.2-stable_win64_console.exe --path . -- --pruebas` (o agregar `--pruebas` a los argumentos de ejecución del editor).
- **Ejecutable aparte:** exportar el preset **"Windows (pruebas)"** (`build/FormerWalker_pruebas.exe`, feature `pruebas`). El preset "Windows Desktop" no la lleva.
- **Archivos propios** en `user://`: `save_pruebas.json`, `input_bindings_pruebas.json` y `pruebas_stats.json`.
- **Teclas por defecto** (cambiables en «Controles»): `F1` panel · `F2` matar a todos · `F3` invulnerable · `F4` curar · `1`/`2` velocidad más lenta/rápida · `0` velocidad normal · `3` cajas de golpe · `4` fase siguiente del jefe · `5` jefe a 1 de vida · `6` +1000 de plata · `7`/`8` sala anterior/siguiente · `9` filo al máximo.
- **Código:** `scripts/test/` (`TestMode`, `TestActions`, `TestStats`, `TestOverlay`, `TestPanel`, autoload `TestTools`), `scripts/ui/jump_screen.gd` y las pruebas `tests/headless/test_mode.gd` y `controls.gd`.
