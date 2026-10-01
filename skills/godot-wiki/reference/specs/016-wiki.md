# 016 — Wiki del juego

**Estado:** Implementada (2026-10-01, a pedido del usuario; decisiones propias donde no se indica otra cosa) · **Depende de:** 004, 006, 007, 009, 012, 014

## Problema

El juego tiene docenas de enemigos, siete jefes, patronos y reglas (desgaste, armadura, empañado, guardia) que hoy solo se descubren jugando o leyendo specs. Hace falta una referencia dentro del juego que enseñe sin spoilear y que no se desactualice al sumar contenido.

## Principio (heredado de TDv1, D-035)

La pantalla es **genérica**: dibuja categorías → entradas → bloques y no sabe qué es un enemigo. Lo que sabe de enemigos, jefes, patronos, espadas y lugares está en `Wiki`, que arma las entradas **leyendo los Resources**. Sumar un `EnemyDefinition`, `BossDefinition`, `PatronDefinition` o `SwordCatalog` lo agrega solo; los números salen de los datos (constitución: escalabilidad por datos).

## Qué hay

| Categoría | Fuente | Se abre cuando… |
|---|---|---|
| **Enemigos** | `resources/enemies/*.tres` (sin los cuerpos de jefe) | el enemigo aparece en la sala donde Platero está |
| **Jefes** | `resources/bosses/*.tres` | se entra a su arena |
| **Patronos** | `PatronDefinition` de los arcos | Platero lo equipa por primera vez |
| **Espadas** | `SwordCatalog` | Platero la empuña |
| **Lugares** | arcos y etapas de la campaña | se entra al arco / etapa |
| **Guía** | `resources/wiki/articles/*.json` + «Controles» (leído del InputMap) | siempre |

- Una entrada **cerrada** muestra «???», el dibujo en silueta y un aviso; **no lleva ningún dato real** (ni nombre), así un error de la pantalla no puede filtrarlo.
- **Enemigos:** dibujo (primer cuadro de `idle`), tipo (volador, caminante, gas…), datos (vida, armadura, daño de contacto, velocidad, plata que suelta, dureza, si lo atraviesa la espada, si se lo puede aplastar), cómo enfrentarlo (según su arquetipo y sus banderas, más una nota propia) y **dónde aparece** (etapas).
- **Jefes:** fases y vida de cada una, armadura, frase de entrada, cómo vencerlo y dónde está.
- **Patronos / espadas:** descripción y datos (filo, daño, desgaste, penetración, alcance; cooldown de la habilidad).
- **Lugares:** arco con año, etapas (las no visitadas aparecen como «???»), jefes y patronos.
- **Guía:** la espada y el filo, la plata y el oficio, salto y caída, la guardia, daño y armadura, el Umbral, y el mundo (sin spoilers de la historia).
- **Textos escritos a mano** en `resources/wiki/notes.json` (nota y consejo por id) y artículos en `resources/wiki/articles/`; **no repiten números** que ya vivan en un Resource.
- **Dónde aparece** sale de `resources/wiki/appearances.json`, generado por `tools/build_wiki_index.gd` a partir de las salas; un test avisa si quedó desactualizado.

## Progreso (bestiario)

- Se guarda en `user://wiki_progress.json`, **aparte de la partida**: lo descubierto sobrevive a «Nueva partida».
- Se marca desde el juego (un solo gancho por tipo): `Enemy._ready`, `BossController._setup`, `PatronManager.equip`, `Player` al empuñar espada y `StageRunner.start`.
- Las pruebas automáticas no escriben el archivo (`SaveGame.enabled = false`).
- **Modo de pruebas (spec 014):** todo abierto y archivo propio.

## Acceso y pantalla

- Botón **Wiki** en el menú principal y en la pausa (solo lectura).
- Pantalla a 640×360: pestañas de categoría arriba, lista de entradas a la izquierda (con un contador abiertas/total y marca de cerradas) y detalle a la derecha con desplazamiento. `Esc` o «Volver» cierra.
- Ver el dibujo con la escala entera más grande que entre, con filtro *nearest*.

## Fuera de alcance (por ahora)

- Buscador y filtros; personajes y cameos (Hades, Heráclito…); ilustraciones de los finales; el bestiario por arco.

## Criterios de aceptación

- [x] **AC-016-1** `Wiki.categories()` devuelve Enemigos, Jefes, Patronos, Espadas, Lugares y Guía, cada una con todas las entradas de sus datos (ningún `.tres` de enemigo menor o jefe queda fuera).
- [x] **AC-016-2** Una entrada cerrada es `locked`, se titula «???» y su texto no contiene el nombre, ni ningún número, ni la nota del dato real.
- [x] **AC-016-3** Al ver a un enemigo en una sala, su entrada se abre; antes está cerrada. Igual para jefes (al entrar a la arena), patronos, espadas y lugares.
- [x] **AC-016-4** Los datos de cada entrada coinciden con su Resource (vida, armadura, daño, fases…) y cambian si el Resource cambia.
- [x] **AC-016-5** «Dónde aparece» lista las etapas reales y el test falla si `appearances.json` no coincide con las salas.
- [x] **AC-016-6** El progreso persiste en `wiki_progress.json`, sobrevive a una nueva partida y no se escribe cuando `SaveGame.enabled` es false.
- [x] **AC-016-7** En modo de pruebas todas las entradas están abiertas.
- [x] **AC-016-8** La pantalla abre desde el menú y la pausa, muestra categorías, lista y detalle, y cierra con `Esc`.
- [x] **AC-016-9** La entrada «Controles» refleja las teclas actuales del InputMap (spec 015).
- [x] **AC-016-10** Sumar un enemigo nuevo (un `.tres` en `resources/enemies/`) lo agrega a la wiki sin tocar otros archivos.

## Preguntas abiertas

1. ¿Buscador de texto (el `plain_text()` de cada entrada ya lo permite)?
2. ¿Ver las ilustraciones animadas (idle) en lugar del primer cuadro?
3. ¿Personajes y cameos como categoría propia, abiertos por escena?
