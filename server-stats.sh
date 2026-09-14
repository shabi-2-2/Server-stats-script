#!/bin/bash

set -euo pipefail

get_cpu_usage() {
    if [[ -r /proc/stat ]]; then
        get_cpu_usage_linux
    else
        echo "Error: /proc/stat not found. CPU usage calculation requires Linux." >&2
        exit 1
    fi
}

get_cpu_usage_linux() {
    local -a prev curr
    local delta_idle delta_total
    local i

    mapfile -t prev < <(awk '/^cpu / {print $2, $3, $4, $5, $6, $7, $8}' /proc/stat)
    sleep 0.5
    mapfile -t curr < <(awk '/^cpu / {print $2, $3, $4, $5, $6, $7, $8}' /proc/stat)

    delta_idle=$((curr[3] + curr[4] - prev[3] - prev[4]))
    delta_total=0
    for ((i = 0; i < 7; i++)); do
        delta_total=$((delta_total + curr[i] - prev[i]))
    done

    awk -v idle="$delta_idle" -v total="$delta_total" \
        'BEGIN { printf "%.1f", 100 * (total - idle) / total }'
}

main() {
    local cpu_usage

    cpu_usage=$(get_cpu_usage)

    printf '%s\n' "Server Performance Stats"
    printf '%s\n' "========================"
    printf 'CPU Usage: %s%%\n' "$cpu_usage"
}

main "$@"