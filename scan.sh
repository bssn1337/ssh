#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 -i <prefix> -u <user> -p <password> [-o port] [-P parallel] [-t timeout]"
  exit 1
}

PREFIX=""
USER=""
PASS=""
PORT=22
PARALLEL=30
TIMEOUT=1

while getopts ":i:u:p:o:P:t:" opt; do
  case $opt in
    i) PREFIX="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    o) PORT="$OPTARG" ;;
    P) PARALLEL="$OPTARG" ;;
    t) TIMEOUT="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z "$PREFIX" || -z "$USER" || -z "$PASS" ]] && usage

command -v sshpass >/dev/null || { echo "[ERROR] sshpass belum terinstall"; exit 1; }

scan_ip() {
  local ip="$1"

  # cek port
  if timeout "$TIMEOUT" bash -c "echo >/dev/tcp/$ip/$PORT" 2>/dev/null; then

    INFO=$(sshpass -p "$PASS" ssh \
      -p "$PORT" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=2 \
      -o LogLevel=ERROR \
      "$USER@$ip" '
        hostname
        grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d "\""
      ' 2>/dev/null)

    if [ -n "$INFO" ]; then
      HOST=$(echo "$INFO" | sed -n '1p')
      OS=$(echo "$INFO" | sed -n '2p')

      if [ -n "$OS" ]; then
        printf "[OK] %s:%s (%s - %s)\n" "$ip" "$PORT" "$HOST" "$OS"
      else
        printf "[OK] %s:%s (%s)\n" "$ip" "$PORT" "$HOST"
      fi
    else
      printf "[FAIL] %s:%s\n" "$ip" "$PORT"
    fi

  fi
}

export -f scan_ip
export USER PASS PORT TIMEOUT

seq 1 254 | xargs -P "$PARALLEL" -I{} bash -c 'scan_ip "$@"' _ "$PREFIX".{}
