#!/usr/bin/env bash
# experimental — FEV U10 remote body (reach). Invoked as: bash -s -- <stableHost> <controlPort> <timeoutSec>
# Read-only: TCP connects only, no mount, no package install.
set -uo pipefail

STABLE="${1:-191.12.234.212}"
CONTROL="${2:-47123}"
TIMEOUT="${3:-3}"

mark() { echo "@@ $1=$2"; }
section() { echo "=== $1 ==="; }

probe() {
  local label="$1" host="$2" port="$3" start end rc
  start=$(date +%s%N)
  timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null
  rc=$?
  end=$(date +%s%N)
  if [ "$rc" -eq 0 ]; then
    mark "$label" open
    mark "${label}_MS" "$(( (end - start) / 1000000 ))"
  elif [ "$rc" -eq 124 ]; then
    mark "$label" timeout
  else
    mark "$label" closed
  fi
}

section network
ip -4 -o addr show
ip -4 route
GW=$(ip -4 route show default | awk '{print $3; exit}')
mark GATEWAY "${GW:-none}"
mark ETH0 "$(ip -4 -o addr show dev eth0 2>/dev/null | awk '{print $4; exit}')"
mark STABLE_HOST "$STABLE"
mark CONTROL_PORT "$CONTROL"

section reach
if [ -n "${GW:-}" ]; then
  probe GW_445 "$GW" 445
  probe GW_CONTROL "$GW" "$CONTROL"
fi
probe STABLE_445 "$STABLE" 445
probe STABLE_CONTROL "$STABLE" "$CONTROL"

section cifs-client
mark KERNEL "$(uname -r)"
if modinfo cifs >/dev/null 2>&1; then mark CIFS_MODULE yes; else mark CIFS_MODULE no; fi
if command -v mount.cifs >/dev/null 2>&1; then mark CIFS_UTILS yes; else mark CIFS_UTILS no; fi
mark CIFS_UTILS_CANDIDATE "$(apt-cache policy cifs-utils 2>/dev/null | awk '/Candidate:/{print $2; exit}')"
if sudo -n true 2>/dev/null; then mark SUDO_NOPASSWD yes; else mark SUDO_NOPASSWD no; fi
