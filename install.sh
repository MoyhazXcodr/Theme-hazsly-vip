#!/usr/bin/env bash
set -Eeuo pipefail

PANEL_DIR="${PANEL_DIR:-/var/www/pterodactyl}"
WEB_USER="${WEB_USER:-www-data}"
BRANCH="${BRANCH:-main}"
REPO_URL="${REPO_URL:-https://github.com/MoyhazXcodr/Theme-hazsly-vip.git}"
TMP_ROOT="${TMPDIR:-/tmp}/hazsly-one-install-$$"
BACKUP_ROOT="$PANEL_DIR/.hazsly-one"
TIMESTAMP="$(date +%F-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/backups/$TIMESTAMP"
LATEST_LINK="$BACKUP_ROOT/latest"
USER_CSS_DST="$PANEL_DIR/resources/scripts/assets/css/hazsly-one-user.css"
ADMIN_CSS_DST="$PANEL_DIR/public/assets/hazsly-one-admin.css"
LOGO_DST="$PANEL_DIR/public/assets/hazsly-one-mark.svg"
APP_TSX="$PANEL_DIR/resources/scripts/components/App.tsx"
APP_IMPORT="import '../assets/css/hazsly-one-user.css';"
ADMIN_LINK="<link rel=\"stylesheet\" href=\"{{ asset('assets/hazsly-one-admin.css') }}\">"

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
err() { printf '[ERR] %s\n' "$*" >&2; }

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

apt_install() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y "$@"
}

ensure_dependencies() {
  local missing=()
  need_cmd git || missing+=(git)
  need_cmd curl || missing+=(curl)
  need_cmd perl || missing+=(perl)
  need_cmd php || missing+=(php)
  need_cmd node || missing+=(nodejs)
  need_cmd npm || missing+=(npm)

  if [ ${#missing[@]} -gt 0 ]; then
    if need_cmd apt-get; then
      log "Installing missing system packages: ${missing[*]}"
      apt_install ca-certificates git curl perl php-cli nodejs npm
    else
      err "Missing commands: ${missing[*]}. Install them manually."
      exit 1
    fi
  fi

  if ! need_cmd yarn; then
    log "Installing yarn"
    npm install -g yarn
  fi
}

resolve_asset_dir() {
  local self_dir=""
  local src="${BASH_SOURCE[0]-}"
  if [ -n "$src" ] && [ -f "$src" ]; then
    self_dir="$(cd "$(dirname "$src")" && pwd)"
    if [ -f "$self_dir/theme/hazsly-one-user.css" ] && [ -f "$self_dir/theme/hazsly-one-admin.css" ]; then
      printf '%s\n' "$self_dir"
      return 0
    fi
  fi

  mkdir -p "$TMP_ROOT"
  log "Cloning theme repo: $REPO_URL"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_ROOT/repo" >/dev/null 2>&1 || {
    err "Failed to clone $REPO_URL"
    exit 1
  }
  if [ ! -f "$TMP_ROOT/repo/theme/hazsly-one-user.css" ] || [ ! -f "$TMP_ROOT/repo/theme/hazsly-one-admin.css" ]; then
    err "Theme assets missing in repo. Expected theme/hazsly-one-user.css and theme/hazsly-one-admin.css"
    exit 1
  fi
  printf '%s\n' "$TMP_ROOT/repo"
}

find_admin_layout() {
  local candidates=(
    "$PANEL_DIR/resources/views/layouts/admin.blade.php"
    "$PANEL_DIR/resources/views/layouts/admin/master.blade.php"
    "$PANEL_DIR/resources/views/admin/layout.blade.php"
    "$PANEL_DIR/resources/views/admin/master.blade.php"
  )
  local f
  for f in "${candidates[@]}"; do
    if [ -f "$f" ]; then
      printf '%s\n' "$f"
      return 0
    fi
  done

  local found
  found="$(grep -Rsl "<title>.*Pterodactyl\|@yield('title')\|admin" "$PANEL_DIR/resources/views" 2>/dev/null | grep -E 'admin|layout' | head -n 1 || true)"
  if [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi
  return 1
}

backup_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  mkdir -p "$BACKUP_DIR$(dirname "${file#$PANEL_DIR}")"
  cp -f "$file" "$BACKUP_DIR${file#$PANEL_DIR}"
}

inject_app_import() {
  if grep -Fq "$APP_IMPORT" "$APP_TSX"; then
    log "User CSS import already present in App.tsx"
    return 0
  fi
  APP_IMPORT_LINE="$APP_IMPORT" perl -0pi -e "s@(^import .*?;\n)@$1$ENV{APP_IMPORT_LINE}\n@m" "$APP_TSX"
}

inject_admin_link() {
  local layout="$1"
  if grep -Fq "$ADMIN_LINK" "$layout"; then
    log "Admin CSS link already present"
    return 0
  fi
  ADMIN_LINK_LINE="$ADMIN_LINK" perl -0pi -e "s@</head>@$ENV{ADMIN_LINK_LINE}\n</head>@i" "$layout"
}

run_build() {
  cd "$PANEL_DIR"
  export NODE_OPTIONS="${NODE_OPTIONS:---openssl-legacy-provider}"
  log "Installing JS dependencies"
  yarn install --network-timeout 300000
  log "Building panel assets"
  yarn build:production
}

artisan_safe() {
  local cmd="$1"
  if [ -f "$PANEL_DIR/artisan" ]; then
    php "$PANEL_DIR/artisan" "$cmd" || true
  fi
}

main() {
  ensure_dependencies

  if [ ! -d "$PANEL_DIR" ] || [ ! -f "$APP_TSX" ]; then
    err "Pterodactyl panel not found at $PANEL_DIR"
    exit 1
  fi

  local asset_dir
  asset_dir="$(resolve_asset_dir)"
  local admin_layout=""
  admin_layout="$(find_admin_layout || true)"

  mkdir -p "$BACKUP_DIR" "$PANEL_DIR/resources/scripts/assets/css" "$PANEL_DIR/public/assets" "$BACKUP_ROOT/backups"
  ln -sfn "$BACKUP_DIR" "$LATEST_LINK"

  log "Entering maintenance mode"
  artisan_safe down

  log "Backing up files"
  backup_file "$APP_TSX"
  if [ -n "$admin_layout" ]; then
    backup_file "$admin_layout"
  fi
  [ -f "$USER_CSS_DST" ] && backup_file "$USER_CSS_DST"
  [ -f "$ADMIN_CSS_DST" ] && backup_file "$ADMIN_CSS_DST"
  [ -f "$LOGO_DST" ] && backup_file "$LOGO_DST"

  log "Copying Hazsly One assets"
  install -m 0644 "$asset_dir/theme/hazsly-one-user.css" "$USER_CSS_DST"
  install -m 0644 "$asset_dir/theme/hazsly-one-admin.css" "$ADMIN_CSS_DST"
  if [ -f "$asset_dir/theme/public/hazsly-one-mark.svg" ]; then
    install -m 0644 "$asset_dir/theme/public/hazsly-one-mark.svg" "$LOGO_DST"
  fi

  log "Injecting user theme import"
  APP_IMPORT_LINE="$APP_IMPORT" inject_app_import

  if [ -n "$admin_layout" ]; then
    log "Injecting admin theme link into $(basename "$admin_layout")"
    ADMIN_LINK_LINE="$ADMIN_LINK" inject_admin_link "$admin_layout"
  else
    warn "Admin layout not auto-detected. User panel theme will still install."
  fi

  run_build

  log "Clearing caches"
  artisan_safe view:clear
  artisan_safe config:clear
  artisan_safe cache:clear
  artisan_safe route:clear

  if id "$WEB_USER" >/dev/null 2>&1; then
    log "Fixing ownership to $WEB_USER"
    chown -R "$WEB_USER":"$WEB_USER" "$PANEL_DIR"
  else
    warn "User $WEB_USER not found. Skipping chown."
  fi

  log "Restarting queue"
  artisan_safe queue:restart
  artisan_safe up

  log "Hazsly One installed successfully"
  log "Backup saved at: $BACKUP_DIR"
}

main "$@"
