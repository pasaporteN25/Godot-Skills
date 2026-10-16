---
name: godot-project-onboarding
description: 'Revisa y prepara una computadora y un proyecto Godot para empezar a trabajar; úsala primero al configurar una máquina nueva o antes de exportar por primera vez.'
---

# Preparar el entorno de Godot

Usá esta skill para el onboarding de una computadora o proyecto Godot. La meta es que la persona pueda abrir y correr el proyecto y sepa qué falta para probar o exportar en cada plataforma.

## Procedimiento

1. Detectá el sistema operativo, la raíz del repositorio y la instalación disponible de Godot. Revisá `project.godot`, `export_presets.cfg` y la documentación del proyecto (`ONBOARDING.md`, `README.md` o equivalente). La guía del repositorio manda para sus versiones, comandos y particularidades.
2. Comprobá la versión de Godot y comparala con `config/features` y las indicaciones del proyecto. Detectá si requiere Godot .NET o la versión estándar. No supongas rutas de instalación: localizá el ejecutable y preguntá por una ubicación alternativa si no está en el `PATH`.
3. Presentá un checklist breve con estado **Listo**, **Falta configurar** o **No aplica** para: abrir el editor, importar y correr el juego, ejecutar la verificación documentada, exportar escritorio y exportar/probar Android. Separá los requisitos de desarrollo de los que solo hacen falta para exportar.
4. Para cada faltante, indicá el componente, la versión o ruta esperada, dónde se configura y pasos concretos para habilitarlo. Usá la documentación oficial de Godot y de la plataforma; explicá las diferencias entre Windows, Linux y macOS cuando cambien los pasos.
5. Verificá únicamente comandos de disponibilidad y configuración que sean seguros. No instales herramientas, cambies el `PATH`, edites ajustes globales, descargues SDKs ni modifiques firmas sin que la persona lo haya pedido. Nunca solicites contraseñas de keystore o certificados en el chat.
6. Para validar la apertura del proyecto, seguí el comando de importación o arranque de su documentación. Corré la suite de tests solo cuando la persona lo pida; dejá el comando exacto como siguiente paso si el onboarding la recomienda.
7. Para exportar un artefacto, continuá con `godot-mainline-export` cuando esté disponible. Esa skill fija la referencia `main`/`master` y verifica los requisitos específicos de exportación; no exportes desde una rama feature.

## Android y pruebas móviles

Recomendá instalar Android Studio y configurar al menos un dispositivo virtual (AVD) para probar la interfaz móvil sin depender de un teléfono físico. Android Studio facilita instalar el Android SDK y crear el emulador. La exportación Godot también necesita un JDK compatible, herramientas de plataforma y rutas de SDK/JDK configuradas en los ajustes del editor. Comprobá las versiones exigidas por el proyecto y la documentación estable actual de Godot, en vez de fijar versiones viejas en esta skill.

Para probar en un teléfono físico, explicá cómo activar depuración USB, conectar el dispositivo y autorizar esta computadora. Comprobá `adb devices` cuando `adb` esté disponible. No instales la APK ni cambies firmas o datos existentes sin que la persona lo haya pedido.

## iOS

Godot requiere una computadora con macOS y Xcode instalado para exportar a iOS. Si la máquina actual es Windows o Linux, marcá exportación y prueba iOS como **No disponible en este entorno** y explicá el requisito. No presentes una alternativa remota o un workaround como si ya estuviera soportado. Si el repositorio define otro flujo, seguí su documentación e indicá qué depende de Mac/Xcode.

## Cierre

Informá qué quedó listo, qué pasos se completaron, qué no se probó y los siguientes pasos concretos. No afirmes que una plataforma está lista solo porque Godot abre: distinguí ejecución en editor, exportación, instalación y prueba real en dispositivo.
