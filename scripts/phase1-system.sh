#!/usr/bin/env bash
# =============================================================================
# CS2 Performance Optimization — Phase 1: System-level changes
# Tasks: 1.1 (GPU env vars) + 1.2-1.4 (CPU performance governor)
# Requires: sudo
# Reboot required after this script completes.
# =============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${BOLD}[cs2-opt]${NC} $*"; }
ok()   { echo -e "${GREEN}  ✓${NC} $*"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $*"; }
fail() { echo -e "${RED}  ✗${NC} $*"; exit 1; }

echo ""
echo -e "${BOLD}=== CS2 Performance Optimization — Phase 1 ===${NC}"
echo ""

# -----------------------------------------------------------------------------
# TASK 1.1 — GPU routing: append NVIDIA vars to /etc/environment
# Spec: gpu-primary-nvidia — Global NVIDIA Environment Variables
# -----------------------------------------------------------------------------
log "Task 1.1 — Setting NVIDIA GPU as primary (global)"

ENV_FILE="/etc/environment"
MARKER="# CS2 Performance Optimization — GPU routing"

if grep -q "$MARKER" "$ENV_FILE"; then
    warn "NVIDIA vars already present in $ENV_FILE — skipping"
else
    cat << 'EOF' | sudo tee -a "$ENV_FILE" > /dev/null

# CS2 Performance Optimization — GPU routing (GTX 1650 as primary)
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
__VK_LAYER_NV_optimus=NVIDIA_only
DRI_PRIME=1
EOF
    ok "NVIDIA vars appended to $ENV_FILE"
fi

# Install mesa-utils for GPU verification (glxinfo)
log "Task 1.1 — Installing mesa-utils (for glxinfo GPU verification)"
if command -v glxinfo &>/dev/null; then
    warn "mesa-utils already installed — skipping"
else
    sudo apt-get install -y mesa-utils &>/dev/null && ok "mesa-utils installed" || warn "Could not install mesa-utils — verify GPU routing manually"
fi

# -----------------------------------------------------------------------------
# TASK 1.2 — CPU governor: create systemd oneshot service
# Spec: cpu-performance-governor — Permanent Performance Governor via Systemd
# -----------------------------------------------------------------------------
log "Task 1.2 — Creating CPU performance governor systemd service"

SERVICE_FILE="/etc/systemd/system/cs2-performance-governor.service"

sudo tee "$SERVICE_FILE" > /dev/null << 'EOF'
[Unit]
Description=Set CPU governor to performance (CS2 optimization)
After=power-profiles-daemon.service
Requires=power-profiles-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/bin/powerprofilesctl set performance
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

ok "Service file created at $SERVICE_FILE"

# -----------------------------------------------------------------------------
# TASK 1.3 — Enable and start the CPU governor service
# -----------------------------------------------------------------------------
log "Task 1.3 — Enabling cs2-performance-governor.service"

sudo systemctl daemon-reload
sudo systemctl enable --now cs2-performance-governor.service

ok "cs2-performance-governor.service enabled and started"

# -----------------------------------------------------------------------------
# TASK 1.4 — Verify CPU governor is active now
# -----------------------------------------------------------------------------
log "Task 1.4 — Verifying CPU governor"

GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
PROFILE=$(powerprofilesctl 2>/dev/null | grep "^\*" | awk '{print $2}' || echo "unknown")

if [[ "$GOVERNOR" == "performance" ]]; then
    ok "CPU governor: performance ✓"
else
    warn "CPU governor: $GOVERNOR (may need reboot to take full effect)"
fi

if [[ "$PROFILE" == "performance" ]]; then
    ok "Power profile: performance ✓"
else
    warn "Power profile: $PROFILE"
fi

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}=== Phase 1 Complete ===${NC}"
echo ""
echo "Changes applied:"
echo "  • /etc/environment — 4 NVIDIA GPU routing vars added"
echo "  • /etc/systemd/system/cs2-performance-governor.service — created & enabled"
echo ""
echo -e "${YELLOW}ACTION REQUIRED: Reboot the system to activate GPU routing.${NC}"
echo "  sudo reboot"
echo ""
echo "After reboot, verify GPU routing with:"
echo "  glxinfo | grep 'OpenGL renderer'"
echo "  Expected: string containing 'NVIDIA GeForce GTX 1650'"
echo ""
echo "Rollback:"
echo "  GPU: Remove the 4 NVIDIA lines from /etc/environment, then reboot"
echo "  CPU: sudo systemctl disable --now cs2-performance-governor.service"
echo ""
