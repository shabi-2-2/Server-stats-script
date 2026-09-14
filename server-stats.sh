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

get_disk_usage() {
    local df_output

    if ! command -v df >/dev/null 2>&1; then
        echo "Error: df command not found. Disk statistics require GNU df." >&2
        exit 1
    fi

    df_output=$(df -B1 / 2>/dev/null) || {
        echo "Error: could not inspect the root filesystem /." >&2
        exit 1
    }

    awk '
        NR > 1 && $NF == "/" {
            total = $2
            used = $3
            available = $4
        }
        END {
            if (total <= 0 || used < 0 || available < 0) {
                print "Error: invalid df output for /." > "/dev/stderr"
                exit 1
            }
            printf "Disk Usage: %.1f%%\n", (used / total) * 100
            printf "Disk Used: %.2f GiB\n", used / (1024 * 1024 * 1024)
            printf "Disk Available: %.2f GiB\n", available / (1024 * 1024 * 1024)
            printf "Disk Total: %.2f GiB\n", total / (1024 * 1024 * 1024)
        }
    ' <<< "$df_output"
}

get_process_table() {
    local sort_key=$1
    local title=$2
    local output sep

    output=$(ps -eo pid,user,pcpu,pmem,comm --sort="${sort_key}" 2>/dev/null) || {
        echo "Error: could not retrieve process listing from ps." >&2
        exit 1
    }

    printf '%s\n' "$title"
    printf -v sep '%*s' "${#title}" ""
    printf '%s\n' "${sep// /-}"
    printf '%-7s %-12s %6s %6s  %s\n' "PID" "USER" "CPU%" "MEM%" "COMMAND"
    awk '
        NR > 1 {
            if ($5 == "ps") next
            printf "%-7s %-12s %6.1f %6.1f  %s\n", $1, $2, $3, $4, $5
            if (++count == 5) exit
        }
    ' <<< "$output"
}

get_process_stats() {
    if ! command -v ps >/dev/null 2>&1; then
        echo "Error: ps command not found. Process statistics require procps." >&2
        exit 1
    fi

    get_process_table "-pcpu" "Top 5 Processes by CPU Usage"
    printf '\n'
    get_process_table "-pmem" "Top 5 Processes by Memory Usage"
}

main() {
    local cpu_usage

    cpu_usage=$(get_cpu_usage)

    printf '%s\n' "Server Performance Stats"
    printf '%s\n' "========================"
    printf 'CPU Usage: %s%%\n' "$cpu_usage"
    printf '\n'
    get_memory_usage
    printf '\n'
    get_disk_usage
    printf '\n'
    get_process_stats
}

main "$@"