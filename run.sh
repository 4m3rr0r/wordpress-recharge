#!/usr/bin/env bash
#
# wordpress-recharge: spin up a local, disposable WordPress instance for
# vuln research on plugins/themes. Auto-installs with admin/admin.
#
# Usage:
#   ./run.sh up                      # start latest WordPress on port 8080
#   ./run.sh up -v 6.2 -p 8081       # start a specific WP version on a custom port
#   ./run.sh down                    # stop containers (keep data)
#   ./run.sh destroy                 # stop containers and wipe all data/volumes
#
set -euo pipefail
cd "$(dirname "$0")"

ACTION="${1:-up}"
shift || true

WP_VERSION="latest"
WP_PORT="8080"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version) WP_VERSION="$2"; shift 2 ;;
    -p|--port)    WP_PORT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [up|down|destroy] [-v|--version <wp_version>] [-p|--port <port>]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

export WP_VERSION WP_PORT

case "$ACTION" in
  up)
    echo "[*] Starting WordPress (version: ${WP_VERSION}) on port ${WP_PORT} ..."
    docker compose up -d db wordpress

    echo "[*] Waiting for the database to accept connections..."
    until docker compose exec -T db mysqladmin ping -h 127.0.0.1 -uwordpress -pwordpress --silent >/dev/null 2>&1; do
      sleep 2
    done

    echo "[*] Waiting for WordPress to respond on http://localhost:${WP_PORT} ..."
    until curl -s -o /dev/null -w '%{http_code}' "http://localhost:${WP_PORT}/wp-login.php" 2>/dev/null | grep -qE '^(200|302)$'; do
      sleep 2
    done

    echo "[*] Waiting for wp-config.php / DB connection via wp-cli ..."
    for i in $(seq 1 30); do
      docker compose run --rm -T wpcli wp db check >/dev/null 2>&1 && break
      sleep 2
    done

    echo "[*] Fixing wp-content permissions (so uploads/plugins work) ..."
    docker compose exec -T wordpress sh -c 'mkdir -p wp-content/uploads && chown -R www-data:www-data wp-content'

    echo "[*] Running WordPress core install (admin / admin) ..."
    if docker compose run --rm -T wpcli wp core is-installed >/dev/null 2>&1; then
      echo "[*] WordPress already installed, skipping install step."
    else
      docker compose run --rm -T wpcli wp core install \
        --url="http://localhost:${WP_PORT}" \
        --title="Vuln Lab" \
        --admin_user=admin \
        --admin_password=admin \
        --admin_email=admin@example.com \
        --skip-email
    fi

    # wp-cli runs as a different user; re-apply ownership after install
    docker compose exec -T wordpress chown -R www-data:www-data wp-content

    echo
    echo "=================================================================="
    echo " WordPress version : ${WP_VERSION}"
    echo " Site URL          : http://localhost:${WP_PORT}/"
    echo " Admin login       : http://localhost:${WP_PORT}/wp-admin"
    echo " Credentials       : admin / admin"
    echo "=================================================================="
    ;;

  down)
    docker compose down
    ;;

  destroy)
    docker compose down -v
    ;;

  *)
    echo "Usage: $0 [up|down|destroy] [-v|--version <wp_version>] [-p|--port <port>]" >&2
    exit 1
    ;;
esac
