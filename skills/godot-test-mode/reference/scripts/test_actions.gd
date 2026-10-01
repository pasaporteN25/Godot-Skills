class_name TestActions
extends RefCounted
## Acciones del modo de pruebas (spec 014) como funciones sobre el juego en curso. Sin interfaz: las usan el
## panel, los atajos y las pruebas automáticas. Usan solo lo que ya hace el juego (daño, derrota, salas).

const ENEMIES_DIR := "res://resources/enemies/"
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0]


# --- saltos desde el menú ------------------------------------------------------

## Arranca la partida en el arco/etapa/sala elegidos. `jump`: arc, stage (-1 = interludio), room, level,
## silver, sword, patron, hearts. Lo anterior queda marcado como superado.
static func start_jump(game: Game, jump: Dictionary) -> void:
	var arc_count := game.campaign.arcs.size() if game.campaign != null else 1
	var arc_index := clampi(int(jump.get("arc", 0)), 0, arc_count - 1)
	var stage_index := int(jump.get("stage", 0))
	prepare_session(game, arc_index, stage_index)
	apply_kit(game.session, jump)
	if stage_index < 0:
		if game.arc.interlude != null:
			game.enter_interlude(game.arc.interlude)
		else:
			game.go_umbral()
		return
	game.enter_stage(stage_index)
	var room_id := StringName(jump.get("room", ""))
	if room_id != &"" and game.runner != null and game.runner.stage.find_room(room_id) != null:
		go_to_room(game.runner, room_id)


## Deja la sesión como si se hubiera llegado jugando: arcos y etapas anteriores superados.
static func prepare_session(game: Game, arc_index: int, stage_index: int) -> void:
	var session := game.session
	var arcs: Array[ArcDefinition] = []
	if game.campaign != null:
		arcs.assign(game.campaign.arcs)
	else:
		arcs.append(game.arc)
	for i in arc_index:
		for stage in arcs[i].stages:
			session.completed[stage.id] = true
		if arcs[i].interlude != null:
			session.completed[arcs[i].interlude.id] = true
	session.arc_index = arc_index
	session.arc = arcs[arc_index]
	game.arc = session.arc
	session.tartessos_reborn = arc_index > 0 or stage_index < 0 or session.tartessos_reborn
	var done := stage_index if stage_index >= 0 else session.arc.stages.size()
	for i in mini(done, session.arc.stages.size()):
		session.completed[session.arc.stages[i].id] = true
	session.progress = clampi(done, 0, session.arc.stages.size() - 1)


## Equipamiento inicial: nivel (con sus mejoras), plata, espada, patrono y corazones extra.
static func apply_kit(session: GameSession, kit: Dictionary) -> void:
	var level := clampi(int(kit.get("level", 0)), 0, session.levels.max_level())
	session.level = level
	session.bonus_hearts = 0
	session.bonus_damage_pct = 0.0
	for i in level:
		match session.levels.perk(i):
			&"heart":
				session.bonus_hearts += 1
			&"damage":
				session.bonus_damage_pct += session.levels.damage_pct_per_perk
	session.bonus_hearts += maxi(0, int(kit.get("hearts", 0)))
	session.silver = maxi(0, int(kit.get("silver", 0)))
	session.silver_earned = maxi(session.silver, session.levels.threshold(level - 1) if level > 0 else 0)
	var sword := StringName(kit.get("sword", ""))
	if sword != &"" and SwordCatalog.get_definition(sword) != null:
		session.sword_id = sword
	var patron := StringName(kit.get("patron", ""))
	session.patron_id = patron if _arc_has_patron(session.arc, patron) else &""


static func _arc_has_patron(arc: ArcDefinition, patron: StringName) -> bool:
	for p in arc.patrons:
		if p.id == patron:
			return true
	return false


# --- salas y etapa -------------------------------------------------------------

## Punto de aparición para entrar a una sala sin pasar por sus salidas: `start` si existe, si no el primero.
static func room_spawn(definition: RoomDefinition) -> StringName:
	var inst := definition.scene.instantiate() as Room
	inst.scan()
	var spawn: StringName = &""
	if inst.has_spawn(&"start"):
		spawn = &"start"
	elif not inst.spawns.is_empty():
		spawn = inst.spawns.keys()[0]
	inst.free()
	return spawn


static func go_to_room(runner: StageRunner, room_id: StringName) -> bool:
	var definition := runner.stage.find_room(room_id)
	if definition == null:
		return false
	runner.go_to_room(room_id, room_spawn(definition))
	return true


## Sala anterior (-1) o siguiente (+1) de la etapa, en el orden de `rooms`, dando la vuelta al final.
static func step_room(runner: StageRunner, step: int) -> StringName:
	var rooms := runner.stage.rooms
	if rooms.is_empty():
		return &""
	var current := 0
	for i in rooms.size():
		if rooms[i].id == runner.current_room_id:
			current = i
	var target := rooms[posmod(current + step, rooms.size())].id
	go_to_room(runner, target)
	return target


## Abre todos los atajos de la etapa (palancas y puertas de todas sus salas).
static func open_all_shortcuts(runner: StageRunner) -> int:
	var gates := {}
	for definition in runner.stage.rooms:
		var inst := definition.scene.instantiate() as Room
		inst.scan()
		for exit in inst.exits:
			if exit.gate_id != &"":
				gates[exit.gate_id] = true
		for sw in inst.switches:
			if sw.gate_id != &"":
				gates[sw.gate_id] = true
		inst.free()
	for gate: StringName in gates:
		runner.state.open_shortcut(gate)
	if runner.room != null:
		for exit in runner.room.exits:
			exit.active = runner.state.is_open(exit.gate_id)
		for sw in runner.room.switches:
			sw.show_open(runner.state.is_open(sw.gate_id))
	return gates.size()


## Da la etapa por superada como si Platero hubiera llegado a la meta.
static func complete_stage(runner: StageRunner) -> void:
	runner.complete_now()


# --- enemigos y jefes ----------------------------------------------------------

## Vence a todos los enemigos vivos (menos los jefes) y descarta las oleadas que faltan, sin soltar plata.
## Devuelve cuántos mató.
static func kill_all(runner: StageRunner) -> int:
	var count := 0
	runner.clear_pending_waves()
	runner.test_no_loot = true
	for node in runner.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy.is_in_group("bosses"):
			continue
		enemy._take_damage(enemy.hp + 1.0)
		count += 1
	runner.test_no_loot = false
	return count


## Hace aparecer un enemigo junto a Platero, sin botín ni registro de derrota.
static func spawn_enemy(runner: StageRunner, definition: EnemyDefinition, frozen: bool = false) -> Enemy:
	if runner.room == null or runner.player == null or definition.scene == null:
		return null
	var enemy := definition.scene.instantiate() as Enemy
	enemy.definition = definition
	enemy.spawner_id = &"test_spawn"
	enemy.position = runner.player.global_position + Vector2(70.0 * runner.player.facing, 0.0)
	enemy.frozen = frozen
	runner.room.add_child(enemy)
	return enemy


## Todas las definiciones de enemigos menores (sin los cuerpos de jefe), por id.
static func enemy_definitions() -> Array[EnemyDefinition]:
	var result: Array[EnemyDefinition] = []
	for file in DirAccess.get_files_at(ENEMIES_DIR):
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres") or name.ends_with("_body.tres"):
			continue
		var definition := load(ENEMIES_DIR + name) as EnemyDefinition
		if definition != null and definition.scene != null:
			result.append(definition)
	result.sort_custom(func(a: EnemyDefinition, b: EnemyDefinition) -> bool: return String(a.id) < String(b.id))
	return result


static func boss_next_phase(boss: BossController) -> void:
	boss._pause_time = 0.0
	boss._phase_cleared()


static func boss_to_one_hp(boss: BossController) -> void:
	boss.phase_hp = 1.0
	boss.hp = 1.0


# --- Platero --------------------------------------------------------------------

static func heal(player: Player) -> void:
	player.heal_full()


static func add_silver(player: Player, amount: int) -> void:
	player.add_silver(amount)


static func edge_to_max(player: Player) -> void:
	player.sword.edge = player.sword.max_edge
	player.sword.edge_changed.emit(player.sword.edge, player.sword.max_edge)


static func toggle_tarnish(player: Player) -> bool:
	if player.sword.tarnished:
		player.sword.clean()
	else:
		player.sword.tarnish()
	return player.sword.tarnished


static func cycle_patron(session: GameSession, player: Player) -> StringName:
	var definition := session.cycle_patron()
	player.patron.equip(definition)
	return session.patron_id


## Sube un nivel sin pedir la plata (la regala): aplica la mejora a Platero. Devuelve la mejora o vacío.
static func force_level_up(session: GameSession, player: Player) -> StringName:
	if session.level >= session.levels.max_level():
		return &""
	var perk := session.levels.perk(session.level)
	session.silver_earned = maxi(session.silver_earned, session.levels.threshold(session.level))
	player.silver_earned = maxi(player.silver_earned, session.silver_earned)
	session.level += 1
	match perk:
		&"heart":
			session.bonus_hearts += 1
			player.max_hearts += 1.0
			player.hearts += 1.0
			player.healed.emit()
		&"damage":
			session.bonus_damage_pct += session.levels.damage_pct_per_perk
			player.sword.damage_bonus_pct = session.bonus_damage_pct
	return perk


# --- mundo ------------------------------------------------------------------------

static func set_speed(value: float) -> float:
	Engine.time_scale = clampf(value, SPEEDS[0], SPEEDS[SPEEDS.size() - 1])
	return Engine.time_scale


## Pasa a la velocidad siguiente (+1) o anterior (-1) de `SPEEDS`.
static func step_speed(step: int) -> float:
	var index := 2
	for i in SPEEDS.size():
		if is_equal_approx(SPEEDS[i], Engine.time_scale):
			index = i
	return set_speed(SPEEDS[clampi(index + step, 0, SPEEDS.size() - 1)])
