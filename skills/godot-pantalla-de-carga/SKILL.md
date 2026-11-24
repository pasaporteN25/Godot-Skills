---
name: godot-pantalla-de-carga
description: 'Implementá o depurá transiciones de escena en Godot 4 con pantalla de carga, carga en hilo y bloqueo de toques, mouse, teclas y Atrás de Android.'
---

# Pantalla de carga en Godot 4

Patrón basado en [la transición de Monsters & Canons](https://github.com/pasaporteN25/MonstersAndCanons/blob/73e58f4f8cbd985da962561d5e1db324244ef2d9/scripts/logic/scene_transition.gd). Adaptá los tiempos al costo y al comportamiento táctil que midas en cada proyecto.

## Cuándo usarla

- Un cambio de escena tarda (escenas grandes, celular) y el jugador sigue tocando.
- Síntoma típico: **se ejecuta el botón que quedaba debajo del dedo** en la pantalla vieja, o un toque llega a la pantalla nueva apenas aparece.
- Querés una pantalla de carga con tiempo mínimo, carga en hilo y que respete la pausa.
- Querés *un solo lugar* por donde pase todo cambio de escena.

## El problema, en una línea

`change_scene_to_file` carga y arma la escena nueva **en el hilo principal**, y mientras tanto la vieja sigue viva y tocable; los eventos que se juntan mientras el motor está ocupado se entregan **después**, ya sobre la escena nueva.

## El patrón

Dos piezas:

1. **Núcleo genérico** (un `Node`, sin nombrar nada de tu juego): `go(path) -> bool`, `is_busy()`, señales `started`, `finished`, `failed`. Se agrega como hijo de un autoload. Colores, texto, tema y tiempos son propiedades.
2. **Capa fina** en tu autoload de flujo (el que ya tenga `go_to_menu()`, `start_level()`…): todo cambio pasa por un único `_change_scene(path)` y **cada función de flujo sale antes de tocar el estado** si hay un cambio en curso.

Secuencia de `go(path)`:

1. Si ya está ocupado, devolver `false` y no hacer nada.
2. Marcar ocupado, **bloquear la entrada**, mostrar la capa.
3. Esperar **un cuadro** (para que la capa se dibuje antes de lo pesado).
4. `ResourceLoader.load_threaded_request(path)` y mirar `load_threaded_get_status(path, progress)` cada cuadro.
5. Esperar el **tiempo mínimo** (reloj real).
6. `change_scene_to_packed(scene)`, esperar unos cuadros **y** unos milisegundos con la entrada todavía bloqueada.
7. `Input.flush_buffered_events()`, ocultar la capa, liberar la entrada, marcar libre.

## Las trampas

- **El toque que atraviesa.** Una capa `Control` a pantalla completa con `MOUSE_FILTER_STOP` frena el mouse y el toque, pero **no** `_input`, `_unhandled_input`, las teclas ni «atrás». El bloqueo de verdad es `get_tree().root.set_disable_input(true)` (`Viewport.disable_input`; **no** existe como propiedad de `Window`: usar el método). Usar las dos cosas.
- **Guardar el estado, no solo la pantalla.** Aunque se bloquee la entrada, algo puede llamar al flujo por código. Si `start_level(i)` cambia `current_index` *antes* de pedir el cambio, un segundo llamado lo pisa. Salir al principio de cada función de flujo (`if is_changing(): return`).
- **Emulación de mouse desde toque.** En el celular un toque se convierte además en un clic (`emulate_mouse_from_touch`). Probar con **toque y con clic**: bloquear solo uno deja pasar el otro.
- **Lo acumulado se entrega después.** Si la escena nueva tarda en armarse en el hilo principal, los eventos se juntan y llegan en el primer cuadro posterior. Por eso la entrada se libera unos cuadros **y** unos ms *después* del cambio, no en el mismo cuadro.
- **«Atrás» de Android.** `NOTIFICATION_WM_GO_BACK_REQUEST` suele simularse con `Input.parse_input_event(InputEventAction)`. Ignorarlo si hay un cambio en curso, porque algunos juegos lo manejan en la notificación y no por el viewport.
- **Restaurar, no forzar.** Guardar el valor previo de `is_input_disabled()` y devolverlo. Y liberar también en `_exit_tree()` y en el camino de error: si no, un fallo deja la entrada muerta para siempre.
- **Hilo.** `load_threaded_request` devuelve error si la ruta no existe: comprobar `ResourceLoader.exists(path)` antes (si no, el motor imprime errores que algunos frameworks de test cuentan como fallo). Instanciar y el `_ready` de la escena nueva **no** se pueden pasar a un hilo: la barra se congela ahí. Si `load_threaded_request` falla, caer en `ResourceLoader.load`.
- **Pausa.** `process_mode = PROCESS_MODE_ALWAYS` en el núcleo. Esperar con `get_tree().process_frame` (sigue emitiendo con el árbol en pausa). No cambiar la pausa de nadie: el que pausó lo sabe.
- **Mínimo de tiempo.** Medirlo con `Time.get_ticks_msec()`, no con `delta` ni con timers que escalen con `Engine.time_scale`. Sin mínimo, una escena liviana muestra la capa un solo cuadro (parpadeo).
- **Reintentar / recargar.** `reload_current_scene()` también deja pasar toques. Pedir la ruta de `current_scene.scene_file_path` al mismo servicio.
- **Probarlo sin romper la corrida de tests.** No se puede cambiar la escena de un test runner (GUT): el núcleo tiene un `swapper: Callable` que los tests reemplazan por un contador.
- **Probar con eventos reales.** `Input.parse_input_event` + `Input.flush_buffered_events()`. En una corrida sin ventana (`--headless`) la ventana mide 64 × 64 y el contenido se estira: pasar las posiciones por `get_tree().root.get_final_transform() * pos`.
- **Experimentos de control.** Por cada test «el clic no llega» hay que tener otro «sin bloqueo el clic llega»; si no, un helper de clics roto hace pasar todo.

## Código de ejemplo mínimo

```gdscript
# scene_transition.gd — núcleo (sin nombres de tu juego)
class_name SceneTransition
extends Node

signal started(path: String)
signal finished(path: String)
signal failed(path: String)

var min_seconds: float = 0.4
var release_frames: int = 2
var release_seconds: float = 0.15
var swapper: Callable = Callable()   # los tests lo reemplazan

var _busy: bool = false
var _was_disabled: bool = false
var _blocked: bool = false
var _layer: CanvasLayer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	var back := ColorRect.new()
	back.color = Color(0.07, 0.08, 0.1)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	var label := Label.new()
	label.text = "Cargando…"
	label.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(label)


func _exit_tree() -> void:
	_block(false)


func is_busy() -> bool:
	return _busy


func go(path: String) -> bool:
	if _busy or not is_inside_tree():
		return false
	_busy = true
	_layer.visible = true
	_block(true)
	started.emit(path)
	_run(path)  # corrutina: sigue sola
	return true


func _run(path: String) -> void:
	var t0: int = Time.get_ticks_msec()
	await get_tree().process_frame            # que la capa se dibuje
	var scene: PackedScene = await _load(path)
	if scene == null:
		_close()
		failed.emit(path)
		return
	while float(Time.get_ticks_msec() - t0) / 1000.0 < min_seconds:
		await get_tree().process_frame
	if swapper.is_valid():
		swapper.call(scene)
	elif get_tree().change_scene_to_packed(scene) != OK:
		_close()
		failed.emit(path)
		return
	for i: int in release_frames:
		await get_tree().process_frame
	var t1: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t1) / 1000.0 < release_seconds:
		await get_tree().process_frame
	_close()
	finished.emit(path)


func _load(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	if ResourceLoader.load_threaded_request(path) != OK:
		return ResourceLoader.load(path) as PackedScene
	while true:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return null
		await get_tree().process_frame
	return null


func _close() -> void:
	Input.flush_buffered_events()
	_layer.visible = false
	_block(false)
	_busy = false


func _block(on: bool) -> void:
	if not is_inside_tree():
		_blocked = false
		return
	var root: Window = get_tree().root
	if on and not _blocked:
		_was_disabled = root.is_input_disabled()
		root.set_disable_input(true)
		Input.flush_buffered_events()
		_blocked = true
	elif not on and _blocked:
		root.set_disable_input(_was_disabled)
		_blocked = false
```

Capa fina en el autoload de flujo:

```gdscript
var transition: SceneTransition

func _ready() -> void:
	transition = SceneTransition.new()
	add_child(transition)

func is_changing() -> bool:
	return transition.is_busy()

func start_level(index: int) -> void:
	if is_changing():
		return                       # antes de tocar el estado
	current_index = index
	transition.go(LEVEL_SCENE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_changing():
		return
	# Seguir con el manejo normal de Atrás de este proyecto.
```

## Cómo verificar que quedó bien

1. Test: tocar la tarjeta A y, durante la carga, tocar la tarjeta B (mouse y toque): `current_index` sigue en A y el cambio ocurre una sola vez.
2. Test: un evento generado *dentro* del `swapper` (mientras el motor «arma» la escena) no llega a ningún botón.
3. Test: ruta inexistente → `failed`, entrada liberada, escena vieja intacta.
4. Test: con el árbol en pausa termina igual (esperar con `create_timer(t, true)`, porque el runner de tests también se pausa).
5. En un celular real: tocar varias veces durante la carga y, si se puede, medir cuánto tarda. Los tests de escritorio no miden el tacto ni el tiempo real de un celular.
