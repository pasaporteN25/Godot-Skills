# Implementación de referencia (Former Walker, 2026-10-01)

Copia de los archivos reales tal como quedaron en el proyecto de origen. Es una foto: si el proyecto cambió, mirá su
repositorio. Nada de esto corre por sí solo fuera de Former Walker.

- `scripts/control_bindings.gd` (scripts/game): lógica estática sobre el InputMap. **Casi genérico**: cambiar `GAME_ACTIONS`, `LABELS` y `JOY_NAMES`.
- `scripts/controls_screen.gd` (scripts/ui): pantalla de controles, armada por código. Usa `MenuSkin` del juego para los botones (reemplazar por el estilo del proyecto).
- `tests/controls.gd`: test headless (30 controles) con un archivo temporal en `user://`.
- `specs/015-remappable-controls.md`: spec con criterios de aceptación.

Cambios en el juego de origen: botón «Controles» en el menú principal y en la pausa (la pausa ignora Esc mientras la pantalla
está abierta) y `ControlBindings.ensure_loaded()` al arrancar el menú y la partida.
