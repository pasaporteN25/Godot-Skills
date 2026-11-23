---
name: godot-code-console
description: 'Agrega a un juego Godot 4 (GDScript) una consola de códigos en Opciones: el jugador escribe un código y se activa algo (modo de pruebas, trucos, contenido extra, mods). Los códigos son datos (un Resource por código), no secretos: viven en el repo, se listan en un documento y se persisten en un archivo propio de user://. Usalo siempre que el pedido sea activar el modo de pruebas desde el juego sin argumentos de arranque, agregar trucos o códigos, o una lista de códigos que crezca; no lo uses para seguridad ni para proteger contenido de pago.'
---

# Consola de códigos (Godot 4)

Un campo de texto en **Opciones** (menú principal y pausa). El jugador escribe un código, presiona Enter o «Aplicar» y se activa un **efecto** declarado en datos. El primer código de la lista suele ser el del modo de pruebas (ver `godot-test-mode`); después la lista crece con trucos, contenido o modos alternativos.

Referencia de una implementación real: `reference/humanity-booster.md`.

## Diferencia con `godot-test-mode` (leer antes de proponer nada)
`godot-test-mode` recomienda **no usar contraseña ni combinación secreta**, porque en un juego de un jugador el guardado es un archivo editable y una clave no protege nada. Esta skill no la contradice: acá el código **no es seguridad**, es comodidad. Por eso:
- **Los códigos son abiertos**: viven en el repo (`data/codes/*.tres`) y en un documento (`docs/CODIGOS.md`) que cualquiera puede leer. No intentes ocultarlos ni ofuscarlos.
- Sirve para que una **compilación normal** active el modo de pruebas sin argumentos de arranque ni ejecutable aparte (útil para quien prueba y no tiene la línea de comandos a mano).
- Si el proyecto necesita proteger algo (contenido pago, ranking), esto **no** lo hace: eso va en el servidor.

## Antes de escribir código
1. Leé el proyecto (`CLAUDE.md`, cómo se guardan las preferencias, dónde hay una pantalla de Opciones, cómo carga el contenido como datos).
2. Preguntá, con recomendación: ¿el código de pruebas reemplaza al argumento `--pruebas` o convive? (recomendado: conviven). ¿La lista va en el repo? (recomendado: sí, es la idea). ¿La activación persiste entre sesiones? (recomendado: sí, en un archivo propio).
3. Fijá qué efectos existen **hoy** (uno: activar el modo de pruebas). No inventes efectos que nadie usa.

## Diseño (y por qué)
- **Un Resource por código** (`CodeDef`: `id` estable, `code`, `display_name`, `description`, `effect`). Agregar un código = agregar un archivo de datos, sin tocar el código. Si el juego ya carga contenido por datos, `CodeDef` es una clase más del mismo cargador.
- **Los efectos son una lista cerrada en código** (`Codes.EFFECTS`), no strings libres: el código del juego solo reconoce los efectos que conoce. Un efecto nuevo = una constante, su lógica y un caso en el validador; los códigos nuevos para un efecto existente no piden código.
- **Un sistema estático `Codes`** con `normalize()` (recortar y pasar a mayúsculas), `apply()` (devuelve un enum: aplicado, ya activo, desconocido, falló el guardado) y `has_effect()` (lo consulta el sistema que depende del efecto, p. ej. `TestMode.enabled()`).
- **Persistir por id, no por texto**: el archivo guarda `{id: true}`. Si más adelante se cambia el texto del código, las activaciones siguen valiendo.
- **Guardar de forma atómica** (escribir a `.tmp` y renombrar) y **no marcar como activo si falló el guardado**: así la interfaz no dice «activado» y al reiniciar se pierde.
- **Caché con `reset_memory()`** para tests, y la ruta (`path`) y un flag (`save_enabled`) estáticos para que los tests apunten a un archivo temporal.
- **Dónde se ejecuta**: si el juego tiene un único camino para actuar sobre el estado, el código lo usa; no cambies estado de juego desde la interfaz.
- **Interfaz**: una pantalla de Opciones con un `LineEdit` (Enter aplica), botón «Aplicar», mensaje de resultado (no distingas en el texto entre «no existe» y «no disponible» si no hace falta) y, si conviene, la lista de códigos ya activados. Que el foco del campo no robe las teclas del juego.

## Pasos
1. Crear `CodeDef` y la carpeta de datos; registrar la clase en el cargador de contenido.
2. Crear `Codes` con `normalize/apply/has_effect/reset_memory` y la persistencia.
3. Conectar el efecto: el sistema consultado (modo de pruebas, etc.) pregunta `Codes.has_effect(...)` además de su condición actual (feature, argumento).
4. Pantalla de Opciones con el campo; enlazarla desde el menú principal y la pausa.
5. Validador de contenido: código no vacío, **único tras normalizar** (mayúsculas y espacios), efecto conocido, `id` único.
6. Documento `docs/CODIGOS.md`: tabla de códigos y los pasos para agregar uno.
7. Tests: aplicar un código válido y uno inválido, mayúsculas/espacios, activación repetida, persistencia entre «sesiones» (`reset_memory()` y recargar), fallo de guardado, validador, y que el modo de pruebas se active.

## Trampas
- Los tests deben apuntar `Codes.path` a un archivo temporal y restaurarlo; un test que escribe en el `user://` real deja el modo de pruebas activado para siempre.
- Unicidad: `PRUEBAS` y `pruebas ` son el mismo código; validá normalizando.
- Si el modo de pruebas ya redirige guardados o controles al activarse, activarlo **a mitad de sesión** puede dejar estado a medias: decidí si se activa al instante o al reiniciar, y decilo en la interfaz.
- Al sumar un botón de Opciones al menú o a la pausa, actualizá los tests que cuentan botones.
- No pongas en la lista un código cuyo efecto rompa partidas guardadas sin avisar.

## Relacionadas
`godot-test-mode` (el primer código activa ese modo), `godot-remappable-controls` (Opciones suele alojar también los controles y los atajos de pruebas), `godot-headless-tests` (la suite que corre los tests nuevos).
