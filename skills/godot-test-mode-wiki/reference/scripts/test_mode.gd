class_name TestMode
extends RefCounted
## Modo de pruebas (spec 014). Solo existe cuando la feature `pruebas` está presente (preset de exportación
## "Windows (pruebas)") o al arrancar con el argumento `--pruebas`. Usa guardados y preferencias propios,
## para no tocar el progreso real. Un jugador normal nunca lo ve.

const FEATURE := "pruebas"
const ARG := "--pruebas"
const SAVE_PATH := "user://save_pruebas.json"
const BINDINGS_PATH := "user://input_bindings_pruebas.json"
const STATS_PATH := "user://pruebas_stats.json"

## Atajos del panel: acción de InputMap, texto en la pantalla de controles y tecla por defecto (posición
## física). Dígitos y F1–F4: el juego normal no los usa (ver tests, AC-014-12).
const SHORTCUTS := [
	{"action": &"test_panel", "label": "Pruebas: abrir el panel", "key": KEY_F1},
	{"action": &"test_kill_all", "label": "Pruebas: matar a todos", "key": KEY_F2},
	{"action": &"test_god", "label": "Pruebas: invulnerable", "key": KEY_F3},
	{"action": &"test_heal", "label": "Pruebas: curar", "key": KEY_F4},
	{"action": &"test_speed_down", "label": "Pruebas: velocidad más lenta", "key": KEY_1},
	{"action": &"test_speed_up", "label": "Pruebas: velocidad más rápida", "key": KEY_2},
	{"action": &"test_speed_reset", "label": "Pruebas: velocidad normal", "key": KEY_0},
	{"action": &"test_overlay", "label": "Pruebas: ver cajas de golpe", "key": KEY_3},
	{"action": &"test_room_prev", "label": "Pruebas: sala anterior", "key": KEY_7},
	{"action": &"test_room_next", "label": "Pruebas: sala siguiente", "key": KEY_8},
	{"action": &"test_boss_phase", "label": "Pruebas: siguiente fase del jefe", "key": KEY_4},
	{"action": &"test_boss_low", "label": "Pruebas: jefe a 1 de vida", "key": KEY_5},
	{"action": &"test_silver", "label": "Pruebas: +1000 de plata", "key": KEY_6},
	{"action": &"test_edge", "label": "Pruebas: filo al máximo", "key": KEY_9},
]

## Para pruebas automáticas: -1 = según la feature y los argumentos, 0 = apagado, 1 = encendido.
static var force: int = -1
static var _original_save_path: String = ""
static var _original_bindings_path: String = ""
static var _active: bool = false


static func enabled() -> bool:
	if force >= 0:
		return force == 1
	return OS.has_feature(FEATURE) or ARG in OS.get_cmdline_user_args() or ARG in OS.get_cmdline_args()


## Prepara todo lo propio del modo: guardados aparte y atajos en el InputMap. No hace nada si está apagado.
static func activate() -> void:
	if _active or not enabled():
		return
	_active = true
	_original_save_path = SaveGame.path
	_original_bindings_path = ControlBindings.path
	SaveGame.path = SAVE_PATH
	ControlBindings.path = BINDINGS_PATH
	for shortcut: Dictionary in SHORTCUTS:
		var keys: Array[int] = [int(shortcut["key"])]
		ControlBindings.register_extra(shortcut["action"], String(shortcut["label"]), keys)
	if ControlBindings.is_loaded():
		ControlBindings.reload_saved()


## Deshace `activate` (solo lo usan las pruebas automáticas).
static func deactivate() -> void:
	if not _active:
		return
	_active = false
	SaveGame.path = _original_save_path
	ControlBindings.path = _original_bindings_path
	ControlBindings.clear_extra()


static func is_active() -> bool:
	return _active
