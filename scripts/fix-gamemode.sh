#!/usr/bin/env bash
# Fix: gamemoded -t failing due to polkit authorization errors
# Root cause: gamemoded tries to change CPU governor via pkexec/cpugovctl
# but user lacks polkit auth. Fix: disable governor management in gamemode.ini
# (already handled by cs2-performance-governor.service) + add user to gamemode group.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓${NC} $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $*"; }

echo -e "${BOLD}[fix] Updating /etc/gamemode.ini (disable CPU governor management)${NC}"

sudo tee /etc/gamemode.ini > /dev/null << 'EOF'
; CS2 Performance Optimization — gamemode configuration
; CPU governor: DISABLED — handled by cs2-performance-governor.service
; split_lock_mitigate: DISABLED — requires polkit auth not available
; renice=10 → nice=-10 for game process (gamemode convention)

[general]
renice=10
ioprio=0
inhibit_screensaver=1

; Disable CPU governor switching (already handled by systemd service)
desiredgov=
defaultgov=

; Disable iGPU governor switching
igpu_desiredgov=
igpu_power_threshold=-1

[filter]
whitelist=cs2
EOF

ok "/etc/gamemode.ini updated"

echo -e "${BOLD}[fix] Adding $USER to gamemode group${NC}"

if groups "$USER" | grep -q gamemode; then
    warn "User $USER already in gamemode group"
else
    sudo usermod -aG gamemode "$USER"
    ok "User $USER added to gamemode group"
    warn "NOTE: Group change takes effect on next login (re-login or reboot)"
fi

echo -e "${BOLD}[fix] Restarting gamemoded${NC}"
systemctl --user restart gamemoded
sleep 1
ok "gamemoded restarted"

echo ""
echo "Running gamemoded -t..."
echo ""
gamemoded -t 2>&1
echo ""

STATUS=$(systemctl --user is-active gamemoded)
echo "gamemoded status: $STATUS"
