#!/usr/bin/env bash
# =============================================================================
# CS2 Performance Optimization — Rollback script
# Reverts ALL changes applied by phase1-system.sh and phase2-user.sh
# =============================================================================

set -uo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${BOLD}[rollback]${NC} $*"; }
ok()   { echo -e "${GREEN}  ✓${NC} $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $*"; }

echo ""
echo -e "${BOLD}=== CS2 Optimization Rollback ===${NC}"
echo ""

# --- GPU routing vars ---
log "Removing NVIDIA GPU vars from /etc/environment"
if grep -q "CS2 Performance Optimization" /etc/environment; then
    sudo sed -i '/# CS2 Performance Optimization/,/^DRI_PRIME=1$/d' /etc/environment
    ok "NVIDIA vars removed from /etc/environment"
else
    warn "NVIDIA vars not found in /etc/environment — already removed?"
fi

# --- CPU governor service ---
log "Disabling cs2-performance-governor.service"
if systemctl is-active --quiet cs2-performance-governor.service 2>/dev/null; then
    sudo systemctl disable --now cs2-performance-governor.service
    ok "cs2-performance-governor.service disabled"
else
    warn "Service was not active — skipping"
fi

SERVICE_FILE="/etc/systemd/system/cs2-performance-governor.service"
if [[ -f "$SERVICE_FILE" ]]; then
    sudo rm "$SERVICE_FILE"
    sudo systemctl daemon-reload
    ok "Service file removed"
fi

# --- Gamemode ---
log "Disabling gamemoded user service"
systemctl --user disable --now gamemoded 2>/dev/null && ok "gamemoded disabled" || warn "gamemoded was not active"

# --- gamemode.ini ---
log "Removing /etc/gamemode.ini"
if [[ -f /etc/gamemode.ini.bak ]]; then
    sudo mv /etc/gamemode.ini.bak /etc/gamemode.ini
    ok "gamemode.ini restored from backup"
elif [[ -f /etc/gamemode.ini ]]; then
    sudo rm /etc/gamemode.ini
    ok "/etc/gamemode.ini removed"
fi

# --- autoexec.cfg ---
AUTOEXEC="$HOME/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/cfg/autoexec.cfg"
log "Removing CS2 autoexec.cfg"
if [[ -f "${AUTOEXEC}.bak" ]]; then
    mv "${AUTOEXEC}.bak" "$AUTOEXEC"
    ok "autoexec.cfg restored from backup"
elif [[ -f "$AUTOEXEC" ]]; then
    rm "$AUTOEXEC"
    ok "autoexec.cfg removed"
else
    warn "autoexec.cfg not found — already removed?"
fi

echo ""
echo -e "${BOLD}=== Rollback Complete ===${NC}"
echo ""
echo -e "${YELLOW}ACTION REQUIRED:${NC}"
echo "  1. Clear CS2 launch options in Steam → CS2 → Properties → Launch Options"
echo "  2. Reboot to restore Intel UHD as primary GPU and powersave governor"
echo "     sudo reboot"
echo ""
