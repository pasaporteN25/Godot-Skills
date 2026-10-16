---
name: godot-mainline-export
description: 'Exporta y ejecuta builds de Godot para Windows, Android y Linux, siempre desde main o master; revisa presets y herramientas necesarias y explica cómo habilitar lo que falte.'
---

# Exportar builds Godot desde main o master

Usá esta skill cuando el usuario pida generar, actualizar, instalar o ejecutar un `.exe`, `.apk` o build nativo de Linux de un proyecto Godot.

## Fuente obligatoria

Los artefactos deben salir del contenido de `main` o `master` del repositorio en cuestión.

1. Localizá la raíz Git y el `project.godot` del proyecto correcto.
2. Revisá `git status`, la rama actual y el remoto predeterminado. Preferí `origin/main` o `origin/master` según la rama predeterminada del remoto. Si hay remoto y red disponible, corré `git fetch <remoto>` antes de elegir el commit. Si no hay remoto, usá una rama local `main` o `master` solo si existe.
3. Si la rama activa es otra, no exportes desde ella ni cambies de rama en el checkout del usuario. Usá un worktree temporal desde la referencia `main`/`master` elegida. Si hay cambios locales, preservalos intactos.
4. Si el `fetch` falla, no afirmes que la referencia local está al día. Informá el commit disponible y que no se pudo actualizar; pedile habilitar conexión al remoto o confirmar que acepta exportar desde esa referencia local de `main`/`master`.
5. Si no existe una referencia `main` o `master`, no uses la rama activa como sustituto. Explicale al usuario qué falta y cómo activar la rama principal, por ejemplo `git fetch origin` y `git switch main` (o `git switch master`) seguido de `git pull --ff-only`. Si el nombre de la rama principal es distinto, pedile que la identifique.
6. Informá qué referencia y commit se usaron. No hagas commits, pushes ni merges como parte de la exportación, salvo que el usuario los pida expresamente.

## Comprobaciones previas

Antes de exportar, verificá:

- Que el ejecutable de Godot esté disponible (`godot --version`). Si falta, indicá instalar la versión estándar compatible con el proyecto y agregar el ejecutable al `PATH`.
- Que `godot --version` corresponda a una versión compatible con `config/features` en `project.godot`.
- Que haya un preset para la plataforma en `export_presets.cfg`; respetá su nombre y opciones en vez de inventar otra configuración.
- Si no hay preset, explicá cómo crearlo desde **Project → Export → Add…**, elegir la plataforma y guardar `export_presets.cfg`.
- Que estén instaladas las plantillas de exportación que coinciden con la versión exacta de Godot. Si faltan, indicá: **Editor → Manage Export Templates → Download and Install**.
- Para Android: SDK, JDK y Android Build Tools compatibles, con rutas configuradas en **Editor → Editor Settings → Export → Android**. Comprobá también la configuración de firma. Para una build de prueba puede servir la firma debug; una APK de publicación requiere el keystore de release existente. No crees ni reemplaces claves de publicación.
- Para Windows o Linux: las plantillas de exportación para la versión instalada y un preset de escritorio utilizable.
- Para ejecutar una APK: `adb` y un dispositivo/emulador autorizado. Si no están disponibles, explicá cómo activar depuración USB y autorizar el equipo, o iniciar un emulador.

Si falta un componente, no intentes instalarlo ni modifiques rutas o secretos sin que el usuario lo pida. Decí qué falta, dónde se configura y el paso concreto para habilitarlo; luego continuá cuando esté disponible.

## Exportación y ejecución

- Usá el CLI de Godot con `--path` apuntando al worktree principal y el nombre exacto del preset. Ejemplo: `godot --headless --path <worktree> --export-release "Windows Desktop" <ruta-salida>`.
- Guardá el artefacto en la ruta pedida o copiá el resultado fuera del worktree temporal antes de limpiarlo. Eliminá únicamente el worktree temporal creado por esta ejecución y solo después de verificar la copia.
- Elegí debug o release de acuerdo con lo pedido y con la firma configurada. No anuncies éxito si el proceso termina con error aunque haya dejado un archivo parcial.
- Windows: un `.exe` se ejecuta en Windows. Linux: la exportación nativa de Godot produce el ejecutable Linux y, según el preset, un `.pck`; no la llames AppImage salvo que exista ese empaquetado adicional. Ejecutá Linux nativo en Linux; no intentes abrirlo como binario de Windows.
- Android: instalá la APK solo si el usuario pidió ejecutarla/instalarla y hay un dispositivo o emulador disponible. No confundas exportar con instalar.
- Al final comprobá código de salida, existencia, tamaño y fecha del artefacto. Informá plataforma, preset, tipo de firma cuando aplique, branch/commit fuente y cualquier advertencia que afecte el uso.

## Diagnóstico

Separá los errores del proyecto de los problemas de la máquina. Errores al acceder a certificados del sistema, SDK, keystore, plantillas, permisos de la carpeta de usuario o ajustes locales de Godot no demuestran por sí solos que el juego falle al exportar.

- Si el mensaje apunta a una ruta de SDK o Java, indicá la ruta que falta y dónde configurarla.
- Si falta un keystore de release, explicá cómo seleccionar el keystore y alias existentes en el preset de Android. No solicites que pegue contraseñas en el chat.
- Si Godot no puede guardar sus ajustes por permisos del perfil, sugerí ejecutar con el perfil de usuario correcto y permisos normales de escritura; no cambies permisos globales ni pidas ejecutar como administrador como solución genérica.
- Si el export reporta errores de scripts, recursos o configuración del proyecto, detenete en el primer error reproducible, describe el archivo o ajuste implicado y corrige solo lo necesario si el usuario pidió arreglarlo. Después repetí la exportación.
