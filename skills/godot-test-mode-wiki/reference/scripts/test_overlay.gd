class_name TestOverlay
extends Node2D
## Capa de depuración del modo de pruebas (spec 014): dibuja las cajas de golpe y de daño reales.
## Rojo: cuerpo de enemigo · naranja: su zona de contacto · verde: Platero · amarillo: tajo de la espada
## (sólido mientras golpea) · magenta: ondas, esquirlas y proyectiles de los jefes.

const ENEMY := Color(1.0, 0.25, 0.25)
const CONTACT := Color(1.0, 0.6, 0.15)
const PLAYER := Color(0.3, 1.0, 0.4)
const SWORD := Color(1.0, 0.95, 0.2)
const HAZARD := Color(1.0, 0.3, 0.9)


func _ready() -> void:
	top_level = true
	z_index = 200
	global_position = Vector2.ZERO


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var root := get_parent()
	if root == null:
		return
	_walk(root)


func _walk(node: Node) -> void:
	for child in node.get_children():
		if child == self:
			continue
		if child is CollisionShape2D and not (child as CollisionShape2D).disabled:
			_draw_shape(child as CollisionShape2D)
		_walk(child)


func _draw_shape(shape_node: CollisionShape2D) -> void:
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var owner_node := shape_node.get_parent()
	var color := _color_for(owner_node)
	if color.a <= 0.0:
		return
	var rect := Rect2(shape_node.global_position - rect_shape.size * 0.5, rect_shape.size)
	var solid := false
	if owner_node is Area2D and (owner_node as Area2D).name == &"Hitbox":
		solid = (owner_node as Area2D).monitoring
	draw_rect(rect, Color(color.r, color.g, color.b, 0.28) if solid else Color(color.r, color.g, color.b, 0.0), true)
	draw_rect(rect, color, false, 1.0)


func _color_for(owner_node: Node) -> Color:
	if owner_node is Player:
		return PLAYER
	if owner_node is Enemy:
		return ENEMY
	if owner_node is Area2D:
		if owner_node.get_parent() is Enemy:
			return CONTACT
		if owner_node.get_parent() is Player:
			return SWORD if (owner_node as Area2D).monitoring else Color(SWORD.r, SWORD.g, SWORD.b, 0.35)
		if owner_node is Shockwave or owner_node is FallingShard:
			return HAZARD
	return Color(0, 0, 0, 0)
