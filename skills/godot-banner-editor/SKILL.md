---
name: godot-banner-editor
description: 'Diseña un editor cosmético pequeño de estandartes o emblemas para un juego Godot 4: acota formas y paletas, resuelve controles de mouse/touch, persistencia segura y pruebas antes de implementarlo.'
---

# Editor cosmético de estandartes en Godot 4

Usá esta skill cuando el juego necesite que una persona arme un estandarte con piezas visuales acotadas. El objetivo es que el resultado sea reconocible y fácil de guardar, no ofrecer dibujo libre ni convertir la pantalla en un editor de niveles.

## 1. Definí el alcance antes de programar

Primero inspeccioná el canon visual, la guía de arte, el sistema de UI, el guardado y los controles que ya tiene el juego. Escribí qué recurso visual se puede cambiar y dónde se muestra.

Decidí con la persona responsable, con recomendación concreta:

1. **Piezas editables:** fondo, borde, emblema central y, si el juego lo necesita, una cinta secundaria. Recomendá un conjunto pequeño de formas y emblemas dibujados por el equipo; no aceptes imágenes arbitrarias por omisión.
2. **Paleta:** ofrecé colores aprobados con nombre y muestra visible. Comprobá contraste entre fondo, emblema y borde en el tamaño final. Conservá una paleta base que siempre produzca una combinación válida.
3. **Propiedad del diseño:** separá emblemas del jugador, enemigos y facciones. Un editor cosmético del jugador no debería reemplazar automáticamente un símbolo narrativo o de equipo.
4. **Plataformas:** diseñá primero el flujo que el usuario pidió. Mouse y teclado necesitan foco y selección explícitos; touch necesita blancos amplios y controles que no dependan de hover. No infieras que el diseño desktop ya resuelve mobile.
5. **Guardado y uso:** decidí si el diseño se aplica a un solo estandarte o a todo el juego, si persiste entre sesiones y cómo vuelve a un diseño predeterminado.

Si estas decisiones cambian el progreso, el multijugador, el contenido compartido o el guardado de campaña, frená y documentá una spec antes de implementar. No inventes esos alcances.

## 2. Modelá una receta, no una imagen arbitraria

Representá el diseño como datos pequeños y validados: versión de esquema, ids de fondo/borde/emblema y colores elegidos de una lista permitida. Usá ids estables en vez de guardar rutas de recursos o nombres de nodos.

Preferí datos serializables simples cuando solo haya unas pocas opciones. Usá Resources tipados si el juego ya centraliza contenido de esa manera. La interfaz debe consumir un modelo de datos, no escribir directamente en una textura compartida.

Establecé límites de cantidad, ids y combinaciones válidas. Si se necesita una combinación inválida, mostrá una alternativa segura o rechazala con un mensaje breve. No guardes texto introducido, rutas de archivos o scripts ejecutables dentro del diseño.

## 3. Separá editor, vista previa y uso en partida

Implementá primero una vista previa que dibuje la receta con assets ya incluidos en el juego. Elegir una pieza o color debe actualizar solo la vista previa. Confirmar aplica el diseño; cancelar lo descarta.

Mantené el editor en una escena o componente separado del sistema de campaña. La partida debería recibir un diseño validado como dato explícito. Evitá que un nodo de decoración consulte un autoload de guardado o decida por su cuenta si la persona ya ganó.

Para mouse/teclado, cada opción debe tener nombre accesible, foco visible y una acción de confirmar/cancelar consistente con el resto del juego. Para touch, revisá tamaño de controles, desplazamiento y que el gesto de tocar una opción no active el control que queda debajo.

## 4. Persistí sin poner en riesgo el progreso

Guardá el diseño en preferencias de usuario o en un archivo propio, separado del guardado de campaña, salvo que el proyecto tenga una razón documentada para otra opción.

La carga debe tolerar archivo ausente, JSON inválido, versión desconocida, ids eliminados y valores fuera de rango. Ante un diseño inválido, cargá el predeterminado y preservá el resto de los datos del usuario. Versioná el esquema y definí qué campos se migran; no subas la versión general del guardado solo por una preferencia cosmética sin comprobar que sea necesario.

Ofrecé restaurar el diseño predeterminado y verificá que cancelar una edición no escriba el archivo.

## 5. Probá el contrato y la interacción

Agregá pruebas significativas para:

- receta predeterminada y cada combinación válida;
- rechazo de ids desconocidos, valores fuera de la paleta y archivos dañados;
- migración o fallback ante una versión antigua/desconocida;
- editar, previsualizar, cancelar, confirmar y restaurar;
- controles de teclado, mouse y touch para las plataformas incluidas;
- que el diseño cosmético nunca cambie progreso, estadísticas ni identidad de facción.

Capturá la vista previa en el tamaño de uso real y ampliada. Verificá contraste, silueta y legibilidad en fondos claros y oscuros, y probá una combinación con cada emblema. Corré la suite completa y documentá qué dispositivo físico no se pudo probar.

## 6. Cerrá la tarea con alcance claro

Actualizá las specs, decisiones, changelog y tablero del proyecto según corresponda. Registrá por separado lo que se validó en pruebas y lo que requiere revisión visual o una persona jugando. Mantené el skill genérico: las rutas, paletas y decisiones de un juego particular pertenecen al repositorio de ese juego, no acá.
