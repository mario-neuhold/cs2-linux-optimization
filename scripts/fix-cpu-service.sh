#!/usr/bin/env bash
# Fix: cs2-performance-governor.service ordering cycle
# Root cause: WantedBy=multi-user.target + Requires=power-profiles-daemon.service
# creates a circular dependency. Fix: use graphical.target + soft After (no Requires).

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
NC='\033[0m'

ok() { echo -e "${GREEN}  ✓${NC} $*"; }

echo -e "${BOLD}[fix] Updating cs2-performance-governor.service${NC}"

sudo tee /etc/systemd/system/cs2-performance-governor.service > /dev/null << 'EOF'
[Unit]
Description=Set CPU governor to performance (CS2 optimization)
After=power-profiles-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/bin/powerprofilesctl set performance
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF

ok "Unit file updated (WantedBy=graphical.target, no Requires)"

sudo systemctl daemon-reload
ok "systemd daemon reloaded"

sudo systemctl enable --now cs2-performance-governor.service
ok "Service enabled and started"

echo ""
echo "Current status:"
systemctl is-active cs2-performance-governor.service && echo "  Service: active ✓" || echo "  Service: FAILED"
powerprofilesctl | grep -E "^\*|^  " | head -3
echo ""
echo "CPU governor on core 0:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo ""
echo "All cores:"
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort -u
