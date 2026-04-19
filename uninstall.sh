#!/usr/bin/env bash
set -Eeuo pipefail

PANEL_DIR="${PANEL_DIR:-/var/www/pterodactyl}"
WEB_USER="${WEB_USER:-www-data}"
BACKUP_ROOT="$PANEL_DIR/.hazsly-one"
USER_CSS_DST="$PANEL_DIR/resources/scripts/assets/css/hazsly-one-user.css"
ADMIN_CSS_DST="$PANEL_DIR/public/assets/hazsly-one-admin.css"
LOGO_DST="$PANEL_DIR/public/assets/hazsly-one-mark.svg"
APP_TSX="$PANEL_DIR/resources/scripts/components/App.tsx"
APP_IMPORT="import '../assets/css/hazsly-one-user.css';"
ADMIN_LINK="<link rel=\"stylesheet\" href=\"{{ asset('assets/hazsly-one-admin.css') }}\">"

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
err() { printf '[ERR] %s\n' "$*" >&2; }

latest_backup() {
  if [ -L "$BACKUP_ROOT/latest" ]; then
    readlink -f "$BACKUP_ROOT/latest"
    return 0
  fi
  ls -1dt "$BACKUP_ROOT"/backups/* 2>/dev/null | head -n 1 || true
}

restore_file() {
  local backup_root="$1"
  local target="$2"
  local relative="${target#$PANEL_DIR}"
  if [ -f "$backup_root$relative" ]; then
    mkdir -p "$(dirname "$target")"
    cp -f "$backup_root$relative" "$target"
    log "Restored $relative"
    return 0
  fi
  return 1
}

artisan_safe() {
  local cmd="$1"
  if [ -f "$PANEL_DIR/artisan" ]; then
    php "$PANEL_DIR/artisan" "$cmd" || true
  fi
}

main() {
  if [ ! -d "$PANEL_DIR" ] || [ ! -f "$APP_TSX" ]; then
    err "Pterodactyl panel not found at $PANEL_DIR"
    exit 1
  fi

  local backup
  backup="$(latest_backup)"
  if [ -z "$backup" ] || [ ! -d "$backup" ]; then
    err "No Hazsly One backup found"
    exit 1
  fi

  artisan_safe down

  restore_file "$backup" "$APP_TSX" || APP_IMPORT_LINE="$APP_IMPORT" perl -0pi -e "s@\Q$ENV{APP_IMPORT_LINE}\E\n?@@g" "$APP_TSX"

  local admin_layout=""
  admin_layout="$(find "$PANEL_DIR/resources/views" -type f \( -name '*admin*.blade.php' -o -name '*layout*.blade.php' \) | head -n 1 || true)"
  if [ -n "$admin_layout" ]; then
    restore_file "$backup" "$admin_layout" || ADMIN_LINK_LINE="$ADMIN_LINK" perl -0pi -e "s@\Q$ENV{ADMIN_LINK_LINE}\E\n?@@g" "$admin_layout"
  fi

  restore_file "$backup" "$USER_CSS_DST" || rm -f "$USER_CSS_DST"
  restore_file "$backup" "$ADMIN_CSS_DST" || rm -f "$ADMIN_CSS_DST"
  restore_file "$backup" "$LOGO_DST" || rm -f "$LOGO_DST"

  cd "$PANEL_DIR"
  export NODE_OPTIONS="${NODE_OPTIONS:---openssl-legacy-provider}"
  yarn install --network-timeout 300000 || true
  yarn build:production || true

  artisan_safe view:clear
  artisan_safe config:clear
  artisan_safe cache:clear
  artisan_safe route:clear
  artisan_safe queue:restart
  artisan_safe up

  if id "$WEB_USER" >/dev/null 2>&1; then
    chown -R "$WEB_USER":"$WEB_USER" "$PANEL_DIR"
  fi

  log "Hazsly One removed. Restored from $backup"
}

main "$@"
