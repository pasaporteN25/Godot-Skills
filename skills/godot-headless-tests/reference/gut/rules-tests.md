---
paths:
  - "tests/**/*.gd"
---

# Reglas para los tests (GUT)

- **Cómo se corren** (desde la carpeta del proyecto):
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (todos) o `-gtest=res://tests/test_x.gd` (uno). Antes, si hay clases nuevas: `godot --headless --import`.
- **Un test de lógica no abre escenas.** Las fórmulas y los formatos se prueban con `scripts/logic/` (P10). Una escena solo se instancia para probar cómo se conecta.
- **Nunca se llama a funciones que cambian de pantalla** (`GameFlow.go_to_*`, `start_level`, `leave()`): reemplazarían la escena de GUT y cortarían la corrida. Para eso hay "costuras": señales (`left`), variables (`maps_dir`, `on_leave`, `is_seen`) y abridores falsos.
- **Los errores del motor cuentan como fallo.** Un `push_error` esperado se prueba con `assert_push_error`. Un error inesperado (`SCRIPT ERROR`, "Unexpected Errors") es un test que falla aunque los asserts pasen.
- **No tocar el guardado real ni la carpeta de mapas del jugador:** cambiar `SaveManager.save_path` a un archivo de prueba (`user://test_*.json`) y restaurarlo en `after_each`; usar carpetas `user://test_*/` y borrarlas al terminar.
- **Nombres de archivo de prueba:** en Windows `con`, `nul`, `com1`… no se pueden crear; usar otros.
- `GutTest` no tiene `assert_does_not_contain`: usar `assert_false(texto.contains(...))`.
- Un test nuevo de un comportamiento **verifica el caso de borde** (el límite, el vacío, el que falla), no solo el camino feliz.
