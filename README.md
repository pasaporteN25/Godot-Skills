# Godot-Skills

Skills de [Claude Code](https://claude.com/claude-code) para juegos hechos en **Godot 4 (GDScript)**.

## Skills

| Skill | Para qué sirve |
|---|---|
| [`godot-project-onboarding`](skills/godot-project-onboarding/SKILL.md) | **Empezá por acá** al preparar una computadora o proyecto: revisa Godot, las herramientas disponibles y los pasos para abrir, probar y exportar. |
| [`godot-test-mode`](skills/godot-test-mode/SKILL.md) | **Modo de pruebas / admin**: saltar a cualquier etapa, sala, oleada o jefe con equipo inicial, invulnerabilidad, matar enemigos, velocidad, cajas de colisión y estadísticas por nivel, en un ejecutable/feature aparte con guardado propio. |
| [`godot-wiki`](skills/godot-wiki/SKILL.md) | **Wiki / bestiario** dentro del juego que se arma leyendo los Resources (no se desactualiza), con entradas cerradas hasta descubrirlas, índice «dónde aparece» y artículos de guía. |
| [`godot-remappable-controls`](skills/godot-remappable-controls/SKILL.md) | **Controles remapeables** (teclas y botones de mando) sobre el InputMap, con guardado de preferencias y pantalla de controles. |
| [`godot-localization`](skills/godot-localization/SKILL.md) | **Idiomas** (español → inglés y los que vengan) con el sistema del motor: el texto fuente es su propia clave, un extractor, un `.po` por idioma, selector en el menú y tests contra textos sin traducir; incluye cómo medir el costo antes de empezar. |
| [`godot-headless-tests`](skills/godot-headless-tests/SKILL.md) | **Tests headless y CI**: una suite que corre todos los tests con un comando (GUT o scripts `SceneTree`), falla ante un `SCRIPT ERROR` y corre en GitHub Actions. |
| [`godot-mainline-export`](skills/godot-mainline-export/SKILL.md) | **Exportar y ejecutar builds** para Windows, Android y Linux usando `main`/`master`, con verificación de presets, plantillas, SDK y dispositivos. |

Las skills de modo de pruebas, wiki, controles remapeables y localización nacieron en *Former Walker* (la wiki y el modo de pruebas también existen en *TDv1*). El modo de pruebas usa la pantalla de controles para sus atajos y muestra la wiki toda abierta; la wiki tiene una entrada «Controles» que refleja el remapeo. `godot-headless-tests` junta lo aprendido en los dos proyectos sobre tests y CI, y esas cuatro skills la usan para que sus tests no queden fuera de la suite.

## Orden recomendado

1. Corré `godot-project-onboarding` primero al configurar una máquina nueva o al entrar a un proyecto: revisa la guía del repo y detecta qué instalar o configurar.
2. Después usá `godot-mainline-export` para generar o ejecutar builds; para las demás tareas, elegí la skill que corresponda.

Para desarrollo y pruebas móviles, recomendamos instalar [Android Studio](https://developer.android.com/studio) y crear un emulador Android (AVD). Así podés instalar y probar la APK sin depender de un teléfono físico. También se puede probar en un dispositivo real con depuración USB.

**iOS:** por ahora no ofrecemos un flujo de exportación o prueba iOS desde este repositorio. Godot requiere una Mac con Xcode para exportar. Más adelante investigaremos alternativas y actualizaremos el repo si encontramos un workaround viable. [Requisitos de exportación iOS de Godot](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

## Instalar

**Como plugin** (recomendado: se actualiza con `claude plugin update`):

```bash
claude plugin marketplace add pasaporteN25/Godot-Skills
```

```bash
claude plugin install godot-skills@godot-skills
```

(o, dentro de Claude Code, `/plugin marketplace add pasaporteN25/Godot-Skills` y `/plugin install godot-skills@godot-skills`). El plugin agrupa todas las skills del repo.

**A mano**: copiá la carpeta de la skill que quieras a `~/.claude/skills/` (en Windows,
`C:\Users\<usuario>\.claude\skills\`):

```bash
cp -r skills/godot-project-onboarding skills/godot-test-mode skills/godot-wiki skills/godot-remappable-controls skills/godot-headless-tests skills/godot-localization skills/godot-mainline-export ~/.claude/skills/
```

Claude Code las carga solas cuando el pedido encaja con su descripción.

## Estructura

```
.claude-plugin/     plugin.json y marketplace.json (instalación como plugin)
skills/<nombre>/
├── SKILL.md        instrucciones, criterios de diseño y trampas conocidas
└── reference/      implementación de referencia (scripts, tests, specs) de un juego real
```

`reference/` es una foto de código real: sirve para ver cómo encajan las piezas, no para copiarla tal cual. El
`README.md` de cada `reference/` indica de qué commit sale y qué partes son genéricas y cuáles dependen del juego.

## Al cambiar una skill

- El `description` del frontmatter va **entre comillas simples**: si tiene `: ` sin comillas, el YAML no parsea y la
  skill carga sin metadatos.
- Validá antes de subir: `claude plugin validate .` (manifiestos y frontmatter de todas las skills).
- Subí `version` en `.claude-plugin/plugin.json` y en `marketplace.json` para que `claude plugin update` la traiga.
