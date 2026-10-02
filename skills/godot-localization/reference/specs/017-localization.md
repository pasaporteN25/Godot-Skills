# 017 — Idiomas (español e inglés)

**Estado:** Implementada (falta la skill y la revisión visual del usuario) (2026-10-01, a pedido del usuario) · **Depende de:** 014, 015, 016

## Problema

Todo el texto del juego está escrito en español dentro de los scripts, los `.tres`, las escenas y los JSON de la wiki. Hace falta jugarlo en inglés y poder sumar más idiomas sin tocar el código.

## Decisiones (usuario, 2026-10-01)

1. **Los nombres propios no se traducen** (Platero, Argantonio, Hades, Cronos, Tartessos, el Umbral de Hades…). Los nombres de enemigos comunes, objetos, lugares «descriptivos» y habilidades sí.
2. **Solo Former Walker.** El resto de los proyectos usa la skill `godot-localization`, extraída de esta implementación.
3. **El inglés lo traduce el agente y el usuario lo revisa jugando;** las traducciones se aplican de inmediato, no se esperan a la revisión.

## Diseño

- **El español es el texto fuente y su propia clave.** Cada texto del juego se escribe en español en el código/dato y se muestra con `tr("…")`; `translations/<código>.po` lo traduce. Ventaja: no hay claves inventadas que mantener ni textos duplicados, y el juego sigue legible sin traducciones. Costo: corregir una errata en español deja sin traducción al texto viejo → un test lo detecta.
- **Un idioma = un `.po`** (`translations/en.po`), una línea en `Loc.LANGUAGES` y una en `[internationalization]` de `project.godot`.
- **Datos:** los campos de texto de los Resources (`display_name`, `description`, `intro_text`, `completion_line`, `hades_lines`, `ending_pages`, `ending_hint`), el `text` de los carteles de las escenas y los JSON de la wiki siguen en español; el código que los muestra los pasa por `tr()`. La herramienta `tools/build_translations.gd` los extrae.
- **`tools/build_translations.gd`** regenera `translations/es.pot` (plantilla, versionada) y agrega al `en.po` los textos nuevos con la traducción vacía; quita los que ya no existen.
- **Qué idioma arranca:** `--lang=xx` > preferencia guardada (`user://language.json`) > idioma del sistema si está disponible > español. **Cuando Godot corre un script suelto (`-s`), siempre español** (salvo `--lang`): la suite no depende de la computadora ni de la preferencia del jugador.
- **Selector:** botón «Idioma» en el menú principal; recarga el menú. (En la pausa no: las pantallas ya armadas no se reconstruyen.)
- **Fuera de alcance:** el modo de pruebas (panel, «Saltar a…», estadísticas) y los mensajes de error de validación de datos (`errors.append`) siguen en español: son para el desarrollo. Arte con texto dibujado (no hay). Plurales con regla propia (Godot `tr_n` si algún día hace falta). Idiomas de derecha a izquierda.

## Qué se traduce

| Fuente | Cómo se extrae | Cómo se muestra |
|---|---|---|
| `tr("…")` en scripts | literal dentro de `tr(`…`)` | `tr` |
| constantes de texto (`LINE_*`, tablas) | las sentencias bajo una línea `# i18n`, hasta la primera línea en blanco | `tr(CONSTANTE)` |
| Resources | campos de texto listados arriba | `tr(definition.campo)` |
| Escenas | `text = "…"` de los carteles | `tr(text)` |
| Wiki | `notes.json` (`texto`, `consejo`) y `articles/*.json` | `tr` al armar la entrada |

## Criterios de aceptación

- [x] **AC-017-1** Con el idioma en inglés ningún texto del juego fuera del modo de pruebas queda en español: cada texto extraído tiene traducción no vacía y los `%s`/`%d` coinciden con el original.
- [x] **AC-017-2** `translations/es.pot` coincide con lo que extrae la herramienta (el test falla si quedó viejo) y `en.po` no tiene textos que ya no existen.
- [x] **AC-017-3** Los nombres propios siguen iguales en inglés.
- [x] **AC-017-4** El idioma elegido se guarda en `user://language.json` y se aplica al abrir el juego; un archivo dañado, de otra versión o con un idioma desconocido se ignora.
- [x] **AC-017-5** Un script suelto (`-s`) arranca en español aunque la preferencia o el sistema digan otra cosa; `--lang=en` lo cambia.
- [x] **AC-017-6** El menú principal muestra el selector, cambia de idioma y se reconstruye sin perder el foco; el menú, la pausa, la wiki, los controles y el final se ven en inglés.
- [x] **AC-017-7** En inglés, la wiki cerrada no filtra nombres ni números reales (igual que AC-016-2) y «Controles» muestra las teclas con textos en inglés.
- [x] **AC-017-8** Toda la suite anterior pasa sin cambios de comportamiento en español.
- [ ] **AC-017-9** La seudolocalización de Godot (`Loc.set_pseudo`) deja ver sin cortes el menú principal, la pausa y la wiki a 640×360 (revisión visual).
