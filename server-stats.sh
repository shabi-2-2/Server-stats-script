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

get_os_version() {
    local version

    if [[ -r /etc/os-release ]]; then
        version=$(awk -F= '/^PRETTY_NAME=/ {gsub(/["\r]/, "", $2); print $2}' /etc/os-release)
        if [[ -n "$version" ]]; then
            echo "$version"
            return
        fi
    fi

    echo "N/A (no /etc/os-release)"
}

get_uptime() {
    local seconds days hours minutes text=""

    if [[ ! -r /proc/uptime ]]; then
        echo "N/A (no /proc/uptime)"
        return
    fi

    seconds=$(awk '{print int($1)}' /proc/uptime)
    if [[ ! "$seconds" =~ ^[0-9]+$ ]]; then
        echo "N/A (invalid /proc/uptime)"
        return
    fi

    days=$((seconds / 86400))
    hours=$(((seconds % 86400) / 3600))
    minutes=$(((seconds % 3600) / 60))

    [[ $days -gt 0 ]] && text+="$days days, "
    [[ $hours -gt 0 ]] && text+="$hours hours, "
    [[ $minutes -gt 0 ]] && text+="$minutes minutes, "
    text=${text%, }

    if [[ -n "$text" ]]; then
        echo "$text"
    else
        echo "less than a minute"
    fi
}

get_load_average() {
    local load

    if [[ ! -r /proc/loadavg ]]; then
        echo "N/A (no /proc/loadavg)"
        return
    fi

    load=$(awk '{print $1, $2, $3}' /proc/loadavg)
    if [[ -z "$load" ]]; then
        echo "N/A (invalid /proc/loadavg)"
        return
    fi

    echo "${load// /, }"
}

get_logged_in_users() {
    local count

    if ! command -v who >/dev/null 2>&1; then
        echo "N/A (who not found)"
        return
    fi

    count=$( (who 2>/dev/null || true) | wc -l | tr -d ' ' )
    echo "$count"
}

get_failed_logins() {
    local count logfile=""

    if [[ -r /var/log/auth.log ]]; then
        logfile=/var/log/auth.log
    elif [[ -r /var/log/secure ]]; then
        logfile=/var/log/secure
    fi

    if [[ -z "$logfile" ]]; then
        echo "N/A (no readable auth log found)"
        return
    fi

    count=$(grep -Ec "Failed password|authentication failure" "$logfile" 2>/dev/null || true)
    if [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "$count"
    else
        echo "N/A (could not read $logfile)"
    fi
}

get_system_info() {
    printf '%s\n' "System Information"
    printf '%s\n' "------------------"
    printf 'OS: %s\n' "$(get_os_version)"
    printf 'Uptime: %s\n' "$(get_uptime)"
    printf 'Load Average: %s\n' "$(get_load_average)"
    printf 'Logged-in Users: %s\n' "$(get_logged_in_users)"
    printf 'Failed Login Attempts: %s\n' "$(get_failed_logins)"
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
    printf '\n'
    get_system_info
}

main "$@"