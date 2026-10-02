# Implementación de referencia (Former Walker, 2026-10-01)

Copia de los archivos reales tal como quedaron en el proyecto de origen (`pasaporteN25/formerWalker`, spec 017, commit `1abcf43`). Es una
foto: si el proyecto cambió, mirá su repositorio. Nada de esto corre por sí solo fuera de Former Walker.

## Casi genéricos (cambiar nombres, rutas y la lista de idiomas)
- `scripts/loc.gd`: idioma de arranque, selector, preferencia, `t()` y seudolocalización. Cambiar `SOURCE` y `LANGUAGES`.
- `scripts/localization.gd`: autoload que aplica el idioma al arrancar.
- `scripts/translation_catalog.gd`: extractor de textos y lectura/escritura de `.po`. Cambiar `SCRIPT_DIRS`, `DATA_DIRS`,
  `TEXT_FIELDS` y las rutas de la wiki.
- `tools/build_translations.gd`: regenera `es.pot` y sincroniza cada `.po` (`-- --check` para CI).

## Específicos del juego (reescribir leyendo el proyecto nuevo)
- `tests/i18n.gd`: usa `MainMenu`, `PauseMenu`, `EndingScreen`, `Wiki` y las rutas de Former Walker; la estructura (arranque,
  catálogo, traducciones, nombres propios, selector, persistencia, pantallas) se mantiene. `PROPER_NOUNS` es de este juego.
- `tools/capture_i18n.gd`: capturas con el render real de las pantallas de Former Walker.
- `specs/017-localization.md`: spec con las decisiones del usuario y los criterios de aceptación.
- `translations/en.po.example`: el comienzo del `.po` (cabecera y primeros textos) para ver el formato.

## Cambios que hizo en el juego de origen
Autoload `Localization` y `[internationalization]` en `project.godot`; `tr()`/`Loc.t()` en menús, pausa, controles, final, HUD,
Umbral, jefes, eventos y wiki; botón «Idioma» en el menú principal; tests que cuentan botones (+1); `CLAUDE.md` con la regla
«textos nuevos por `tr`, correr el extractor».
