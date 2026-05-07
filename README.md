# AI Registry

**Your personal registry of AI skills and agents.** Installable via terminal at user or
project level. Compatible with **OpenCode**, **Claude Code**, **Cursor**, **Gemini**, and **Copilot**.

## Quick Install (one-liner)

```bash
# Install everything at user level (default)
curl -fsSL https://raw.githubusercontent.com/sisques-labs/ai-registry/main/bootstrap.sh | bash

# Install at project level
curl -fsSL https://raw.githubusercontent.com/sisques-labs/ai-registry/main/bootstrap.sh | bash -s -- --project

# Install for a specific tool
curl -fsSL https://raw.githubusercontent.com/sisques-labs/ai-registry/main/bootstrap.sh | bash -s -- --tool claude
```

## Manual Installation

```bash
# Clone the repo
git clone https://github.com/sisques-labs/ai-registry.git ~/ai-registry
cd ~/ai-registry

# Install EVERYTHING at once (skills + agents + commands at user level for OpenCode)
./install.sh all

# Or by category
./install.sh skills           # All skills
./install.sh agents           # All agents
./install.sh commands         # All commands

# Or individually
./install.sh skill <name>
./install.sh agent <name>
./install.sh command <name>
```

## Installation Levels

| Flag | Target | Example |
|------|--------|---------|
| `--user` (default) | `~/.config/opencode/...` | System-wide skills |
| `--project` | `./skills/`, `./opencode.json` | Project-level skills |
| `--tool <tool>` | Specific tool config | `opencode`, `claude`, `cursor`, `gemini`, `copilot` |

### Examples

```bash
# Install skills at project level for OpenCode
./install.sh skills --project

# Install a specific agent at user level
./install.sh agent my-reviewer --user

# Install skills for Claude Code
./install.sh skills --tool claude

# Install everything at project level
./install.sh all --project
```

## Commands

```bash
install.sh all                         # Install everything
install.sh skills                      # All skills
install.sh agents                      # All agents
install.sh commands                    # All commands
install.sh skill <name>               # A specific skill
install.sh agent <name>               # A specific agent
install.sh command <name>             # A specific command
install.sh ls                          # List available items
install.sh create skill <name>        # Scaffold a new skill
install.sh create agent <name>        # Scaffold a new agent
install.sh create command <name>      # Scaffold a new command
install.sh index                       # Regenerate index.json
install.sh --help                      # Show help
```

## Registry Structure

```
├── index.json          # Auto-generated catalog of skills/agents/commands
├── install.sh          # CLI — entry point
├── lib/
│   └── utils.sh        # Shared functions (resolve, install, scaffold)
├── skills/             # Your skills
│   ├── <name>/
│   │   ├── SKILL.md    # Skill instructions (Gentle AI format)
│   │   ├── assets/     # Templates, schemas, examples
│   │   └── references/ # Local documentation
│   └── ...
├── agents/             # Your agents
│   ├── <name>/
│   │   ├── AGENT.md    # Persona and instructions
│   │   └── opencode.json # Agent definition (injected into opencode.json)
│   └── ...
├── commands/           # Slash commands
│   ├── <name>/
│   │   └── COMMAND.md  # Command definition
│   └── ...
└── templates/          # Scaffolding
    ├── skill/
    ├── agent/
    └── command/
```

## Skill Format

Each skill is a directory with a `SKILL.md` following the Gentle AI format:

```yaml
---
name: my-skill
description: >
  Description of the skill.
  Trigger: When the AI should load this skill.
license: Apache-2.0
metadata:
  author: your-name
  version: "1.0"
---
```

The `SKILL.md` must include:
- **When to Use**: when the skill applies
- **Critical Patterns**: the most important rules (what the resolver injects)
- **Code Examples**: minimal, focused examples
- **Commands**: common commands

## Agent Format

Each agent has:
- `AGENT.md` — persona, instructions, and constraints
- `opencode.json` — agent definition for OpenCode (auto-registered on install)

```json
{
  "description": "Agent description",
  "hidden": true,
  "mode": "subagent",
  "prompt": "Full agent instructions",
  "tools": {
    "bash": true,
    "edit": true,
    "read": true,
    "write": true
  }
}
```

## Skill Registry (Gentle AI integration)

This registry auto-generates an `index.json` with the full catalog.
If you use the Gentle AI SDD system, integrate these skills by running:

```bash
./install.sh index   # regenerates index.json
```

The Gentle AI skill resolver can then consume this registry to inject compact rules into sub-agents.

## Publishing & Distribution

This registry is designed to work across all your projects. Here are the available distribution methods:

### 1. One-liner curl (recommended for quick setup)

```bash
curl -fsSL https://raw.githubusercontent.com/sisques-labs/ai-registry/main/bootstrap.sh | bash
```

Clones the repo, runs the installer, cleans up. No leftovers.

### 2. Git clone (recommended for development)

```bash
git clone https://github.com/sisques-labs/ai-registry.git ~/ai-registry
cd ~/ai-registry
./install.sh all --project  # install into your current project
```

Keeps the registry locally so you can update with `git pull`.

### 3. npm / GitHub Packages (planned)

Published as `@sisques-labs/ai-registry` to GitHub Packages:

```bash
# Future
npx @sisques-labs/ai-registry install --project
```

### 4. GitHub template repo

Fork or use this repo as a template to create your own skills registry.
Enable "Template repository" in your GitHub repo settings.

### 5. Git submodule

Add to any project for direct reference:

```bash
git submodule add https://github.com/sisques-labs/ai-registry.git .ai-registry
.ai-registry/install.sh all --project
```

### 6. GitHub Actions auto-deploy

On every push to `main`, the registry can auto-deploy to npm and
create a GitHub Release with the one-liner install command.

## Roadmap

- [ ] Skill dependency support
- [ ] `install.sh update` — update installed skills
- [ ] `install.sh remove <name>` — uninstall
- [ ] `SKILL.md` syntax validation before install
- [ ] Installation profiles (`--profile backend`, `--profile frontend`)
- [ ] Package distribution (brew, npm, etc.)
