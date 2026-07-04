#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="maister-pi"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC}  $1"; }

echo ""
echo "=================================================="
echo "  Maister for Pi - Installation"
echo "=================================================="
echo ""

# Determine install mode
GLOBAL=false
TARGET_PATH=""

if [ "$1" = "--global" ]; then
  GLOBAL=true
  shift
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 [--global] [PROJECT_PATH]"
  echo ""
  echo "  Default (no flags):       Local install to PROJECT_PATH (required)"
  echo "  ./install.sh --global     Global install to ~/.pi/agent/"
  echo "  ./install.sh /path/to/my-project"
  echo ""
  echo "Options:"
  echo "  --global    Install globally (for all projects) in ~/.pi/agent/"
  echo "  -h, --help  Show this help message"
  echo ""
  exit 0
else
  TARGET_PATH="$1"
fi

if $GLOBAL; then
  info "Mode: Global installation (--global flag)"
  DEST_BASE="$HOME/.pi/agent"
else
  if [ -z "$TARGET_PATH" ]; then
    err "Error: Local installation requires a project path."
    echo ""
    echo "Usage: $0 <PROJECT_PATH>"
    echo "  e.g.  $0 /home/user/my-project"
    echo "  e.g.  $0 ."
    echo ""
    echo "For global install, use: $0 --global"
    echo "For help, use:        $0 --help"
    exit 1
  fi
  # Resolve to absolute path
  TARGET_PATH="$(cd "$TARGET_PATH" 2>/dev/null && pwd || echo "$TARGET_PATH")"
  if [ ! -d "$TARGET_PATH" ]; then
    err "Error: Directory does not exist: $TARGET_PATH"
    exit 1
  fi
  DEST_BASE="$TARGET_PATH/.pi"
  info "Mode: Local installation"
  info "Target: $TARGET_PATH"
  info "Destination: $DEST_BASE/"
fi

DEST_AGENTS="$DEST_BASE/agents"
DEST_SKILLS="$DEST_BASE/skills"
DEST_PROMPTS="$DEST_BASE/prompts"
DEST_EXTENSIONS="$DEST_BASE/extensions"

# Components to install
COMPONENTS=(
  "Agents (24 specialized sub-agents)"
  "Skills (16 workflow orchestrators and utilities)"
  "Prompt templates (15 command wrappers)"
  "Post-compaction reminder extension"
  "Playwright MCP configuration"
)

# Required npm packages
PACKAGES=(
  "pi-subagents"
  "pi-mcp-adapter"
  "@juicesharp/rpiv-ask-user-question"
  "@juicesharp/rpiv-todo"
  "pi-web-access"
  "pi-prompt-template-model"
)

echo ""
echo "This will install:"
for comp in "${COMPONENTS[@]}"; do
  echo "  - $comp"
done
echo ""
echo "Required packages (installed via 'pi install'):"
for pkg in "${PACKAGES[@]}"; do
  echo "  - npm:$pkg"
done
echo ""
echo "Optional companion package (manual install if desired):"
echo "  - npm:pi-intercom  # live supervisor decisions for long-running/background subagents"
echo ""

# Confirm
read -p "Proceed with installation? [Y/n] " confirm
if [[ "$confirm" =~ ^[Nn] ]]; then
  info "Installation cancelled."
  exit 0
fi

echo ""
info "Starting installation..."

# --- Copy agents ---
mkdir -p "$DEST_AGENTS"
cp "$SCRIPT_DIR/agents/"*.md "$DEST_AGENTS/"
ok "Agents copied to $DEST_AGENTS/"

# --- Copy skills ---
mkdir -p "$DEST_SKILLS"
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  if [ -d "$skill_dir" ]; then
    skname=$(basename "$skill_dir")
    mkdir -p "$DEST_SKILLS/$skname"
    cp -r "$skill_dir"* "$DEST_SKILLS/$skname/" 2>/dev/null || true
  fi
done
ok "Skills copied to $DEST_SKILLS/"

# --- Copy prompts ---
mkdir -p "$DEST_PROMPTS"
cp "$SCRIPT_DIR/prompts/"*.md "$DEST_PROMPTS/"
ok "Prompt templates copied to $DEST_PROMPTS/"

# --- Copy extensions ---
mkdir -p "$DEST_EXTENSIONS"
if [ -d "$SCRIPT_DIR/extensions" ]; then
  cp -r "$SCRIPT_DIR/extensions/"* "$DEST_EXTENSIONS/"
  ok "Extensions copied to $DEST_EXTENSIONS/"
fi

# --- Copy AGENTS.md (context file) ---
if [ -f "$SCRIPT_DIR/AGENTS.md" ]; then
  cp "$SCRIPT_DIR/AGENTS.md" "$DEST_BASE/AGENTS.md"
  ok "AGENTS.md copied"
fi

# --- Copy MCP config ---
if [ -f "$SCRIPT_DIR/.mcp.json" ]; then
  cp "$SCRIPT_DIR/.mcp.json" "$DEST_BASE/.mcp.json"
  ok ".mcp.json copied"
elif [ -f "$SCRIPT_DIR/mcp.json" ]; then
  cp "$SCRIPT_DIR/mcp.json" "$DEST_BASE/mcp.json"
  ok "mcp.json copied"
fi

# --- Install npm packages ---
echo ""
read -p "Install required npm packages? [Y/n] " install_packages
if [[ ! "$install_packages" =~ ^[Nn] ]]; then
  echo ""
  info "Installing required npm packages via Pi..."
  echo ""

  for pkg in "${PACKAGES[@]}"; do
    info "Installing npm:$pkg ..."
    if pi install "npm:$pkg" 2>/dev/null; then
      ok "npm:$pkg installed"
    else
      warn "Failed to install npm:$pkg — you may need to install it manually: pi install npm:$pkg"
    fi
  done

  echo ""
else
  info "Skipping npm package installation."
  echo ""
  info "You can install packages manually later:"
  for pkg in "${PACKAGES[@]}"; do
    echo "       pi install npm:$pkg"
  done
  echo ""
  echo "Optional companion:"
  echo "       pi install npm:pi-intercom"
  echo ""
fi

# --- Summary ---
echo "=================================================="
echo "  Installation Complete"
echo "=================================================="
echo ""
if $GLOBAL; then
  echo "  Location: ~/.pi/agent/ (global)"
else
  echo "  Location: $DEST_BASE/ (project-local)"
fi
echo ""
echo "  Optional companion for background subagent decisions:"
echo "    pi install npm:pi-intercom"
echo ""
echo "  Quick Start:"
echo "    /maister-init           - Initialize Maister framework"
echo "    /maister-work           - Unified workflow entry point"
echo "    /maister-development    - Full development workflow"
echo "    /maister-quick-plan     - Lightweight planning"
echo "    /maister-quick-bugfix   - Quick bug fix"
echo ""
echo "  For full documentation, see the README.md"
echo "=================================================="
