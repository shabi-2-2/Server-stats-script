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

get_memory_usage() {
    if [[ ! -r /proc/meminfo ]]; then
        echo "Error: /proc/meminfo not found or not readable. Memory statistics require Linux." >&2
        exit 1
    fi

    awk '
        /^MemTotal:/     { total = $2 }
        /^MemAvailable:/ { available = $2 }
        END {
            if (total <= 0 || available < 0) {
                print "Error: invalid /proc/meminfo data." > "/dev/stderr"
                exit 1
            }
            used = total - available
            printf "Memory Usage: %.1f%%\n", (used / total) * 100
            printf "Memory Used: %.2f GiB\n", used / (1024 * 1024)
            printf "Memory Available: %.2f GiB\n", available / (1024 * 1024)
            printf "Memory Total: %.2f GiB\n", total / (1024 * 1024)
        }
    ' /proc/meminfo
}

main() {
    local cpu_usage

    cpu_usage=$(get_cpu_usage)

    printf '%s\n' "Server Performance Stats"
    printf '%s\n' "========================"
    printf 'CPU Usage: %s%%\n' "$cpu_usage"
    printf '\n'
    get_memory_usage
}

main "$@"