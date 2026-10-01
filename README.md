# Godot-Skills

Skills de [Claude Code](https://claude.com/claude-code) para juegos hechos en **Godot 4 (GDScript)**.

## Skills

| Skill | Para qué sirve |
|---|---|
| [`godot-test-mode`](skills/godot-test-mode/SKILL.md) | **Modo de pruebas / admin**: saltar a cualquier etapa, sala o jefe con equipo inicial, invulnerabilidad, matar enemigos, velocidad, cajas de colisión y estadísticas por nivel, en un ejecutable/feature aparte con guardado propio. |
| [`godot-wiki`](skills/godot-wiki/SKILL.md) | **Wiki / bestiario** dentro del juego que se arma leyendo los Resources (no se desactualiza), con entradas cerradas hasta descubrirlas, índice «dónde aparece» y artículos de guía. |
| [`godot-remappable-controls`](skills/godot-remappable-controls/SKILL.md) | **Controles remapeables** (teclas y botones de mando) sobre el InputMap, con guardado de preferencias y pantalla de controles. |

Las tres nacieron en *Former Walker* (la wiki y el modo de pruebas también existen en *TDv1*) y se complementan:
el modo de pruebas usa la pantalla de controles para sus atajos y muestra la wiki toda abierta, y la wiki tiene una entrada
«Controles» que refleja el remapeo.

## Instalar

Copiá la carpeta de la skill que quieras a `~/.claude/skills/` (en Windows, `C:\Users\<usuario>\.claude\skills\`):

```bash
cp -r skills/godot-test-mode skills/godot-wiki skills/godot-remappable-controls ~/.claude/skills/
```

Claude Code las carga solas cuando el pedido encaja con su descripción (por ejemplo «agregá un modo admin para probar
niveles», «hacé una wiki con los enemigos» o «que se puedan remapear las teclas»).

## Estructura

```
skills/<nombre>/
├── SKILL.md        instrucciones, criterios de diseño y trampas conocidas
└── reference/      implementación de referencia (scripts, tests, specs) de un juego real
```

`reference/` es una foto de código real: sirve para ver cómo encajan las piezas, no para copiarla tal cual. El
`README.md` de cada `reference/` indica qué partes son genéricas y cuáles dependen del juego.
