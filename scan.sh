#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 -i <prefix> -u <user> -p <password> [-P parallel] [-t timeout]"
  echo "Example: $0 -i 192.168.213 -u dev -p 'secret' -P 30 -t 1"
  exit 1
}

PREFIX=""
USER=""
PASS=""
PARALLEL=30
TIMEOUT=1

while getopts ":i:u:p:P:t:" opt; do
  case $opt in
    i) PREFIX="$OPTARG" ;;
    u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    P) PARALLEL="$OPTARG" ;;
    t) TIMEOUT="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z "$PREFIX" || -z "$USER" || -z "$PASS" ]] && usage

if ! command -v sshpass >/dev/null; then
  echo "[ERROR] sshpass belum terinstall"
  exit 1
fi

export USER PASS PREFIX TIMEOUT

seq 1 254 | xargs -P "$PARALLEL" -I{} bash -c '
ip="$PREFIX".{};
if timeout "$TIMEOUT" bash -c "echo >/dev/tcp/$ip/22" 2>/dev/null; then
  if sshpass -p "$PASS" ssh \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=2 \
      -o LogLevel=ERROR \
      "$USER@$ip" "exit" 2>/dev/null; then
    printf "[OK] %s\n" "$ip"
  else
    printf "[FAIL] %s\n" "$ip"
  fi
fi
'
