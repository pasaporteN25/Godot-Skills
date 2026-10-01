class_name TestStats
extends Node
## Estadísticas de una pasada por una etapa en el modo de pruebas (spec 014): daño recibido, filo gastado,
## plata ganada, muertes y tiempo. Sirve para comparar con `docs/balance/report.md` sin cronometrar a mano.
## El daño recibido cuenta aunque Platero sea invulnerable: es lo que habría perdido.

var runner: StageRunner
var player: Player
var damage_taken: float = 0.0
var edge_spent: float = 0.0
var silver_earned: int = 0
var deaths: int = 0
var seconds: float = 0.0

var _last_edge: float = 0.0
var _start_earned: int = 0
var _started_at: String = ""
var _finished: bool = false


## Empieza a medir la etapa del `runner` (que ya tiene a Platero).
func bind(stage_runner: StageRunner) -> void:
	runner = stage_runner
	player = stage_runner.player
	_last_edge = player.sword.edge
	_start_earned = player.silver_earned
	_started_at = Time.get_datetime_string_from_system()
	player.hurt.connect(func(amount: float) -> void: damage_taken += amount)
	player.died.connect(func() -> void: deaths += 1)


func _physics_process(delta: float) -> void:
	if player == null or _finished or not is_instance_valid(player):
		return
	seconds += delta
	var edge := player.sword.edge
	if edge < _last_edge:
		edge_spent += _last_edge - edge
	_last_edge = edge
	silver_earned = player.silver_earned - _start_earned


func to_dict(outcome: StringName = &"") -> Dictionary:
	return {
		"stage": String(runner.stage.id) if runner != null and runner.stage != null else "",
		"stage_name": runner.stage.display_name if runner != null and runner.stage != null else "",
		"started_at": _started_at,
		"damage_taken": snappedf(damage_taken, 0.01),
		"edge_spent": snappedf(edge_spent, 0.1),
		"silver_earned": silver_earned,
		"deaths": deaths,
		"seconds": snappedf(seconds, 0.1),
		"outcome": String(outcome),
	}


## Línea corta para el panel.
func summary() -> String:
	return "Daño %.1f · Filo %.1f · Plata %d · Muertes %d · %s" % [damage_taken, edge_spent, silver_earned, deaths, format_time(seconds)]


static func format_time(total: float) -> String:
	var s := int(total)
	return "%d:%02d" % [s / 60, s % 60]


## Cierra la medición y agrega la pasada al archivo (si duró lo suficiente para valer algo).
func finish(outcome: StringName, path: String = TestMode.STATS_PATH) -> void:
	if _finished:
		return
	_finished = true
	if seconds < 2.0:
		return
	append_run(to_dict(outcome), path)


static func append_run(entry: Dictionary, path: String) -> void:
	var runs: Array = read_runs(path)
	runs.append(entry)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudieron guardar las estadísticas en %s" % path)
		return
	file.store_string(JSON.stringify({"runs": runs}, "\t"))


static func read_runs(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("runs")) == TYPE_ARRAY:
		return parsed["runs"]
	return []
