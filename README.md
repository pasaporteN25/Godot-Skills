# Godot-Skills

Skills de [Claude Code](https://claude.com/claude-code) para juegos hechos en **Godot 4 (GDScript)**.

## Skills

| Skill | Para qué sirve |
|---|---|
| [`godot-test-mode-wiki`](skills/godot-test-mode-wiki/SKILL.md) | Agrega a un juego Godot un **modo de pruebas / admin** (saltar a niveles, jefes y salas, invulnerabilidad, matar enemigos, velocidad, cajas de colisión, estadísticas por nivel), una **wiki / bestiario** que se arma leyendo los Resources, y una pantalla de **controles remapeables**. Nació en *Former Walker* y se probó también en *TDv1*. |

## Instalar una skill

Copiá la carpeta de la skill a `~/.claude/skills/` (en Windows, `C:\Users\<usuario>\.claude\skills\`):

```bash
cp -r skills/godot-test-mode-wiki ~/.claude/skills/
```

Claude Code la carga sola cuando el pedido encaja con su descripción (por ejemplo «agregá un modo admin para probar niveles» o «hacé una wiki con los enemigos»).

## Estructura

```
skills/<nombre>/
├── SKILL.md        instrucciones y criterios de diseño
└── reference/      implementación de referencia (scripts, tests, specs) de un juego real
```

La carpeta `reference/` es una foto de código real: sirve para ver cómo encajan las piezas, no para copiarla tal cual. El `README.md` de cada `reference/` indica qué partes son genéricas y cuáles dependen del juego.
