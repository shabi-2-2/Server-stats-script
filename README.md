# Server Performance Stats

A Linux Bash script that reports server performance statistics: CPU usage, memory usage, disk usage, and top processes by CPU and memory.

This project is based on the [roadmap.sh Server Performance Stats](https://roadmap.sh/projects/server-stats) project.

The script targets **Linux** only.

## Status

Current phase: **Phase 02 - CPU Statistics (complete)**

Completed phases:

- **Phase 01 - Setup**: Project structure, executable script, strict shell settings.
- **Phase 02 - CPU Statistics**: Total CPU usage percentage, calculated from `/proc/stat`.

Not yet implemented (planned for later phases):

- Total memory usage
- Total disk usage
- Top 5 processes by CPU usage
- Top 5 processes by memory usage
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

## Usage

```sh
./server-stats.sh
```

## Example Output

```
Server Performance Stats
========================
CPU Usage: 23.4%
```

## Requirements

- Linux operating system with `/proc/stat`
- Bash 4+ (required for `mapfile`)
- No external dependencies