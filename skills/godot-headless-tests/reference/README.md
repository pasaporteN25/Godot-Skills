# Implementación de referencia (2026-10-01)

Copias de dos proyectos reales. Son fotos: si el proyecto cambió, mirá su repositorio.

## `scenetree/` — sin framework (Former Walker)
- `all.gd`: runner que encuentra todos los `tests/headless/*.gd`, corre `run.gd` primero y cada uno en su propio
  proceso; falla con código ≠ 0 o con `SCRIPT ERROR`/`Parse Error`/`Failed to load script`. Filtro `-- solo=a,b`.
  **Genérico**: solo cambian `DIR` y `FIRST`.
- `test_template.gd`: esqueleto de un test (`check`, archivo temporal, resumen en la última línea, código de salida).
- `test.ps1`: atajo de Windows (importa y corre `all.gd`; `-Solo wiki`).
- `tests.yml`: GitHub Actions (importar, `--check-only` de `tools/`, `all.gd`).

## `gut/` — GUT (TDv1/JuegoA)
- `tests.yml`: GitHub Actions con GUT; el paso final busca `SCRIPT ERROR|Parse Error|Failed to load script` en el
  registro porque GUT saltea sin avisar un test que no compila (D-030 de TDv1).
- `rules-tests.md`: las reglas de tests de TDv1 (`.claude/rules/tests.md`): costuras para no cambiar de escena,
  archivos de prueba, `assert_push_error`, casos de borde.
