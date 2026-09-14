# Server Performance Stats

A Linux Bash script that reports server performance statistics: CPU usage, memory usage, disk usage, and top processes by CPU and memory.

This project is based on the [roadmap.sh Server Performance Stats](https://roadmap.sh/projects/server-stats) project.

## Status

Current phase: **Phase 01 - Setup**

The project is set up with a minimal, executable script. Statistics logic is intentionally not implemented yet and will be added phase by phase.

## Planned Statistics

The final script will report:

- Total CPU usage
- Total memory usage
- Total disk usage
- Top 5 processes by CPU usage
- Top 5 processes by memory usage
- Optional system information (OS version, uptime, load average, logged-in users, failed login attempts)

## Usage

```sh
./server-stats.sh
```

## Requirements

- Linux operating system
- Bash
- No external dependencies