---
name: godot-headless-tests
description: 'Arma o arregla la suite de tests automáticos de un juego Godot 4 (GDScript) para que corra entera con un solo comando y en GitHub Actions: tests headless (GUT, gdUnit4 o scripts "extends SceneTree"), un runner que encuentra los tests solo, que falla ante un SCRIPT ERROR aunque el código de salida sea 0, archivos temporales en user:// y CI con Godot en caché. Usalo cuando el usuario pida "tests automáticos", "CI", "GitHub Actions", "que corran todos los tests", "test headless", "los tests tocan mi guardado" o "los tests pasan pero hay errores"; y también cada vez que agregues un archivo de test nuevo a un proyecto Godot (por ejemplo desde godot-test-mode, godot-wiki o godot-remappable-controls), para confirmar que la suite lo corre.'
---

# Tests headless y CI (Godot 4)

Resuelve dos fallas que pasaron de verdad:
- **Tests que nadie corre.** En Former Walker la «definición de hecho» era `-s tests/headless/run.gd`, pero `wiki.gd`, `test_mode.gd`, `controls.gd` y cinco tests de arte eran scripts aparte: estaban en verde el día que se escribieron y después nadie los volvió a ejecutar.
- **Verde con un script roto.** GUT saltea sin avisar un archivo de test que no compila y termina en verde (TDv1, D-030); un script `-s` que no compila puede salir con código 0.

Hay referencias de los dos casos en `reference/`: `scenetree/` (Former Walker, sin framework) y `gut/` (TDv1/JuegoA, GUT).

## Antes de escribir código
1. **Detectá el framework** y seguí el del proyecto, sin mezclar: `addons/gut/` → GUT; `addons/gdUnit4/` → gdUnit4; scripts `extends SceneTree` en `tests/` → sin framework. Si no hay nada y el usuario no tiene preferencia, recomendá scripts `extends SceneTree` (cero dependencias) o GUT (si va a haber muchos tests y quiere el panel del editor).
2. **Encontrá la «definición de hecho»**: `CLAUDE.md`, README, `tools/test.*`, workflow de CI. Ese comando es el que tiene que correr **todo**.
3. **Compará lo que existe con lo que corre**: listá los archivos de test y fijate cuáles ejecuta de verdad ese comando. Si hay huérfanos, ese es el primer arreglo.

## Reglas (y por qué)
- **Un comando corre todo y un test nuevo entra solo**: descubrimiento por carpeta, nunca una lista a mano que alguien se olvida de actualizar.
  - GUT: `-s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
  - Sin framework: un `tests/headless/all.gd` que lista la carpeta y corre cada script **en su propio proceso** (`OS.create_process(OS.get_executable_path(), ["--headless", "--path", raíz, "--log-file", registro, "-s", ruta])`), sondea el registro y lee el código con `OS.get_process_exit_code`. Proceso propio = no comparten estáticos ni autoloads (igual que al correrlos a mano). Ver `reference/scenetree/all.gd`; ofrece `-- solo=wiki,controls` para iterar y `-- limite=N` segundos por test.
- **Error de script = fallo**, aunque el código sea 0: buscá `SCRIPT ERROR`, `Parse Error` y `Failed to load script` en la salida. Los avisos de fugas al salir (`leaked at exit`, `resources still in use`) no cuentan como fallo, pero conviene limpiarlos.
- **Un test roto se cuelga para siempre**: un error en tiempo de ejecución en un script `extends SceneTree` corta la función y nunca llega a `quit()`; el proceso queda vivo. El runner corta el test unos segundos después del primer `SCRIPT ERROR` y a los N segundos en cualquier caso; en CI, además, `timeout-minutes`.
- **Importar antes de correr**: `--headless --path . --import`. Hace falta tras sumar un `class_name` y siempre en CI (la carpeta `.godot/` no está en git).
- **Ningún test toca archivos reales**: rutas estáticas (`SaveGame.path`, controles, progreso de la wiki, estadísticas) apuntadas a `user://test_*.json` y borradas al final; el guardado apagado (`SaveGame.enabled = false`) en `_initialize`. Dos proyectos con el mismo nombre (o un worktree) comparten `user://`: nombres de archivo de test únicos.
- **Las herramientas también compilan**: en CI, `--check-only -s tools/x.gd` para cada script de `tools/` (ningún test los carga).
- **El último renglón de cada test es su resumen** («Wiki: 40 controles / 0 fallos») y el código de salida es 0 solo si no falló nada: es lo que leen `all.gd` y el CI.

## CI (GitHub Actions)
`reference/gut/tests.yml` y `reference/scenetree/tests.yml`: `ubuntu-24.04` fijo (no `ubuntu-latest`, que cambia solo), Godot oficial descargado de GitHub y guardado en la caché (sin imágenes Docker ni actions de terceros), importar, revisar `tools/`, correr la suite. Exportar ejecutables queda fuera: necesita ~1 GB de plantillas y no agrega seguridad a los tests. En un repo privado son minutos pagos (2000 gratis por mes): avisá cuánto tarda la suite.

## Trampas (cada una costó tiempo)
- **Linux distingue mayúsculas**: un `load("res://Art/x.png")` que anda en Windows falla en CI si el archivo es `art/x.png`. La primera corrida en CI suele encontrar alguno.
- `godot.cmd` se cuelga desde Bash: llamá al `Godot_v…_console.exe` directo. No renombres el `_console.exe` (es un lanzador que busca al Godot real por su nombre).
- **No captures la salida con pipes** (`OS.execute` con salida u `OS.execute_with_pipe`): `OS.execute` espera sin límite a un test colgado, y con `execute_with_pipe` no bloqueante el pipe se llena con un test que imprime mucho y el test se traba. `--log-file` escribe todo a un archivo y los errores al instante; esperá a que el proceso muera tras `OS.kill` antes de borrar el registro (en Windows queda abierto).
- Imprimí un resumen por test al terminar cada uno y la salida completa solo si falló. La suite completa tarda minutos: correla en segundo plano.
- **El idioma de la computadora cambia los tests**: si el juego tiene idiomas, un script `-s` arranca en el idioma del sistema (en CI, inglés) y los textos esperados dejan de coincidir. Forzá el idioma original en los scripts sueltos (ver `godot-localization`).
- **Un clon limpio no es tu carpeta**: si el código commiteado carga un asset que solo existe sin commitear, la suite pasa en tu máquina y falla en CI (Former Walker: `preload` de un shader y retratos que el agente de arte no había subido). Probá la suite en un `git worktree` del commit antes de dar el CI por bueno.
- GUT: nunca llames funciones que cambian de escena (`change_scene_to_*`, `go_to_*`): reemplazan la escena de GUT y cortan la corrida. Usá costuras (señales, variables inyectables).
- `JSON.parse_string` imprime ERROR ante un archivo dañado (y eso hace fallar un test «de archivo dañado»): usá `JSON.new().parse(...)`.
- No llames `reload()` a un método estático: choca con `Script.reload()` y resetea los estáticos (la ruta vuelve a la real y el test escribe el archivo del jugador).
- Un lambda captura locales por valor: para un flag, un array de un elemento.
- Los scripts `-s` se compilan antes que los autoloads: en `tools/` no se puede usar un autoload como tipo.
- En Windows no se pueden crear archivos `con`, `nul`, `com1`…: no los uses como nombre de prueba.

## Verificación
1. **Rompé a propósito**: sumá un test que falle, otro con un error de sintaxis y otro con un error en tiempo de ejecución (`var n: Node = null; n.get_name()`); la suite tiene que terminar con código 1, nombrar los tres y no colgarse. Borralos.
2. Suite completa en verde y `user://` sin archivos `test_*` sobrantes.
3. Actualizá la «definición de hecho» (`CLAUDE.md`, README, `tools/test.*`) para que apunte al comando nuevo.
4. Con CI: la primera corrida en GitHub en verde (el PR que lo agrega ya la dispara).

## Relacionadas
`godot-test-mode`, `godot-wiki` y `godot-remappable-controls` agregan cada una un archivo de test: esta skill es la que asegura que la suite lo corre.
