# Referencia: Humanity Booster (RTS 3D, Godot 4.7)

Procedencia: implementación de HB-081 (rama `feature/cdx-modo-pruebas`, publicada en `master` el 24/11/2026). **No es genérica**: es un ejemplo de cómo quedó en ese juego.

## Piezas
- `src/defs/code_def.gd`: `CodeDef extends GameDef` con `code` y `effect`. Se carga sola desde `data/codes/`.
- `data/codes/test_mode_code.tres`: `PRUEBAS` → efecto `enable_test_mode`.
- `src/core/codes.gd` (`Codes`): `normalize`, `apply` (enum `APPLIED/ALREADY_ACTIVE/UNKNOWN/SAVE_FAILED`), `has_effect`, `reset_memory`, persistencia en `user://codes.json` por id con escritura atómica.
- `src/ui/options_screen.gd`: pantalla de Opciones con el campo, «Aplicar» y los controles; la abren el menú principal y la pausa.
- `TestMode.enabled()` consulta `Codes.has_effect("enable_test_mode")` además del argumento `--pruebas` y de la feature del preset de exportación.
- `ContentValidator`: código único tras normalizar y efecto dentro de `Codes.EFFECTS`; `CodeDef` queda fuera de la enciclopedia (`is_playable`).
- `docs/CODIGOS.md`: la tabla pública de códigos y cómo agregar uno.
- `tests/codes_test.gd`, con el archivo de activaciones redirigido a un temporal desde `tests/runner.gd`.

## Lo que no es genérico
- El proyecto manda toda acción por `Game.execute`; ese es el camino que usa el código para efectos de estado.
- La lista de códigos es pública a propósito (decisión del autor del juego).
- Textos de interfaz en español, con clave de traducción.
