#!/usr/bin/env bash
set -euo pipefail

PANEL_DIR="${PANEL_DIR:-/var/www/pterodactyl}"
APP_TSX="$PANEL_DIR/resources/scripts/components/App.tsx"
USER_CSS="$PANEL_DIR/resources/scripts/assets/css/hazsly-one-user.css"
ADMIN_CSS="$PANEL_DIR/public/assets/hazsly-one-admin.css"
APP_IMPORT="import '../assets/css/hazsly-one-user.css';"
ADMIN_LINK="hazsly-one-admin.css"

printf 'Hazsly One doctor\n\n'

check() {
  local label="$1"
  local ok="$2"
  if [ "$ok" = "1" ]; then
    printf '[OK] %s\n' "$label"
  else
    printf '[NO] %s\n' "$label"
  fi
}

check "Panel directory exists ($PANEL_DIR)" "$( [ -d "$PANEL_DIR" ] && echo 1 || echo 0 )"
check "App.tsx exists" "$( [ -f "$APP_TSX" ] && echo 1 || echo 0 )"
check "User CSS file exists" "$( [ -f "$USER_CSS" ] && echo 1 || echo 0 )"
check "User CSS import present" "$( [ -f "$APP_TSX" ] && grep -Fq "$APP_IMPORT" "$APP_TSX" && echo 1 || echo 0 )"
check "Admin CSS file exists" "$( [ -f "$ADMIN_CSS" ] && echo 1 || echo 0 )"
check "Admin CSS linked in views" "$( grep -Rqs "$ADMIN_LINK" "$PANEL_DIR/resources/views" 2>/dev/null && echo 1 || echo 0 )"
check "Backup root exists" "$( [ -d "$PANEL_DIR/.hazsly-one" ] && echo 1 || echo 0 )"

printf '\nNode: %s\n' "$(node -v 2>/dev/null || echo missing)"
printf 'Yarn: %s\n' "$(yarn -v 2>/dev/null || echo missing)"
printf 'PHP: %s\n' "$(php -v 2>/dev/null | head -n 1 || echo missing)"
