# Server Performance Stats

A Linux Bash script that reports a snapshot of server performance: CPU usage, memory usage, disk usage, the top processes by CPU and memory, and general system information.

This project is based on the [roadmap.sh Server Performance Stats](https://roadmap.sh/projects/server-stats) project.

## Features

- Total CPU usage
- Total memory usage (used, available, total, and usage percentage)
- Total disk usage for the root filesystem `/` (used, available, total, and usage percentage)
- Top 5 processes by CPU usage
- Top 5 processes by memory usage
- OS version
- Uptime
- Load average (1, 5, and 15 minutes)
- Logged-in users
- Failed login attempts

## Requirements

- Linux operating system
- Bash 4+ (required for `mapfile`)
- Standard Linux utilities: `awk`, `df`, `ps`, `grep`, `who`
- No external libraries or packages

## Usage

```sh
chmod +x server-stats.sh
./server-stats.sh
```

## Example Output

All values below are illustrative.

```
Server Performance Stats
========================

CPU Usage: 23.4%

Memory Usage: 41.2%
Memory Used: 6.59 GiB
Memory Available: 9.41 GiB
Memory Total: 16.00 GiB

Disk Usage: 62.5%
Disk Used: 25.00 GiB
Disk Available: 15.00 GiB
Disk Total: 40.00 GiB

Top 5 Processes by CPU Usage
----------------------------
PID     USER         CPU%   MEM%  COMMAND
1234    user         25.4    2.1  web-server
2345    dbuser       12.1    8.7  postgres
3456    root          9.3    0.4  systemd
4567    user          7.8    1.2  sshd
5678    app           5.2    3.3  node

Top 5 Processes by Memory Usage
-------------------------------
PID     USER         CPU%   MEM%  COMMAND
2345    dbuser       12.1    8.7  postgres
1234    user         25.4    2.1  web-server
6789    cache         0.4    6.2  redis-server
5678    app           5.2    3.3  node
7890    user          1.1    2.8  chrome

System Information
------------------
OS: Ubuntu 24.04 LTS
Uptime: 2 days, 4 hours
Load Average: 0.42, 0.38, 0.31
Logged-in Users: 2
Failed Login Attempts: 5
```

## Implementation

| Statistic | Source | Calculation |
| --- | --- | --- |
| CPU usage | `/proc/stat` | Two samples taken 0.5 s apart; usage = `(total_delta - idle_delta) / total_delta * 100` |
| Memory | `/proc/meminfo` | Used = `MemTotal - MemAvailable`; usage = `used / MemTotal * 100`; KiB converted to GiB |
| Disk | `df -B1 /` | Values read in bytes; usage = `used / total * 100`; bytes converted to GiB |
| Top processes | `ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu` / `--sort=-pmem` | Descending sort delegated to `ps`; trimmed to 5 rows; the `ps` process itself is excluded |
| OS version | `/etc/os-release` | `PRETTY_NAME` field |
| Uptime | `/proc/uptime` | Seconds formatted as days/hours/minutes |
| Load average | `/proc/loadavg` | First three fields |
| Logged-in users | `who` | Output lines counted |
| Failed login attempts | `/var/log/auth.log` or `/var/log/secure` | Matches of `Failed password` / `authentication failure` counted |

Mandatory statistics (CPU, memory, disk, processes) fail with a clear error and a non-zero exit status when their sources are unusable. Optional system statistics degrade gracefully: each one is reported as `N/A` with a short explanation instead of stopping the script.

## Limitations

- **Linux only.** The script reads `/proc` files and uses GNU-extended `df -B1` and procps `ps` options. It does not support macOS or Windows.
- Failed-login statistics depend on the distribution, permissions, and authentication setup. Systems that log exclusively through `journald` (with no on-disk auth log) or whose auth logs require root privileges will report `N/A`. The count is not guaranteed on every system.
- The number of logged-in users is derived from `who` (utmp); systems using session managers that do not populate utmp may under-report.
- `mapfile` requires Bash 4+; very old Linux distributions with Bash 3.x are not supported.
- The script was developed and unit/function-tested on macOS using simulated Linux sources. It must be validated end-to-end on a real Linux host before deployment; no Linux integration test was performed during development.

## Project Status

**Complete.**

All phases are implemented and committed:

- Phase 01 - Setup
- Phase 02 - CPU statistics
- Phase 03 - Memory statistics
- Phase 04 - Disk statistics
- Phase 05 - Process statistics
- Phase 06 - Optional system statistics
- Final polish and testing