
#!/bin/bash

# Server Stats Script
# Works on most Linux distributions

echo "===================================="
echo "       SERVER PERFORMANCE STATS"
echo "===================================="

# 1. Total CPU Usage
echo
echo "---- CPU USAGE ----"
if command -v mpstat >/dev/null 2>&1; then
    mpstat 1 1 | awk '/Average/ && $NF ~ /^[0-9.]+$/ {printf "CPU Usage: %.2f%%\n", 100-$NF}'
else
    read cpu user nice system idle iowait irq softirq steal rest < /proc/stat
    total1=$((user+nice+system+idle+iowait+irq+softirq+steal))
    idle1=$((idle+iowait))
    sleep 1
    read cpu user nice system idle iowait irq softirq steal rest < /proc/stat
    total2=$((user+nice+system+idle+iowait+irq+softirq+steal))
    idle2=$((idle+iowait))
    total_diff=$((total2-total1))
    idle_diff=$((idle2-idle1))
    if [ "$total_diff" -gt 0 ]; then
        awk -v t="$total_diff" -v i="$idle_diff" \
            'BEGIN {printf "CPU Usage: %.2f%%\n", (t-i)*100/t}'
    else
        echo "CPU Usage: Unable to calculate"
    fi
fi

# 2. Memory Usage
echo
echo "---- MEMORY USAGE ----"
free -h
free | awk '/Mem:/ {
    used=$3; total=$2;
    printf "Memory Used: %.2f%%\n", used*100/total
}'

# 3. Disk Usage
echo
echo "---- DISK USAGE ----"
df -h -x tmpfs -x devtmpfs
df -P -x tmpfs -x devtmpfs | awk '
NR>1 {
    used=$3; available=$4; total=used+available;
    if (total>0)
        printf "%s: Used %s, Free %s, Usage %s\n", $6, $3, $4, $5
}'

# 4. Top 5 Processes by CPU Usage
echo
echo "---- TOP 5 PROCESSES BY CPU ----"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6

# 5. Top 5 Processes by Memory Usage
echo
echo "---- TOP 5 PROCESSES BY MEMORY ----"
ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -n 6

# 6. Extra Statistics
echo
echo "---- SYSTEM INFORMATION ----"
echo "OS: $(uname -s)"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "Load Average: $(awk '{print $1, $2, $3}' /proc/loadavg)"
echo "Logged-in Users: $(who | wc -l)"

echo
echo "===================================="
echo "       STATS COMPLETE"
echo "===================================="
