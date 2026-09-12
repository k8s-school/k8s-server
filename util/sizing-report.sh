#!/bin/bash

# Sizing report for the OpenTelemetry training server. Run it AS ROOT ON THE
# SERVER, during a session or a rehearsal:
#
#   make ssh FLAVOR=otel            # from provisioning/, lands you as root
#   /opt/otel/util/sizing-report.sh # or scp this file over and run it
#
# It answers the one question the desk calculation cannot: what a participant
# actually costs, stack AND Guacamole desktop together, on this machine. Feed
# the totals back into otel-labs' NOTE-dimensionnement-serveur.md.
#
# Memory is reported as PSS, not RSS: ten Firefox processes share their
# libraries, and summing RSS would count that memory ten times over. PSS gives
# each process its fair share of what it shares, so the per-participant figures
# actually add up to the machine total.

set -uo pipefail

# printf/awk parse "2.01" as a number only under a C locale: on a French system
# LC_NUMERIC expects a comma and every float in this report becomes an error.
export LC_ALL=C

command -v docker > /dev/null || { echo "ERROR: docker not found — is this the training server?"; exit 1; }
[ "$(id -u)" -eq 0 ] || echo "WARNING: not root — desktop memory will be under-reported (other users' processes are invisible)." >&2

# --- machine ----------------------------------------------------------------
mem_total=$(awk '/MemTotal/ {printf "%.0f", $2/1048576}' /proc/meminfo)
mem_avail=$(awk '/MemAvailable/ {printf "%.0f", $2/1048576}' /proc/meminfo)
echo "=== Machine ==="
printf '  %-22s %s vCPU\n' "CPU" "$(nproc)"
printf '  %-22s %s GiB total, %s GiB available\n' "RAM" "$mem_total" "$mem_avail"
printf '  %-22s %s\n' "Disk /" "$(df -h --output=size,used,avail,pcent / | tail -1 | tr -s ' ')"
printf '  %-22s %.2f\n' "Load (1/5/15 min)" "$(cut -d' ' -f1 /proc/loadavg)"
echo

# Total PSS of every process owned by $1, in GiB. smaps_rollup is one read per
# process instead of parsing the whole smaps; a process that exits mid-loop just
# contributes nothing.
user_pss() {
    local user=$1 total=0 pid
    for pid in $(pgrep -u "$user" 2>/dev/null); do
        local p
        p=$(awk '/^Pss:/ {s+=$2} END {print s+0}' "/proc/$pid/smaps_rollup" 2>/dev/null) || continue
        total=$((total + ${p:-0}))
    done
    awk -v k="$total" 'BEGIN {printf "%.2f", k/1048576}'
}

# One docker stats call for everything: it costs a full sampling window per
# invocation, so calling it per participant would take a minute for nothing.
stats=$(docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}' 2>/dev/null)

# --- participants -----------------------------------------------------------
printf '=== Per participant ===\n'
printf '  %-10s %-10s %10s %10s %12s\n' USER CLUSTER 'STACK RAM' 'STACK CPU' 'DESKTOP PSS'
n=0; sum_stack=0; sum_desk=0
for home in /home/*; do
    user=$(basename "$home")
    id "$user" > /dev/null 2>&1 || continue
    case "$user" in student*|trainer) ;; *) continue ;; esac

    line=$(printf '%s\n' "$stats" | grep "^${user}-control-plane|" || true)
    if [ -n "$line" ]; then
        cluster="up"
        cpu=$(echo "$line" | cut -d'|' -f2)
        ram=$(echo "$line" | cut -d'|' -f3 | awk '{print $1}')
        # docker prints GiB or MiB — normalise to GiB for the sum. Strip the
        # unit first in both branches: awk would coerce "512MiB" to 512 on its
        # own, but only by accident, and a future unit would break it silently.
        ram_g=$(echo "$ram" | awk '
            /MiB/ {gsub(/[A-Za-z]/, ""); printf "%.2f\n", $0/1024; next}
                  {gsub(/[A-Za-z]/, ""); printf "%.2f\n", $0}')
    else
        cluster="-"; cpu="-"; ram_g="0.00"
    fi

    desk=$(user_pss "$user")
    printf '  %-10s %-10s %10s %10s %12s\n' "$user" "$cluster" "$ram_g" "$cpu" "$desk"
    n=$((n + 1))
    sum_stack=$(awk -v a="$sum_stack" -v b="$ram_g" 'BEGIN {print a+b}')
    sum_desk=$(awk -v a="$sum_desk" -v b="$desk" 'BEGIN {print a+b}')
done

[ "$n" -eq 0 ] && { echo "  (no student/trainer account found)"; exit 0; }

# --- what it means ----------------------------------------------------------
echo
echo "=== Totals over $n account(s) ==="
awk -v s="$sum_stack" -v d="$sum_desk" -v n="$n" -v tot="$mem_total" -v av="$mem_avail" '
BEGIN {
  printf "  %-34s %.1f GiB\n", "Stacks (kind nodes)", s
  printf "  %-34s %.1f GiB\n", "Desktops (XFCE + Firefox)", d
  printf "  %-34s %.1f GiB\n", "Base system (rest of the RAM used)", tot-av-s-d
  printf "\n"
  if (n > 0) printf "  %-34s %.2f GiB stack + %.2f GiB desktop = %.2f GiB\n", \
                    "Cost of ONE participant", s/n, d/n, (s+d)/n
  printf "  %-34s %.0f GiB\n", "Extrapolated to 11 (10 + trainer)", (tot-av-s-d) + 11*(s+d)/n
  printf "\n  A GP1-L has 128 GiB. Under ~115 the room fits with the lab 2 build peak.\n"
}'
echo
echo "Disk, the resource that runs out first:"
docker system df 2>/dev/null | sed 's/^/  /'
