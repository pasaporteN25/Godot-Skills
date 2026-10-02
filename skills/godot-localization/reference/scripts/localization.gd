extends Node
## Autoload «Localization»: aplica el idioma al arrancar, antes de que exista ninguna pantalla (spec 017).
## Sin `class_name`: no puede llamarse igual que el autoload. La lógica está en `Loc`.


func _ready() -> void:
	Loc.ensure_loaded()
