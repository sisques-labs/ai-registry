---
name: example-skill
description: >
  Example skill demonstrating the registry skill format.
  Trigger: When working with example patterns or learning the skill system.
license: Apache-2.0
metadata:
  author: sisques-labs
  version: "1.0"
---

## When to Use

- When you need a reference for how skills are structured
- As a template for creating new skills
- To understand the SKILL.md frontmatter format

## Critical Patterns

- Frontmatter MUST include: name, description (with Trigger:), license, metadata.author, metadata.version
- Description field MUST contain "Trigger:" keywords for the skill resolver
- Keep Critical Patterns concise — 5-15 compact rules max
- Use `assets/` for code templates, `references/` for local docs

## Structure

```
skills/{skill-name}/
├── SKILL.md       # Required — main skill file
├── assets/        # Optional — templates, schemas, examples
└── references/    # Optional — links to local documentation
```

## Code Examples

```bash
# Create a new skill
./install.sh create skill my-awesome-skill

# Install it
./install.sh skill my-awesome-skill --user

# List available
./install.sh ls
```

## Commands

```bash
./install.sh create skill <name>   # Scaffold a new skill
./install.sh skill <name>          # Install a skill
./install.sh ls                    # List available
```

## Resources

- **Templates**: See [templates/skill/](../../templates/skill/) for scaffolding
- **Skill Creator**: See [skill-creator](https://github.com/gentleman-programming/skills) for official spec
