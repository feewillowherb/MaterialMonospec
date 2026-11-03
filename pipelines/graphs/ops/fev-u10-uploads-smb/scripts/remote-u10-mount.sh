#!/usr/bin/env bash
# experimental — FEV U10 mount test. Invoked as: bash <(...) <unc> <credPath> <mountPoint> <write:yes|no>
# Read-only mount unless write=yes; write=yes creates and deletes one file under <share>/_probe/ only.
set -uo pipefail

UNC="${1:?unc}"
CRED="${2:-/etc/um-uploads.cred}"
MP="${3:-/mnt/um-uploads-probe}"
WRITE="${4:-no}"

mark() { echo "@@ $1=$2"; }
section() { echo "=== $1 ==="; }
ms_since() { echo $(( ($(date +%s%N) - $1) / 1000000 )); }

cleanup() {
  if mountpoint -q "$MP"; then sudo -n umount "$MP" && mark UNMOUNT ok || mark UNMOUNT failed; fi
  sudo -n rmdir "$MP" 2>/dev/null || true
}
trap cleanup EXIT

section preconditions
if sudo -n true 2>/dev/null; then mark SUDO_NOPASSWD yes; else mark SUDO_NOPASSWD no; exit 3; fi
if command -v mount.cifs >/dev/null 2>&1; then mark CIFS_UTILS yes; else mark CIFS_UTILS no; exit 3; fi
if sudo -n test -f "$CRED"; then mark CRED present; else mark CRED missing; exit 3; fi

section mount
sudo -n mkdir -p "$MP"
if mountpoint -q "$MP"; then sudo -n umount "$MP"; fi
OPTS="credentials=$CRED,uid=1654,gid=1654,file_mode=0664,dir_mode=0775,noserverino"
if [ "$WRITE" != "yes" ]; then OPTS="ro,$OPTS"; fi
if sudo -n mount -t cifs "$UNC" "$MP" -o "$OPTS" 2>/tmp/u10-mount.err; then
  mark MOUNT ok
else
  mark MOUNT failed
  mark MOUNT_ERROR "$(tr '\n' ' ' </tmp/u10-mount.err)"
  sudo -n dmesg 2>/dev/null | grep -i cifs | tail -n 5
  exit 4
fi
mark MOUNT_MODE "$(if [ "$WRITE" = "yes" ]; then echo rw; else echo ro; fi)"
mark SMB_VERS "$(grep " $MP " /proc/mounts | grep -o 'vers=[^,]*' | head -1 | cut -d= -f2)"

section read
start=$(date +%s%N)
mark TOP_DIRS "$(find "$MP" -mindepth 1 -maxdepth 1 -type d | wc -l)"
mark LIST_MS "$(ms_since "$start")"
if [ -d "$MP/_tus" ]; then mark TUS_DIR present; else mark TUS_DIR absent; fi
sample="$(find "$MP" -mindepth 2 -maxdepth 2 -type f -iname '*.jpg' 2>/dev/null | head -1)"
if [ -n "$sample" ]; then
  mark SAMPLE "${sample#"$MP"/}"
  mark SAMPLE_BYTES "$(stat -c %s "$sample")"
  start=$(date +%s%N)
  if cat "$sample" >/dev/null; then mark READ ok; else mark READ failed; fi
  mark READ_MS "$(ms_since "$start")"
  dir="$(dirname "$sample")"
  start=$(date +%s%N)
  n=0
  for f in $(find "$dir" -maxdepth 1 -type f | head -20); do stat -c %s "$f" >/dev/null && n=$((n + 1)); done
  mark STAT_COUNT "$n"
  mark STAT_TOTAL_MS "$(ms_since "$start")"
else
  mark SAMPLE none
  mark READ skipped
fi

section write
if [ "$WRITE" = "yes" ]; then
  probe_dir="$MP/_probe"
  probe="$probe_dir/u10-$(date +%Y%m%dT%H%M%S)-$$.bin"
  sudo -n mkdir -p "$probe_dir"
  head -c 204800 /dev/urandom > /tmp/u10-probe.bin
  start=$(date +%s%N)
  if sudo -n cp /tmp/u10-probe.bin "$probe"; then mark WRITE ok; else mark WRITE failed; fi
  mark WRITE_MS "$(ms_since "$start")"
  start=$(date +%s%N)
  if sudo -n cmp -s /tmp/u10-probe.bin "$probe"; then mark READBACK ok; else mark READBACK mismatch; fi
  mark READBACK_MS "$(ms_since "$start")"
  sudo -n rm -f "$probe" && mark DELETE ok || mark DELETE failed
  sudo -n rmdir "$probe_dir" 2>/dev/null && mark PROBE_DIR removed || mark PROBE_DIR kept
  rm -f /tmp/u10-probe.bin
else
  mark WRITE skipped
fi
