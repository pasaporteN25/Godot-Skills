# Instrucciones para agentes — Godot-Skills

## Propósito y formato

- Este repositorio mantiene skills reutilizables para proyectos Godot 4 y GDScript.
- `skills/<nombre>/SKILL.md` es la fuente de verdad del flujo de cada skill. Mantené sus instrucciones centradas en el trabajo y neutrales respecto del modelo o herramienta cuando sea posible.
- `.claude-plugin/` empaqueta y publica estas skills como plugin de Claude Code. Los archivos de `skills/<nombre>/agents/` son metadatos opcionales específicos de la herramienta indicada en su nombre; no dupliques ahí el flujo de trabajo de `SKILL.md`.
- Agregá referencias o scripts solo cuando resuelvan una necesidad concreta. Los detalles de un juego específico van en `reference/` y deben indicar su procedencia y qué partes no son genéricas.

## Al agregar o cambiar una skill

- Usá nombres de carpeta en minúsculas con guiones, iguales al campo `name` del frontmatter.
- Mantené `description` breve y entre comillas simples para evitar errores de YAML con `: `.
- Actualizá la tabla, el orden recomendado y el comando de instalación manual en `README.md` cuando corresponda.
- Mantené sincronizados los números de versión y la descripción del plugin en `.claude-plugin/plugin.json` y `.claude-plugin/marketplace.json`.
- Antes de publicar, validá el formato de las skills y ejecutá `claude plugin validate .` cuando Claude CLI esté disponible. Informá cualquier validador que no se haya podido ejecutar.
- Revisá que la documentación de Android e iOS siga siendo correcta; no presentes requisitos de una plataforma como disponibles si no lo están.

## Alcance y seguridad

- No conviertas un detalle de un juego concreto en una regla general sin comprobar que aplica a otros proyectos Godot.
- No incluyas credenciales, keystores, contraseñas ni datos personales en las skills, ejemplos o referencias.
- Cada rama o PR debe mantener el cambio acotado a las skills y documentación de este repositorio.
