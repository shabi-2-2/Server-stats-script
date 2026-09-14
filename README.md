# Server Performance Stats

A Linux Bash script that reports server performance statistics: CPU usage, memory usage, disk usage, and top processes by CPU and memory.

This project is based on the [roadmap.sh Server Performance Stats](https://roadmap.sh/projects/server-stats) project.

The script targets **Linux** only.

## Status

Current phase: **Phase 04 - Disk Statistics (complete)**

Next phase: **Phase 05 - Process Statistics**

Completed phases:

- **Phase 01 - Setup**: Project structure, executable script, strict shell settings.
- **Phase 02 - CPU Statistics**: Total CPU usage percentage, calculated from `/proc/stat`.
- **Phase 03 - Memory Statistics**: Total, used, and available memory plus usage percentage, read from `/proc/meminfo`.
- **Phase 04 - Disk Statistics**: Total, used, and available disk space for `/`, plus usage percentage, collected with `df -B1 /`.
- **Phase 05 - Process Statistics**: Top 5 processes by CPU usage and top 5 by memory usage, collected with `ps`.

Not yet implemented (planned for later phases):

- Optional system information (OS version, uptime, load average, logged-in users, failed login attempts)

## How CPU Usage Is Calculated

CPU usage is derived from `/proc/stat` using the classic two-sample method:

1. Read the aggregate `cpu` line from `/proc/stat`.
2. Wait 0.5 seconds.
3. Read the `cpu` line a second time.
4. Compute the deltas between samples for idle time (idle + iowait) and total time (user + nice + system + idle + iowait + irq + softirq).
5. Usage percentage = `(total_delta - idle_delta) / total_delta * 100`.

Because the sample interval is very short, the result reflects current CPU activity rather than system lifetime averages.

If `/proc/stat` is unavailable, the script prints a clear error message and exits with a non-zero status.

## How Memory Usage Is Calculated

Memory statistics come from `/proc/meminfo`:

- `MemTotal` - total system memory in kB
- `MemAvailable` - estimated memory available for starting new applications, in kB

From those values:

- Used memory = `MemTotal - MemAvailable`
- Usage percentage = `(Used memory / MemTotal) * 100`

Values (reported in KiB by `/proc/meminfo`) are converted to GiB (KiB / 1024 / 1024).

If `/proc/meminfo` is missing or unreadable, the script prints a clear error message and exits with a non-zero status.

## How Disk Usage Is Calculated

Disk statistics cover the root filesystem `/` only and are collected with:

```sh
df -B1 /
```

`-B1` forces `df` to report sizes in bytes, so calculations do not rely on human-readable output. The script skips the header row, picks the data row whose mount point is `/`, and reads:

- Total disk space (bytes)
- Used disk space (bytes)
- Available disk space (bytes)

From those raw values:

- Disk usage percentage = `(Used / Total) * 100`
- GiB display values = `bytes / (1024 * 1024 * 1024)`

The percentage is computed from the actual used and total values rather than trusting `df`'s `Use%` column.

Error handling covers: `df` not being available, the root filesystem not being inspectable, and invalid output values. Each case prints a clear error and exits with a non-zero status.

If `/proc/meminfo` is missing or unreadable, the script prints a clear error message and exits with a non-zero status.

## How Process Statistics Are Calculated

Process information is collected with the standard Linux `ps` command. The script displays the **top 5 processes by CPU usage** and the **top 5 processes by memory usage**, showing PID, USER, CPU%, MEM%, and COMMAND for each.

Sorting is delegated to `ps` via its built-in sort option rather than sorting in Bash:

- Top by CPU: `ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu` (descending by CPU usage)
- Top by memory: `ps -eo pid,user,pcpu,pmem,comm --sort=-pmem` (descending by memory usage)

The header row is skipped and the process list is trimmed to exactly 5 rows. The `ps` process itself is filtered out if it appears in its own output, so it does not occupy one of the top-5 slots.

If `ps` is unavailable or cannot produce a process listing, the script prints a clear error and exits with a non-zero status.

## Usage

```sh
./server-stats.sh
```

## Example Output

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
```

## Requirements

- Linux operating system with `/proc/stat`, `/proc/meminfo`, and GNU `df`
- Bash 4+ (required for `mapfile`)
- No external dependencies