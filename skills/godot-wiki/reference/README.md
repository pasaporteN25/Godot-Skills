# Implementación de referencia (Former Walker, 2026-10-01)

Copia de los archivos reales tal como quedaron en el proyecto de origen. Es una foto: si el proyecto cambió, mirá su
repositorio. Nada de esto corre por sí solo fuera de Former Walker.

## Casi genéricos (adaptar nombres y textos)
- `scripts/wiki_entry.gd`, `scripts/wiki_category.gd`: modelo de entradas y categorías.
- `scripts/wiki_progress.gd`: qué se descubrió y su archivo. Depende de `SaveGame.enabled` y de `TestMode.enabled()` (modo de pruebas, skill `godot-test-mode`); quitar la segunda dependencia si el juego no lo tiene.
- `scripts/wiki_screen.gd`: pantalla genérica (pestañas, lista, detalle).
- `scripts/wiki_index.gd` + `scripts/build_wiki_index.gd`: índice «dónde aparece»; cambiar el recorrido a la estructura del juego (campaña → etapas → salas → spawners).

## Específicos del juego (reescribir leyendo el proyecto nuevo)
- `scripts/wiki.gd`: proveedores por categoría (enemigos, jefes, patronos, espadas, lugares, guía) sobre los Resources de Former Walker.
- `data/notes.json`, `data/article_example.json`: formato de los textos a mano.

## Tests y spec
- `tests/wiki.gd`: test headless (40 controles) con archivos temporales.
- `specs/016-wiki.md`: spec con criterios de aceptación.

## Ganchos de descubrimiento que se sumaron al juego de origen
Una línea `WikiProgress.mark(...)` en `Enemy._ready`, `BossController._setup`, `PatronManager.equip`, `Player` (al empuñar
una espada) y `StageRunner.start`, más un botón «Wiki» en el menú principal y en la pausa.
