#!/usr/bin/env bash
set -euo pipefail
echo '=== os-release ==='
cat /etc/os-release 2>/dev/null || true
echo '=== uname ==='
uname -a
echo '=== virt ==='
if command -v systemd-detect-virt >/dev/null 2>&1; then
  systemd-detect-virt || true
else
  echo 'systemd-detect-virt:missing'
fi
echo '=== hostnamectl ==='
hostnamectl 2>/dev/null || true
echo '=== cpu-virt-flags ==='
grep -E 'hypervisor|vmx|svm' /proc/cpuinfo 2>/dev/null | sort -u | head -n 20 || true
echo '=== lscpu-summary ==='
lscpu 2>/dev/null | grep -E 'Architecture|CPU\(s\)|Model name|Hypervisor|Virtualization|Vendor' || true
echo '=== wsl-hint ==='
if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then echo 'WSLInterop:present'; else echo 'WSLInterop:absent'; fi
if [ -d /mnt/c/Windows ]; then echo 'mnt-c-Windows:present'; else echo 'mnt-c-Windows:absent'; fi
