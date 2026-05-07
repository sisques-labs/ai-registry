#!/usr/bin/env bash
# =============================================================================
# ai-registry — CLI Installer
#
# Instala skills, agentes, y commands desde este registry a tu entorno
# (usuario o proyecto). Soporta OpenCode, Claude Code, Cursor, Gemini, Copilot.
#
# Uso:
#   install.sh all                                   Instalar todo
#   install.sh skills                                 Instalar todos los skills
#   install.sh agents                                 Instalar todos los agentes
#   install.sh commands                               Instalar todos los commands
#   install.sh skill <name>                           Instalar un skill
#   install.sh agent <name>                           Instalar un agente
#   install.sh command <name>                         Instalar un comando
#   install.sh ls                                     Listar disponible
#   install.sh create skill <name>                    Scaffold nuevo skill
#   install.sh create agent <name>                    Scaffold nuevo agente
#   install.sh create command <name>                  Scaffold nuevo comando
#   install.sh index                                  Regenerar index.json
#
# Flags:
#   --user      (default) Instalar a nivel usuario
#   --project             Instalar a nivel proyecto
#   --tool <t>            Tool target (opencode|claude|cursor|gemini|copilot)
#   --help                Mostrar ayuda
#
# Ejemplos:
#   install.sh all --user --tool opencode
#   install.sh skill my-go-patterns --project
#   install.sh agents --tool claude
#   install.sh create agent code-reviewer
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"

# --- Defaults ---
LEVEL="user"
TOOL="opencode"
REGISTRY_ROOT="$SCRIPT_DIR"

# --- Help ---
show_help() {
  # Print the help block (lines between # === and the first empty line)
  local file="${BASH_SOURCE[0]}"
  while IFS= read -r line; do
    [[ "$line" == "# ==="* ]] && continue
    [[ "$line" == "#" ]] && { echo ""; continue; }
    [[ "$line" == "# "* ]] && echo "${line:2}"
    [[ "$line" != "#"* ]] && [[ "$line" != "" ]] && break
  done < "$file"
  exit 0
}

# --- Parse args ---
parse_args() {
  local args=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --user)    LEVEL="user"; shift ;;
      --project) LEVEL="project"; shift ;;
      --tool)    shift; TOOL="${1:-opencode}"; shift ;;
      --help)    show_help ;;
      -h)        show_help ;;
      --*)       log_warn "Unknown flag: $1"; shift ;;
      *)         args+=("$1"); shift ;;
    esac
  done

  # Restore positional args
  set -- "${args[@]}"

  # First positional is the command, second (if any) is the name
  CMD="${1:-help}"
  NAME="${2:-}"
}

# --- Main ---
main() {
  parse_args "$@"

  case "$CMD" in
    all)
      log_step "Installing ALL — skills, agents, commands"
      echo "  Level: $LEVEL | Tool: $TOOL"
      echo ""

      SKILL_TARGET="$(resolve_target_dir skill "$LEVEL" "$TOOL")"
      AGENT_TARGET="$(resolve_target_dir agent "$LEVEL" "$TOOL")"
      CMD_TARGET="$(resolve_target_dir command "$LEVEL" "$TOOL")"
      OPENCODE_JSON="$(resolve_opencode_json "$LEVEL")"

      install_all_skills "$SKILL_TARGET" "$REGISTRY_ROOT"
      install_all_agents "$AGENT_TARGET" "$OPENCODE_JSON" "$REGISTRY_ROOT"
      install_all_commands "$CMD_TARGET" "$REGISTRY_ROOT"

      echo ""
      log_ok "All items installed!"
      echo ""
      log_info "Skills → $SKILL_TARGET"
      log_info "Agents → $AGENT_TARGET"
      if [ -n "$OPENCODE_JSON" ]; then
        log_info "Agent registration → $OPENCODE_JSON"
      fi
      log_info "Commands → $CMD_TARGET"
      ;;

    skills)
      log_step "Installing all skills"
      echo "  Level: $LEVEL | Tool: $TOOL"
      TARGET="$(resolve_target_dir skill "$LEVEL" "$TOOL")"
      install_all_skills "$TARGET" "$REGISTRY_ROOT"
      log_ok "All skills → $TARGET"
      ;;

    agents)
      log_step "Installing all agents"
      echo "  Level: $LEVEL | Tool: $TOOL"
      TARGET="$(resolve_target_dir agent "$LEVEL" "$TOOL")"
      OPENCODE_JSON="$(resolve_opencode_json "$LEVEL")"
      install_all_agents "$TARGET" "$OPENCODE_JSON" "$REGISTRY_ROOT"
      log_ok "All agents → $TARGET"
      ;;

    commands)
      log_step "Installing all commands"
      echo "  Level: $LEVEL | Tool: $TOOL"
      TARGET="$(resolve_target_dir command "$LEVEL" "$TOOL")"
      install_all_commands "$TARGET" "$REGISTRY_ROOT"
      log_ok "All commands → $TARGET"
      ;;

    skill)
      if [ -z "$NAME" ]; then
        log_error "Usage: install.sh skill <name> [--user|--project] [--tool <tool>]"
        exit 1
      fi
      TARGET="$(resolve_target_dir skill "$LEVEL" "$TOOL")"
      install_skill "$NAME" "$TARGET" "$REGISTRY_ROOT"
      ;;

    agent)
      if [ -z "$NAME" ]; then
        log_error "Usage: install.sh agent <name> [--user|--project] [--tool <tool>]"
        exit 1
      fi
      TARGET="$(resolve_target_dir agent "$LEVEL" "$TOOL")"
      OPENCODE_JSON="$(resolve_opencode_json "$LEVEL")"
      install_agent "$NAME" "$TARGET" "$OPENCODE_JSON" "$REGISTRY_ROOT"
      ;;

    command)
      if [ -z "$NAME" ]; then
        log_error "Usage: install.sh command <name> [--user|--project] [--tool <tool>]"
        exit 1
      fi
      TARGET="$(resolve_target_dir command "$LEVEL" "$TOOL")"
      install_command "$NAME" "$TARGET" "$REGISTRY_ROOT"
      ;;

    ls)
      list_registry "$REGISTRY_ROOT"
      ;;

    create)
      if [ -z "$NAME" ]; then
        log_error "Usage: install.sh create <skill|agent|command> <name>"
        exit 1
      fi
      local subcmd="$NAME"
      local subname="${3:-}"
      if [ -z "$subname" ]; then
        log_error "Usage: install.sh create <skill|agent|command> <name>"
        exit 1
      fi
      case "$subcmd" in
        skill)   scaffold_skill "$subname" "$REGISTRY_ROOT" ;;
        agent)   scaffold_agent "$subname" "$REGISTRY_ROOT" ;;
        command) scaffold_command "$subname" "$REGISTRY_ROOT" ;;
        *)       log_error "Unknown type: $subcmd. Use: skill, agent, or command"; exit 1 ;;
      esac
      ;;

    index)
      generate_index "$REGISTRY_ROOT"
      ;;

    help|--help|-h)
      show_help
      ;;

    *)
      log_error "Unknown command: $CMD"
      echo "Usage: install.sh <command> [name] [--user|--project] [--tool <tool>]"
      echo "  Commands: all, skills, agents, commands, skill <n>, agent <n>, command <n>,"
      echo "            ls, create <type> <n>, index"
      exit 1
      ;;
  esac
}

main "$@"
