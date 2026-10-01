# Implementación de referencia (Former Walker, 2026-10-01)

Copia de los archivos reales tal como quedaron en el proyecto de origen. Es una foto: si el proyecto cambió, mirá su
repositorio. Nada de esto corre por sí solo fuera de Former Walker.

## Casi genéricos (adaptar rutas y nombres)
- `scripts/test_mode.gd`: activación (feature `pruebas` o `--pruebas`), rutas propias y atajos. Depende de `SaveGame.path` y de `ControlBindings` (ver la skill `godot-remappable-controls`).
- `scripts/test_stats.gd`, `scripts/test_overlay.gd`: usan `StageRunner`, `Player`, `Enemy` del juego; la lógica se mantiene.
- `scripts/test_tools.gd`: esqueleto del autoload (cartel, atajos, banderas, estadísticas por etapa). Sin `class_name`.

## Específicos del juego (reescribir leyendo el proyecto nuevo)
- `scripts/test_actions.gd`: acciones sobre el núcleo de Former Walker (saltos, salas, enemigos, jefes, Platero).
- `scripts/test_panel.gd`, `scripts/jump_screen.gd`: panel F1 y «Saltar a…».

## Tests y spec
- `tests/test_mode.gd`: test headless (61 controles) con archivos temporales.
- `specs/014-test-mode.md`: spec con criterios de aceptación y las decisiones del usuario.

## Cambios mínimos que hizo en el núcleo del juego
`Player.test_god` (no pierde vida), `StageRunner`: `go_to_room`, `skip_wave`, `unlock_exits`, `clear_pending_waves`,
`complete_now`, `test_no_loot`; `Launch.test_jump`; un gancho en `Game._ready`; un autoload inerte; un preset de exportación
«Windows (pruebas)» con `custom_features="pruebas"` y `runnable=false`.
