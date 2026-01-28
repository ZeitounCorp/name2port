#!/usr/bin/env bash
set -euo pipefail

# name2port auto-installer (macOS/Linux)
# Supports:
#   curl -fsSL <URL> | bash
#   curl -fsSL <URL> | bash -s -- -y --link user
#
# Installs:
#   - python3 (if missing, via OS package manager when possible)
#   - pipx (preferred, when possible; otherwise falls back to pip --user)
#   - name2port from PyPI
# Optional:
#   - symlink into ~/bin or /usr/local/bin

APP="name2port"

GREEN="\033[92m"
YELLOW="\033[38;5;208m"
RED="\033[91m"
RESET="\033[0m"

YES=0
LINK_MODE="ask"      # ask|never|always
LINK_TARGET="user"   # user|system

usage() {
  cat <<EOF
${APP} installer (macOS/Linux)

Usage (local):
  ./install.sh
  ./install.sh -y
  ./install.sh --link user
  ./install.sh --link system
  ./install.sh --no-link

Usage (curl | bash):
  curl -fsSL <URL> | bash
  curl -fsSL <URL> | bash -s -- -y --link user

Options:
  -y, --yes            Auto-accept prompts
  --link user          Create/refresh symlink in ~/bin/${APP}
  --link system        Create/refresh symlink in /usr/local/bin/${APP} (sudo)
  --no-link            Do not create symlinks
  -h, --help           Show help

EOF
}

log()  { echo -e "${GREEN}==>${RESET} $*"; }
warn() { echo -e "${YELLOW}==>${RESET} $*" >&2; }
err()  { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

prompt_yn() {
  local q="$1"
  local default="${2:-y}" # y/n
  if [[ "$YES" -eq 1 ]]; then
    return 0
  fi
  local suffix="[y/N]"
  [[ "$default" == "y" ]] && suffix="[Y/n]"
  read -r -p "$q $suffix " ans
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy]$ ]]
}

detect_pm() {
  if need_cmd apt-get; then echo "apt"; return; fi
  if need_cmd dnf; then echo "dnf"; return; fi
  if need_cmd yum; then echo "yum"; return; fi
  if need_cmd pacman; then echo "pacman"; return; fi
  if need_cmd zypper; then echo "zypper"; return; fi
  if need_cmd apk; then echo "apk"; return; fi
  if need_cmd brew; then echo "brew"; return; fi
  echo "unknown"
}

install_pkg() {
  local pm="$1"; shift
  local pkgs=("$@")
  case "$pm" in
    apt)
      sudo apt-get update -y
      sudo apt-get install -y "${pkgs[@]}"
      ;;
    dnf) sudo dnf install -y "${pkgs[@]}" ;;
    yum) sudo yum install -y "${pkgs[@]}" ;;
    pacman) sudo pacman -Sy --noconfirm "${pkgs[@]}" ;;
    zypper) sudo zypper --non-interactive install "${pkgs[@]}" ;;
    apk) sudo apk add --no-cache "${pkgs[@]}" ;;
    brew) brew install "${pkgs[@]}" ;;
    *) err "Unsupported package manager. Please install python3 and pipx manually." ;;
  esac
}

ensure_python() {
  if need_cmd python3; then
    log "python3 detected."
    return 0
  fi

  warn "python3 not found."
  local pm
  pm="$(detect_pm)"
  warn "Detected package manager: $pm"

  if ! prompt_yn "Install python3 using $pm?" "y"; then
    err "python3 is required. Please install it and re-run."
  fi

  case "$pm" in
    apt) install_pkg "$pm" python3 python3-venv python3-pip ;;
    dnf|yum) install_pkg "$pm" python3 python3-pip ;;
    pacman) install_pkg "$pm" python python-pip ;;
    zypper) install_pkg "$pm" python3 python3-pip ;;
    apk) install_pkg "$pm" python3 py3-pip ;;
    brew) install_pkg "$pm" python ;;
    *) err "Can't install python3 automatically on this system." ;;
  esac
}

ensure_pipx() {
  if need_cmd pipx; then
    log "pipx detected."
    return 0
  fi

  warn "pipx not found. pipx is recommended for installing Python CLI tools."
  local pm
  pm="$(detect_pm)"
  warn "Detected package manager: $pm"

  if prompt_yn "Install pipx using $pm (preferred)?" "y"; then
    case "$pm" in
      apt) install_pkg "$pm" pipx ;;
      dnf|yum) install_pkg "$pm" pipx ;;
      pacman) install_pkg "$pm" python-pipx ;;
      zypper) install_pkg "$pm" python3-pipx ;;
      brew) install_pkg "$pm" pipx ;;
      apk)
        warn "apk may not have pipx on all distros; falling back to pip --user."
        python3 -m pip install --user --upgrade pipx
        ;;
      *)
        warn "Unknown package manager; falling back to pip --user."
        python3 -m pip install --user --upgrade pipx
        ;;
    esac
  else
    warn "Continuing without pipx (will use pip --user)."
    return 1
  fi

  if need_cmd pipx; then
    pipx ensurepath >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}

install_name2port() {
  if need_cmd pipx; then
    log "Installing ${APP} using pipx..."
    pipx install "$APP" --force
    return 0
  fi

  log "Installing ${APP} using pip --user..."
  python3 -m pip install --user --upgrade "$APP"
}

resolve_app_path() {
  if need_cmd "$APP"; then
    command -v "$APP"
    return 0
  fi

  if need_cmd pipx; then
    local bin="${PIPX_BIN_DIR:-$HOME/.local/bin}"
    if [[ -x "$bin/$APP" ]]; then
      echo "$bin/$APP"
      return 0
    fi
  fi

  if [[ -x "$HOME/.local/bin/$APP" ]]; then
    echo "$HOME/.local/bin/$APP"
    return 0
  fi

  return 1
}

ensure_link_dir_user() {
  mkdir -p "$HOME/bin"
  if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    warn "NOTE: ~/bin is not on your PATH."
    warn "Add this line to your shell profile (e.g. ~/.bashrc or ~/.zshrc):"
    warn "  export PATH=\"\$HOME/bin:\$PATH\""
  fi
}

create_symlink() {
  local src="$1"
  local mode="$2" # user|system

  if [[ "$mode" == "user" ]]; then
    ensure_link_dir_user
    ln -sf "$src" "$HOME/bin/$APP"
    log "Symlinked: $HOME/bin/$APP -> $src"
    return 0
  fi

  if [[ "$mode" == "system" ]]; then
    sudo ln -sf "$src" "/usr/local/bin/$APP"
    log "Symlinked: /usr/local/bin/$APP -> $src"
    return 0
  fi
}

# -------------------------
# Parse args
# -------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) YES=1; shift ;;
    --no-link) LINK_MODE="never"; shift ;;
    --link)
      LINK_MODE="always"
      LINK_TARGET="${2:-user}"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *)
      err "Unknown argument: $1 (use -h)"
      ;;
  esac
done

# -------------------------
# Run
# -------------------------
log "Starting ${APP} installer..."
ensure_python
ensure_pipx || true
install_name2port

APP_PATH="$(resolve_app_path || true)"
if [[ -z "${APP_PATH:-}" ]]; then
  warn "Installed, but couldn't locate '${APP}' on PATH."
  warn "Try opening a new terminal or ensure ~/.local/bin is on PATH."
else
  log "Installed executable found at: $APP_PATH"
fi

if [[ "$LINK_MODE" == "never" ]]; then
  log "Skipping symlink creation (--no-link)."
else
  if [[ -z "${APP_PATH:-}" ]]; then
    warn "Skipping symlink: executable path not found."
  else
    if [[ "$LINK_MODE" == "always" ]]; then
      create_symlink "$APP_PATH" "$LINK_TARGET"
    else
      if prompt_yn "Create a symlink so '${APP}' is ready-to-use from your PATH?" "y"; then
        if prompt_yn "Link to ~/bin (recommended) instead of /usr/local/bin?" "y"; then
          create_symlink "$APP_PATH" "user"
        else
          create_symlink "$APP_PATH" "system"
        fi
      else
        log "Symlink not created."
      fi
    fi
  fi
fi

log "Done."
log "Try:"
echo "  ${APP} bento-pdf" | sed 's/^/  /'
