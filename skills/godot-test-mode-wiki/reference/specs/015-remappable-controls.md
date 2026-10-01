# 015 — Controles remapeables

**Estado:** Implementada (2026-10-01) · **Depende de:** 002, 014

## Problema

La constitución y la spec 002 prometen teclas remapeables, pero el juego solo tenía un texto con las teclas fijas. Además el modo de pruebas (spec 014) suma atajos propios que también tienen que poder cambiarse.

## Reglas

1. **Una sola pantalla «Controles»**, desde el menú principal y desde la pausa. Lista todas las acciones del juego con **dos teclas** y **un botón de mando** cada una (Mover, Saltar, Espada, Guardia, Pluma, Yunque, Pulir, Patrono, Interactuar, Pausa).
2. **Cambiar** = clic en la casilla y apretar la tecla o botón nuevo. `Esc` cancela; `Supr`/`Retroceso` vacía la casilla. Los modificadores solos (Shift, Ctrl, Alt) no valen.
3. **Posición física:** las teclas se guardan por posición (WASD sigue siendo WASD en un teclado AZERTY o español).
4. **Conflictos:** si la tecla ya la usa otra acción, **intercambian** (la otra recibe la que esta tenía). Una acción del juego **nunca queda sin ningún control**: si el cambio la dejaría vacía, se rechaza con un mensaje.
5. **Los ejes del stick no se remapean** y se conservan; el D-pad y los botones sí.
6. **Efecto inmediato** (el InputMap cambia al instante) y **guardado** en `user://input_bindings.json`; solo se guarda lo que difiere de fábrica. El modo de pruebas usa `input_bindings_pruebas.json`.
7. **Restaurar** una acción (↺) o todas.
8. **Archivo ilegible** (dañado, otra versión, acciones desconocidas, valores que no son números): se ignora y rigen los valores de fábrica.
9. **Atajos del modo de pruebas** (spec 014): se agregan a la misma pantalla como acciones opcionales (pueden quedar vacías) solo cuando el modo está activo.

## Fuera de alcance

- Combinaciones con modificador (Ctrl+tecla), perfiles múltiples, remapeo de ejes analógicos y de la rueda/mouse.
- Textos en otros idiomas.

## Criterios de aceptación

- [x] **AC-015-1** La pantalla lista las 11 acciones del juego, cada una con 2 teclas y 1 botón de mando, y se abre desde el menú principal y desde la pausa.
- [x] **AC-015-2** Cambiar una tecla o un botón se aplica al instante en el InputMap y se guarda; el archivo contiene solo las acciones modificadas.
- [x] **AC-015-3** Una tecla usada por otra acción se intercambia; si la otra acción quedaría sin control, el cambio se rechaza.
- [x] **AC-015-4** Las teclas se guardan por posición física.
- [x] **AC-015-5** Restaurar una acción o todas devuelve los valores de fábrica y el archivo queda sin diferencias.
- [x] **AC-015-6** Un archivo dañado, de otra versión o con datos inválidos no rompe nada: rigen los valores de fábrica.
- [x] **AC-015-7** Con el modo de pruebas activo, sus atajos `test_*` aparecen en la pantalla y se guardan en su propio archivo; sin él, no existen.
- [x] **AC-015-8** Mientras se espera una tecla, `Esc` cancela la captura sin cerrar la pantalla ni la pausa.
- [x] **AC-015-9** Los ejes del stick de las acciones de movimiento se conservan tras cualquier cambio.
