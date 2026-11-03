#!/usr/bin/env bash
# experimental — FEV U10 VM setup. Invoked as: bash <(...) <smbUser> <smbDomain> <credPath>
# stdin line 1: sudo password of the SSH user (empty when sudo is already passwordless)
# stdin line 2: SMB account password (empty to keep the existing credentials file)
# Passwords are only read from stdin and passed through pipes / bash builtins; never echoed or put in argv.
set -uo pipefail

SMB_USER="${1:-um-uploads}"
SMB_DOMAIN="${2:-WORKGROUP}"
CRED="${3:-/etc/um-uploads.cred}"

mark() { echo "@@ $1=$2"; }
section() { echo "=== $1 ==="; }

IFS= read -r SUDO_PW || true
IFS= read -r SMB_PW || true
SUDO_PW="${SUDO_PW#$'\xef\xbb\xbf'}"
if printf '%s%s' "$SUDO_PW" "$SMB_PW" | LC_ALL=C grep -q '[^[:print:]]'; then
  mark STDIN_CLEAN no
  mark STDIN_NONPRINT_LINE1 "$(printf '%s' "$SUDO_PW" | LC_ALL=C tr -d '[:print:]' | od -An -tx1 | tr -s ' ')"
  mark STDIN_NONPRINT_LINE2 "$(printf '%s' "$SMB_PW" | LC_ALL=C tr -d '[:print:]' | od -An -tx1 | tr -s ' ')"
  exit 3
fi
mark STDIN_CLEAN yes
ME="$(id -un)"
DROPIN="/etc/sudoers.d/90-${ME}-ops"

section sudo
if sudo -n true 2>/dev/null; then
  mark SUDO_BEFORE nopasswd
else
  mark SUDO_BEFORE password
  if [ -z "$SUDO_PW" ]; then mark SUDO_SETUP no-password-given; exit 3; fi
  if ! printf '%s\n' "$SUDO_PW" | sudo -S -p '' true 2>/dev/null; then mark SUDO_SETUP bad-password; exit 3; fi
  tmp="$(mktemp)"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$ME" > "$tmp"
  if printf '%s\n' "$SUDO_PW" | sudo -S -p '' visudo -cf "$tmp" >/dev/null 2>&1 &&
     printf '%s\n' "$SUDO_PW" | sudo -S -p '' install -m 0440 -o root -g root "$tmp" "$DROPIN"; then
    mark SUDO_SETUP installed
  else
    mark SUDO_SETUP failed
    rm -f "$tmp"
    exit 3
  fi
  rm -f "$tmp"
fi
unset SUDO_PW
if sudo -n visudo -c >/dev/null 2>&1; then mark SUDOERS_VALID yes; else mark SUDOERS_VALID no; fi
if sudo -n true 2>/dev/null; then mark SUDO_NOPASSWD yes; else mark SUDO_NOPASSWD no; exit 3; fi

section cifs-utils
if command -v mount.cifs >/dev/null 2>&1; then
  mark CIFS_UTILS already
elif sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y -q cifs-utils >/tmp/u10-apt.log 2>&1; then
  mark CIFS_UTILS installed
else
  mark CIFS_UTILS failed
  tail -n 20 /tmp/u10-apt.log
fi
mark CIFS_UTILS_VERSION "$(dpkg-query -W -f='${Version}' cifs-utils 2>/dev/null)"

section credentials
if [ -n "$SMB_PW" ]; then
  if printf 'username=%s\npassword=%s\ndomain=%s\n' "$SMB_USER" "$SMB_PW" "$SMB_DOMAIN" |
     sudo -n sh -c 'umask 077; cat > "$1"' _ "$CRED"; then
    mark CRED written
  else
    mark CRED failed
  fi
else
  mark CRED skipped
fi
unset SMB_PW
mark CRED_STAT "$(sudo -n stat -c '%a %U:%G' "$CRED" 2>/dev/null || echo missing)"
