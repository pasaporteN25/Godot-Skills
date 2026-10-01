# Implementación de referencia (Former Walker, 2026-10-01)

Copia de los archivos reales tal como quedaron en el proyecto (rutas originales entre paréntesis). Es una foto: si el
proyecto de origen cambió, mirá su repositorio. Nada de esto corre por sí solo fuera de Former Walker.

## Casi genéricos (adaptar nombres de acciones, textos y rutas)
- `control_bindings.gd` (scripts/game), `controls_screen.gd` (scripts/ui): remapeo. Cambiar `GAME_ACTIONS`/`LABELS`.
- `test_mode.gd`: activación, rutas propias, atajos `SHORTCUTS`. Depende de `SaveGame.path` y `ControlBindings`.
- `test_stats.gd`, `test_overlay.gd`: usan `StageRunner`, `Player`, `Enemy` del juego; la lógica se mantiene.
- `wiki_entry.gd`, `wiki_category.gd`, `wiki_progress.gd`, `wiki_screen.gd`: modelo y pantalla de la wiki.
- `wiki_index.gd` + `build_wiki_index.gd`: índice «dónde aparece»; cambiar el recorrido a la estructura del juego.

## Específicos del juego (reescribir leyendo el proyecto nuevo)
- `test_actions.gd`, `test_tools.gd`, `test_panel.gd`, `jump_screen.gd`: acciones y paneles sobre el núcleo de Former Walker.
- `wiki.gd`: proveedores por categoría (enemigos, jefes, patronos, espadas, lugares, guía).
- `data/notes.json`, `data/article_example.json`: formato de textos a mano.

## Tests y specs
- `tests/`: `test_mode.gd`, `controls.gd`, `wiki.gd` (headless; usan archivos temporales en `user://`).
- `specs/`: 014 modo de pruebas, 015 controles remapeables, 016 wiki, con criterios de aceptación.

## Cambios mínimos que hizo en el núcleo del juego
`Player.test_god` (no pierde vida), `StageRunner`: `go_to_room`, `skip_wave`, `unlock_exits`, `clear_pending_waves`,
`complete_now`, `test_no_loot`; `Launch.test_jump`; un gancho en `Game._ready`; un autoload inerte; y una línea de
`WikiProgress.mark` en cada lugar donde nace una cosa descubrible.
