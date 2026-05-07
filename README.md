# 🤖 AI Registry

**Your personal registry of AI skills and agents.** Instalable via terminal a nivel
usuario o proyecto. Compatible con OpenCode, Claude Code, Cursor, Gemini, y Copilot.

## Installación

```bash
# Clonar el repo
git clone <url> ~/ai-registry
cd ~/ai-registry

# Instalar TODO de una (skills + agentes + commands a nivel usuario para OpenCode)
./install.sh all

# O por partes
./install.sh skills           # Todos los skills
./install.sh agents           # Todos los agentes
./install.sh commands         # Todos los commands

# O uno por uno
./install.sh skill <name>
./install.sh agent <name>
./install.sh command <name>
```

## Niveles de instalación

| Flag | Destino | Ejemplo |
|------|---------|---------|
| `--user` (default) | `~/.config/opencode/...` | Skills del sistema |
| `--project` | `./skills/`, `./opencode.json` | Skills del proyecto |
| `--tool <tool>` | Especifica la tool | `opencode`, `claude`, `cursor`, `gemini`, `copilot` |

### Ejemplos

```bash
# Instalar skills a nivel proyecto para OpenCode
./install.sh skills --project

# Instalar un agente específico a nivel usuario
./install.sh agent mi-revisor --user

# Instalar skills para Claude Code
./install.sh skills --tool claude

# Instalar todo a nivel proyecto
./install.sh all --project
```

## Comandos

```bash
install.sh all                         # Instalar todo
install.sh skills                      # Todos los skills
install.sh agents                      # Todos los agentes
install.sh commands                    # Todos los commands
install.sh skill <nombre>              # Un skill específico
install.sh agent <nombre>              # Un agente específico
install.sh command <nombre>            # Un comando específico
install.sh ls                          # Listar disponible
install.sh create skill <nombre>       # Scaffold nuevo skill
install.sh create agent <nombre>       # Scaffold nuevo agente
install.sh create command <nombre>     # Scaffold nuevo comando
install.sh index                       # Regenerar index.json
install.sh --help                      # Ayuda
```

## Estructura del Registry

```
├── index.json          # Catálogo autogenerado de skills/agentes/commands
├── install.sh          # CLI — entry point
├── lib/
│   └── utils.sh        # Funciones compartidas (resolve, install, scaffold)
├── skills/             # Tus skills
│   ├── <nombre>/
│   │   ├── SKILL.md    # Skill instructions (formato Gentle AI)
│   │   ├── assets/     # Templates, schemas, ejemplos
│   │   └── references/ # Documentación local
│   └── ...
├── agents/             # Tus agentes
│   ├── <nombre>/
│   │   ├── AGENT.md    # Persona e instrucciones
│   │   └── opencode.json # Definición del agente (se inyecta en opencode.json)
│   └── ...
├── commands/           # Slash commands
│   ├── <nombre>/
│   │   └── COMMAND.md  # Definición del comando
│   └── ...
└── templates/          # Scaffolding
    ├── skill/
    ├── agent/
    └── command/
```

## Formato de Skills

Cada skill es un directorio con un `SKILL.md` que sigue el formato Gentle AI:

```yaml
---
name: mi-skill
description: >
  Descripción del skill.
  Trigger: Cuándo debe cargarse.
license: Apache-2.0
metadata:
  author: tu-nombre
  version: "1.0"
---
```

El `SKILL.md` debe incluir:
- **When to Use**: cuándo aplica
- **Critical Patterns**: las reglas más importantes (lo que inyecta el resolver)
- **Code Examples**: ejemplos mínimos y enfocados
- **Commands**: comandos comunes

## Formato de Agentes

Cada agente tiene:
- `AGENT.md` — persona, instrucciones y constraints
- `opencode.json` — definición del agente para OpenCode (se registra automáticamente al instalar)

```json
{
  "description": "Descripción del agente",
  "hidden": true,
  "mode": "subagent",
  "prompt": "Instrucciones completas del agente",
  "tools": {
    "bash": true,
    "edit": true,
    "read": true,
    "write": true
  }
}
```

## Skill Registry (integración con Gentle AI)

Este registry genera automáticamente un `index.json` con el catálogo completo.
Si usás el sistema SDD de Gentle AI, podés integrar estos skills ejecutando:

```bash
./install.sh index   # regenera index.json
```

Luego, el skill resolver de Gentle AI puede consumir este registry para
inyectar reglas compactas en sub-agentes.

## Roadmap (ideas)

- [ ] Soporte para dependencias entre skills
- [ ] `install.sh update` — actualizar skills instalados
- [ ] `install.sh remove <name>` — desinstalar
- [ ] Validación de sintaxis SKILL.md antes de instalar
- [ ] Perfiles de instalación (`--profile backend`, `--profile frontend`)
- [ ] Publicación como paquete (brew, npm, etc.)
