#!/usr/bin/env bash
# experimental — FEV U2 remote body. Invoked as: bash -s -- <mode> <bip> <poolBase> <poolSize> <registryMirror> <mssqlMemMb> <keepMssql>
# mode: preflight | install | verify
# Never echo passwords. SA password is generated on the remote host and discarded with the probe container.
set -uo pipefail

MODE="${1:-preflight}"
BIP="${2:-10.233.0.1/24}"
POOL_BASE="${3:-10.234.0.0/16}"
POOL_SIZE="${4:-24}"
MIRROR="${5:-}"
MSSQL_MEM_MB="${6:-1536}"
KEEP_MSSQL="${7:-false}"

MSSQL_IMAGE="mcr.microsoft.com/mssql/server:2022-latest"
PROBE_NAME="fev-u2-mssql"

mark() { echo "@@ $1=$2"; }
section() { echo "=== $1 ==="; }

preflight() {
  section preflight
  if sudo -n true 2>/dev/null; then mark SUDO_NOPASSWD yes; else mark SUDO_NOPASSWD no; fi
  if command -v docker >/dev/null 2>&1; then mark DOCKER_PRESENT yes; else mark DOCKER_PRESENT no; fi
  . /etc/os-release && mark OS "$VERSION_CODENAME"
  mark MEM_TOTAL_MB "$(free -m | awk '/^Mem:/{print $2}')"
  mark ROOT_AVAIL_GB "$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
  section routes
  ip -4 route
  section docker-hub-mirror
  if [ -n "$MIRROR" ]; then
    mark MIRROR_HTTP "$(timeout 8 curl -sS -o /dev/null -w '%{http_code}' "$MIRROR/v2/" 2>/dev/null || echo fail)"
  fi
  mark ALIYUN_DOCKER_CE_HTTP "$(timeout 8 curl -sS -o /dev/null -w '%{http_code}' https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg 2>/dev/null || echo fail)"
  mark MCR_HTTP "$(timeout 8 curl -sS -o /dev/null -w '%{http_code}' https://mcr.microsoft.com/v2/ 2>/dev/null || echo fail)"
}

install_docker() {
  section install
  if ! sudo -n true 2>/dev/null; then mark INSTALL skipped-no-sudo; return 1; fi

  # daemon.json BEFORE first dockerd start, so docker0 never takes 172.17.0.0/16 (overlaps VM eth0 172.17.56.144/28).
  local mirrors_json="[]"
  if [ -n "$MIRROR" ]; then mirrors_json="[\"$MIRROR\"]"; fi
  sudo install -d -m 0755 /etc/docker
  sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
  "bip": "$BIP",
  "default-address-pools": [ { "base": "$POOL_BASE", "size": $POOL_SIZE } ],
  "registry-mirrors": $mirrors_json,
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "5" },
  "live-restore": true
}
EOF
  mark DAEMON_JSON written

  if command -v docker >/dev/null 2>&1 && dpkg -s docker-ce >/dev/null 2>&1; then
    mark DOCKER_CE already-installed
  else
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get update -y -qq || { mark INSTALL apt-update-failed; return 1; }
    sudo -E apt-get install -y -qq ca-certificates curl gnupg >/dev/null || { mark INSTALL apt-prereq-failed; return 1; }
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg \
      || { mark INSTALL gpg-failed; return 1; }
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    . /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu ${VERSION_CODENAME} stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo -E apt-get update -y -qq || { mark INSTALL apt-update-docker-failed; return 1; }
    sudo -E apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null \
      || { mark INSTALL apt-docker-failed; return 1; }
    mark DOCKER_CE installed
  fi

  sudo systemctl enable docker containerd >/dev/null 2>&1
  sudo systemctl restart docker || { mark INSTALL dockerd-start-failed; sudo journalctl -u docker --no-pager -n 30; return 1; }
  mark INSTALL ok
}

verify() {
  section verify
  if ! sudo -n true 2>/dev/null; then mark VERIFY skipped-no-sudo; return 1; fi
  if ! command -v docker >/dev/null 2>&1; then mark DOCKER_OK no; return 1; fi

  mark DOCKER_SERVER "$(sudo docker version --format '{{.Server.Version}}' 2>/dev/null || echo none)"
  mark COMPOSE "$(sudo docker compose version --short 2>/dev/null || echo none)"
  mark DOCKER_ENABLED "$(systemctl is-enabled docker 2>/dev/null)"
  mark DOCKER_ACTIVE "$(systemctl is-active docker 2>/dev/null)"
  mark CGROUP "$(sudo docker info --format '{{.CgroupVersion}}' 2>/dev/null)"
  mark STORAGE "$(sudo docker info --format '{{.Driver}}' 2>/dev/null)"
  mark DOCKER0 "$(ip -4 -o addr show docker0 2>/dev/null | awk '{print $4}')"
  mark ETH0 "$(ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}')"
  if ip -4 route | grep -q '^172\.17\.0\.0/16'; then mark BRIDGE_OVERLAP yes; else mark BRIDGE_OVERLAP no; fi
  if [ "$(systemctl is-active docker 2>/dev/null)" = "active" ]; then mark DOCKER_OK yes; else mark DOCKER_OK no; return 1; fi

  section hello-world
  if sudo docker run --rm hello-world 2>&1 | grep -q 'Hello from Docker'; then mark HELLO_OK yes; else mark HELLO_OK no; fi

  section mssql
  sudo docker rm -f "$PROBE_NAME" >/dev/null 2>&1 || true
  local sa
  sa="U2a!$(openssl rand -hex 12)"
  local t0; t0=$(date +%s)
  if ! sudo docker pull -q "$MSSQL_IMAGE" >/dev/null 2>&1; then mark MSSQL_PULL failed; mark MSSQL_OK no; return 0; fi
  mark MSSQL_PULL ok
  mark MSSQL_PULL_SECONDS "$(( $(date +%s) - t0 ))"
  sudo docker run -d --name "$PROBE_NAME" \
    -e ACCEPT_EULA=Y -e MSSQL_PID=Express -e "MSSQL_SA_PASSWORD=$sa" \
    -e "MSSQL_MEMORY_LIMIT_MB=$MSSQL_MEM_MB" -e MSSQL_COLLATION=Chinese_PRC_CI_AS -e TZ=Asia/Shanghai \
    "$MSSQL_IMAGE" >/dev/null 2>&1 || { mark MSSQL_RUN failed; mark MSSQL_OK no; return 0; }

  local ok=no i
  for i in $(seq 1 40); do
    if sudo docker exec "$PROBE_NAME" /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$sa" -b -Q "SELECT 1" >/dev/null 2>&1; then ok=yes; break; fi
    sleep 3
  done
  mark MSSQL_READY_SECONDS "$(( $(date +%s) - t0 ))"
  if [ "$ok" = yes ]; then
    sudo docker exec "$PROBE_NAME" /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$sa" -b -h -1 -W -Q \
      "SET NOCOUNT ON; CREATE DATABASE fev_u2_probe; SELECT 'MSSQL_VERSION=' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(64)) + ' ' + CAST(SERVERPROPERTY('Edition') AS nvarchar(128)); SELECT 'MSSQL_COLLATION=' + CAST(SERVERPROPERTY('Collation') AS nvarchar(64)); SELECT 'MSSQL_DB_CREATED=' + name FROM sys.databases WHERE name='fev_u2_probe';" 2>&1 \
      | sed -n 's/^\(MSSQL_[A-Z_]*\)=\(.*\)$/@@ \1=\2/p'
    mark MSSQL_MEM_USAGE "$(sudo docker stats --no-stream --format '{{.MemUsage}}' "$PROBE_NAME" 2>/dev/null)"
    mark MSSQL_OK yes
  else
    mark MSSQL_OK no
    sudo docker logs --tail 30 "$PROBE_NAME" 2>&1 | sed 's/^/  mssql-log: /'
  fi

  if [ "$KEEP_MSSQL" != "true" ]; then
    sudo docker rm -f "$PROBE_NAME" >/dev/null 2>&1 && mark MSSQL_PROBE_REMOVED yes
  fi
  section host-after
  mark MEM_AVAILABLE_MB "$(free -m | awk '/^Mem:/{print $7}')"
  mark ROOT_AVAIL_GB "$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
}

case "$MODE" in
  preflight) preflight ;;
  install)   preflight; install_docker ;;
  verify)    verify ;;
  all)       preflight; install_docker && verify ;;
  *) echo "unknown mode $MODE"; exit 2 ;;
esac
exit 0
