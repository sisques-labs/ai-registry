#!/usr/bin/env bash
# =============================================================================
# ai-registry — lib/utils.sh
# Shared utility functions for the registry CLI.
# =============================================================================

set -euo pipefail

# --- Colors ---
RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

log_info()  { printf "${BLUE}ℹ${RESET}  %s\n" "$*"; }
log_ok()    { printf "${GREEN}✓${RESET}  %s\n" "$*"; }
log_warn()  { printf "${YELLOW}⚠${RESET}  %s\n" "$*"; }
log_error() { printf "${RED}✗${RESET}  %s\n" "$*" >&2; }
log_step()  { printf "\n${CYAN}==>${RESET} ${BOLD}%s${RESET}\n" "$*"; }

# --- Resolve the registry root (where this script lives) ---
registry_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# --- Resolve install targets based on level ---
# Usage: resolve_targets <type> <level> <tool>
#   type: skill|agent|command
#   level: user|project
#   tool: opencode (default) | claude | cursor | etc.
# Output: prints the target directory path
resolve_target_dir() {
  local type="$1"
  local level="${2:-user}"
  local tool="${3:-opencode}"

  case "$tool" in
    opencode)
      case "$level" in
        user)   echo "$HOME/.config/opencode/$type"s ;;
        project) echo "$(pwd)/$type"s ;;
      esac
      ;;
    claude)
      case "$level" in
        user)   echo "$HOME/.claude/$type"s ;;
        project) echo "$(pwd)/.claude/$type"s ;;
      esac
      ;;
    cursor)
      case "$level" in
        user)   echo "$HOME/.cursor/$type"s ;;
        project) echo "$(pwd)/.cursor/$type"s ;;
      esac
      ;;
    gemini)
      case "$level" in
        user)   echo "$HOME/.gemini/$type"s ;;
        project) echo "$(pwd)/.gemini/$type"s ;;
      esac
      ;;
    copilot)
      case "$level" in
        user)   echo "$HOME/.copilot/$type"s ;;
        project) echo "$(pwd)/.copilot/$type"s ;;
      esac
      ;;
    *)
      log_error "Unknown tool: $tool. Supported: opencode, claude, cursor, gemini, copilot"
      return 1
      ;;
  esac
}

# --- Resolve the opencode.json path for agent registration ---
resolve_opencode_json() {
  local level="${1:-user}"
  case "$level" in
    user)    echo "$HOME/.config/opencode/opencode.json" ;;
    project) echo "$(pwd)/opencode.json" ;;
  esac
}

# --- Install a skill directory ---
# Copies a skill dir into the target skills directory
install_skill() {
  local skill_name="$1"
  local target_dir="$2"
  local registry_root="$3"

  local source="$registry_root/skills/$skill_name"
  local target="$target_dir/$skill_name"

  if [ ! -d "$source" ]; then
    log_error "Skill '$skill_name' not found in registry/skills/"
    return 1
  fi

  mkdir -p "$target_dir"
  cp -R "$source/" "$target/"
  log_ok "Skill '$skill_name' installed → $target"
}

# --- Install all skills ---
install_all_skills() {
  local target_dir="$1"
  local registry_root="$2"
  local count=0

  mkdir -p "$target_dir"
  for skill_dir in "$registry_root/skills"/*/; do
    local name
    name="$(basename "$skill_dir")"
    [ "$name" = "index.json" ] && continue
    [ "$name" = "_shared" ] && continue
    install_skill "$name" "$target_dir" "$registry_root"
    count=$((count + 1))
  done

  log_ok "Installed $count skill(s) to $target_dir"
}

# --- Install an agent (copy files + register in opencode.json) ---
install_agent() {
  local agent_name="$1"
  local target_dir="$2"
  local opencode_json="$3"
  local registry_root="$4"

  local source="$registry_root/agents/$agent_name"
  local target="$target_dir/$agent_name"

  if [ ! -d "$source" ]; then
    log_error "Agent '$agent_name' not found in registry/agents/"
    return 1
  fi

  # Copy agent files
  mkdir -p "$target_dir"
  cp -R "$source/" "$target/"
  log_ok "Agent '$agent_name' files installed → $target"

  # Register agent in opencode.json if we have a definition snippet
  local def_snippet="$source/opencode.json"
  if [ -f "$def_snippet" ]; then
    register_agent_in_opencode "$agent_name" "$def_snippet" "$opencode_json"
  fi
}

# --- Register an agent definition in opencode.json ---
register_agent_in_opencode() {
  local agent_name="$1"
  local snippet="$2"
  local opencode_json="$3"

  if [ ! -f "$opencode_json" ]; then
    log_warn "No opencode.json found at $opencode_json — skipping agent registration"
    log_info "Create it manually or run 'install.sh init' to bootstrap"
    return 0
  fi

  # Check if agent already exists
  if grep -q "\"$agent_name\"" "$opencode_json" 2>/dev/null; then
    log_warn "Agent '$agent_name' already exists in $opencode_json — skipping registration"
    return 0
  fi

  # Read the snippet and inject it
  local snippet_content
  snippet_content="$(cat "$snippet")"

  # Inject into the "agent" object before the last closing brace of the agents block
  # Uses python3 for reliable JSON manipulation
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys

with open('$opencode_json', 'r') as f:
    config = json.load(f)

with open('$snippet', 'r') as f:
    agent_def = json.load(f)

if 'agent' not in config:
    config['agent'] = {}

if '$agent_name' in config['agent']:
    print('duplicate')
    sys.exit(0)

config['agent']['$agent_name'] = agent_def

with open('$opencode_json', 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')

print('ok')
" && log_ok "Agent '$agent_name' registered in $opencode_json" || {
      log_warn "Could not automatically register agent — JSON manipulation failed"
      log_info "Manually add the agent definition from: $snippet"
      return 1
    }
  else
    log_warn "python3 not found — cannot auto-register agent in opencode.json"
    log_info "Manually add the agent definition from: $snippet"
    return 1
  fi
}

# --- Install all agents ---
install_all_agents() {
  local target_dir="$1"
  local opencode_json="$2"
  local registry_root="$3"
  local count=0

  mkdir -p "$target_dir"
  for agent_dir in "$registry_root/agents"/*/; do
    local name
    name="$(basename "$agent_dir")"
    [ "$name" = "index.json" ] && continue
    install_agent "$name" "$target_dir" "$opencode_json" "$registry_root"
    count=$((count + 1))
  done

  log_ok "Installed $count agent(s) to $target_dir"
}

# --- Install a command ---
install_command() {
  local cmd_name="$1"
  local target_dir="$2"
  local registry_root="$3"

  local source="$registry_root/commands/$cmd_name"
  local target="$target_dir/$cmd_name.md"

  if [ ! -d "$source" ]; then
    # Try as a flat .md file
    if [ -f "$registry_root/commands/$cmd_name.md" ]; then
      source="$registry_root/commands/$cmd_name.md"
      target="$target_dir/$cmd_name.md"
    else
      log_error "Command '$cmd_name' not found in registry/commands/"
      return 1
    fi
  fi

  mkdir -p "$target_dir"

  if [ -d "$source" ]; then
    # Directory-based command (may have assets)
    cp -R "$source/" "${target_dir}/${cmd_name}/"
    log_ok "Command '$cmd_name' installed → ${target_dir}/${cmd_name}/"
  else
    cp "$source" "$target"
    log_ok "Command '$cmd_name' installed → $target"
  fi
}

# --- Install all commands ---
install_all_commands() {
  local target_dir="$1"
  local registry_root="$2"
  local count=0

  mkdir -p "$target_dir"
  for cmd_dir in "$registry_root/commands"/*/; do
    local name
    name="$(basename "$cmd_dir")"
    [ "$name" = "index.json" ] && continue
    install_command "$name" "$target_dir" "$registry_root"
    count=$((count + 1))
  done

  # Also check for flat .md files at root level
  for cmd_file in "$registry_root/commands"/*.md; do
    [ -f "$cmd_file" ] || continue
    local name
    name="$(basename "$cmd_file" .md)"
    [ "$name" = "index" ] && continue
    # Check if there's already a directory for it
    [ -d "$registry_root/commands/$name" ] && continue
    cp "$cmd_file" "$target_dir/"
    log_ok "Command '$name' installed → $target_dir/$name.md"
    count=$((count + 1))
  done

  log_ok "Installed $count command(s) to $target_dir"
}

# --- Generate index.json automatically ---
generate_index() {
  local registry_root="$1"

  log_step "Generating index.json..."

  if ! command -v python3 &>/dev/null; then
    log_warn "python3 not found — cannot auto-generate index.json"
    return 1
  fi

  python3 -c "
import json, os, re

registry = os.path.dirname(os.path.abspath('$registry_root'))
# resolve properly
registry = os.path.abspath('$registry_root')

def read_frontmatter(path):
    \"\"\"Read YAML-like frontmatter from a markdown file.
    
    Strategy: try Python's yaml module first (best), fall back to a
    custom parser that handles the subset used by Gentle AI skills:
      - Simple key: value
      - Multiline folded (>)
      - Nested mappings (metadata:)
      - Quoted values
    \"\"\"
    try:
        with open(path, 'r') as f:
            content = f.read()
    except:
        return {}

    if not content.startswith('---'):
        return {}

    parts = content.split('---', 2)
    if len(parts) < 3:
        return {}

    yaml_block = parts[1]

    # Strategy 1: try yaml module
    try:
        import yaml
        parsed = yaml.safe_load(yaml_block)
        if isinstance(parsed, dict):
            flat = {}
            def flatten(obj, prefix=''):
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        fq = f\"{prefix}.{k}\" if prefix else k
                        if isinstance(v, dict):
                            flatten(v, fq)
                        else:
                            flat[fq] = v
                elif obj is not None:
                    flat[prefix] = str(obj)
            flatten(parsed)
            return flat
    except ImportError:
        pass

    # Strategy 2: fallback parser for our subset
    lines = yaml_block.split('\\n')
    result = {}

    # Returns (nesting_level, key, value, is_parent)
    # where is_parent means it introduces children (like metadata:)
    def parse_line(line):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            return None
        if ':' not in stripped:
            return None
        indent = len(line) - len(line.lstrip())
        colon = stripped.index(':')
        key = stripped[:colon].rstrip()
        val = stripped[colon + 1:].strip()
        is_parent = (val == '' or val in ('>', '|', '>-', '|-', '>+', '|+'))
        return (indent, key, val, is_parent)

    # First pass: build indent structure and identify parent/leaf nodes
    parsed_lines = []
    for line in lines:
        info = parse_line(line)
        if info:
            parsed_lines.append(info)

    # Determine if a line has children by checking next line's indent
    has_children = [False] * len(parsed_lines)
    for idx, (indent, _, _, _) in enumerate(parsed_lines):
        if idx + 1 < len(parsed_lines):
            next_indent = parsed_lines[idx + 1][0]
            has_children[idx] = next_indent > indent

    # Second pass: collect folded content for parent nodes
    folded_content = {}
    for idx, (indent, key, val, is_parent) in enumerate(parsed_lines):
        if has_children[idx]:
            # Collect all lines at higher indent until next same-or-less indent
            lines_folded = []
            j = idx + 1
            while j < len(lines):
                raw_line = lines[j]
                if not raw_line.strip():
                    j += 1
                    continue
                line_indent = len(raw_line) - len(raw_line.lstrip())
                if line_indent <= indent:
                    break
                # Check if this line is a key:value pair at a deeper indent
                deeper = parse_line(raw_line)
                if deeper and deeper[0] > indent:
                    # This is a sub-key, stop collecting
                    break
                lines_folded.append(raw_line.strip())
                j += 1
            if lines_folded:
                folded_content[idx] = ' '.join(lines_folded)

    # Build the result
    # Track the active parent chain
    parent_stack = []  # (indent, prefix)

    for idx, (indent, key, val, is_parent) in enumerate(parsed_lines):
        # Pop parent stack
        while parent_stack and parent_stack[-1][0] >= indent:
            parent_stack.pop()

        prefix = parent_stack[-1][1] + '.' if parent_stack else ''
        qualified = prefix + key

        if has_children[idx]:
            # This is a parent node (nested mapping)
            parent_stack.append((indent, qualified))
        elif folded_content.get(idx):
            result[qualified] = folded_content[idx]
        else:
            # Scalar value
            result[qualified] = val.strip('\"').strip(\"'\")

    return result

def collect_skills(base):
    items = []
    skills_dir = os.path.join(base, 'skills')
    if not os.path.isdir(skills_dir):
        return items
    for entry in sorted(os.listdir(skills_dir)):
        entry_path = os.path.join(skills_dir, entry)
        if not os.path.isdir(entry_path) or entry == '__pycache__':
            continue
        skill_md = os.path.join(entry_path, 'SKILL.md')
        meta = read_frontmatter(skill_md) if os.path.exists(skill_md) else {}
        items.append({
            'name': entry,
            'type': 'skill',
            'description': meta.get('description', ''),
            'author': meta.get('metadata.author', ''),
            'version': meta.get('metadata.version', ''),
        })
    return items

def collect_agents(base):
    items = []
    agents_dir = os.path.join(base, 'agents')
    if not os.path.isdir(agents_dir):
        return items
    for entry in sorted(os.listdir(agents_dir)):
        entry_path = os.path.join(agents_dir, entry)
        if not os.path.isdir(entry_path) or entry == '__pycache__':
            continue
        agent_md = os.path.join(entry_path, 'AGENT.md')
        meta = read_frontmatter(agent_md) if os.path.exists(agent_md) else {}
        items.append({
            'name': entry,
            'type': 'agent',
            'description': meta.get('description', ''),
            'author': meta.get('metadata.author', ''),
            'version': meta.get('metadata.version', ''),
        })
    return items

def collect_commands(base):
    items = []
    cmds_dir = os.path.join(base, 'commands')
    if not os.path.isdir(cmds_dir):
        return items
    for entry in sorted(os.listdir(cmds_dir)):
        entry_path = os.path.join(cmds_dir, entry)
        if entry == 'index.json':
            continue
        if os.path.isdir(entry_path):
            cmd_md = os.path.join(entry_path, 'COMMAND.md')
            meta = read_frontmatter(cmd_md) if os.path.exists(cmd_md) else {}
            items.append({
                'name': entry,
                'type': 'command',
                'description': meta.get('description', ''),
            })
        elif entry.endswith('.md'):
            meta = read_frontmatter(entry_path)
            items.append({
                'name': entry[:-3],
                'type': 'command',
                'description': meta.get('description', ''),
            })
    return items

base = os.path.abspath('$registry_root')
index = {
    'name': os.path.basename(base),
    'description': 'AI Skills & Agents Registry',
    'skills': collect_skills(base),
    'agents': collect_agents(base),
    'commands': collect_commands(base),
}

index_path = os.path.join(base, 'index.json')
with open(index_path, 'w') as f:
    json.dump(index, f, indent=2, ensure_ascii=False)
    f.write('\n')

total = len(index['skills']) + len(index['agents']) + len(index['commands'])
print(f'  Skills: {len(index[\"skills\"])}, Agents: {len(index[\"agents\"])}, Commands: {len(index[\"commands\"])} (total: {total})')
" && log_ok "index.json regenerated" || log_error "Failed to generate index.json"
}

# --- Scaffold a new skill ---
scaffold_skill() {
  local name="$1"
  local registry_root="$2"
  local target="$registry_root/skills/$name"

  if [ -d "$target" ]; then
    log_error "Skill '$name' already exists"
    return 1
  fi

  mkdir -p "$target/assets" "$target/references"

  cat > "$target/SKILL.md" << SKILLMD
---
name: $name
description: >
  {One-line description of what this skill does}.
  Trigger: {When the AI should load this skill}.
license: Apache-2.0
metadata:
  author: $(git config user.name 2>/dev/null || echo "your-name")
  version: "1.0"
---

## When to Use

{Bullet points of when to use this skill}

## Critical Patterns

{The most important rules — what AI MUST know}

## Code Examples

\`\`\`{language}
{Minimal, focused examples}
\`\`\`

## Commands

\`\`\`bash
{Common commands}
\`\`\`

## Resources

- **Templates**: See [assets/](assets/) for {description}
- **Documentation**: See [references/](references/) for local docs
SKILLMD

  log_ok "Skill '$name' scaffolded → skills/$name/"
  log_info "Edit skills/$name/SKILL.md with your rules"
}

# --- Scaffold a new agent ---
scaffold_agent() {
  local name="$1"
  local registry_root="$2"
  local target="$registry_root/agents/$name"

  if [ -d "$target" ]; then
    log_error "Agent '$name' already exists"
    return 1
  fi

  mkdir -p "$target"

  cat > "$target/AGENT.md" << AGENTMD
---
name: $name
description: >
  {One-line description of what this agent does}.
license: Apache-2.0
metadata:
  author: $(git config user.name 2>/dev/null || echo "your-name")
  version: "1.0"
---

## Persona

{Describe the agent's personality, tone, and expertise}

## Instructions

{Detailed instructions for the agent}

## Constraints

- {What the agent should NOT do}
AGENTMD

  cat > "$target/opencode.json" << 'OPCDJSON'
{
  "description": "{One-line description for the agent}",
  "hidden": true,
  "mode": "subagent",
  "prompt": "{Instructions for the agent}",
  "tools": {
    "bash": true,
    "edit": true,
    "read": true,
    "write": true
  }
}
OPCDJSON

  log_ok "Agent '$name' scaffolded → agents/$name/"
  log_info "Edit agents/$name/AGENT.md and agents/$name/opencode.json"
}

# --- Scaffold a new command ---
scaffold_command() {
  local name="$1"
  local registry_root="$2"
  local target="$registry_root/commands/$name"

  if [ -d "$target" ]; then
    log_error "Command '$name' already exists"
    return 1
  fi

  mkdir -p "$target"

  cat > "$target/COMMAND.md" << CMDMD
---
description: "{One-line description of what the command does}"
agent: {agent-name}
---

{Instructions for the command. This is what the orchestrator runs when the slash command is invoked.}

## Workflow

1. {Step 1}
2. {Step 2}
3. {Step 3}

## Context

- Working directory: \$PWD
CMDMD

  log_ok "Command '$name' scaffolded → commands/$name/"
  log_info "Edit commands/$name/COMMAND.md"
}

# --- List what's available in the registry ---
list_registry() {
  local registry_root="$1"

  log_step "Registry: $(basename "$registry_root")"

  if [ -f "$registry_root/index.json" ]; then
    python3 -c "
import json
with open('$registry_root/index.json') as f:
    idx = json.load(f)

def print_group(title, items):
    if not items:
        return
    print(f'\n  ${BOLD}{title}${RESET}:')
    for item in items:
        desc = item.get('description', '')[:80]
        desc = desc.replace('{', '').replace('}', '')
        if desc:
            print(f'    ${CYAN}{item[\"name\"]}${RESET}  —  {desc}')
        else:
            print(f'    ${CYAN}{item[\"name\"]}${RESET}')

print_group('Skills', idx.get('skills', []))
print_group('Agents', idx.get('agents', []))
print_group('Commands', idx.get('commands', []))
" 2>/dev/null || fallback_list "$registry_root"
  else
    fallback_list "$registry_root"
  fi
}

fallback_list() {
  local registry_root="$1"

  echo ""
  echo "  Skills:"
  for d in "$registry_root/skills"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = "_shared" ] && continue
    echo "    $name"
  done

  echo ""
  echo "  Agents:"
  for d in "$registry_root/agents"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    echo "    $name"
  done

  echo ""
  echo "  Commands:"
  for d in "$registry_root/commands"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    echo "    $name"
  done
}
