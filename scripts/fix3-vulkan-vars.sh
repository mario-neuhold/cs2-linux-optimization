#!/usr/bin/env bash
# Fix 3: Remove __VK_LAYER_NV_optimus and DRI_PRIME from /etc/environment
#
# Root cause: __VK_LAYER_NV_optimus=NVIDIA_only blocks Vulkan ICD selection
# when multiple ICDs are present (intel, nouveau, nvidia, etc.).
# CS2 uses Vulkan — this causes 7fps + black textures.
#
# __NV_PRIME_RENDER_OFFLOAD=1 + __GLX_VENDOR_LIBRARY_NAME=nvidia are sufficient
# to route all rendering to the GTX 1650 on Optimus.

set -euo pipefail
BOLD='\033[1m'; GREEN='\033[0;32m'; NC='\033[0m'
ok() { echo -e "${GREEN}  ✓${NC} $*"; }

echo -e "${BOLD}[fix] Removing __VK_LAYER_NV_optimus and DRI_PRIME from /etc/environment${NC}"

# Backup first
sudo cp /etc/environment /etc/environment.bak-fix3
ok "Backup saved to /etc/environment.bak-fix3"

# Rewrite keeping only the two safe vars
sudo tee /etc/environment > /dev/null << 'EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"

# CS2 Performance Optimization — GPU routing (GTX 1650 as primary)
# __NV_PRIME_RENDER_OFFLOAD + __GLX_VENDOR_LIBRARY_NAME are sufficient for Optimus.
# __VK_LAYER_NV_optimus=NVIDIA_only removed — breaks Vulkan ICD selection with multiple ICDs.
# DRI_PRIME=1 removed — redundant with PRIME render offload vars.
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
EOF

ok "/etc/environment updated — 2 vars kept, 2 problematic vars removed"

echo ""
echo "Current /etc/environment:"
cat /etc/environment
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Re-login or reboot for /etc/environment changes to take effect"
echo "     (or: source /etc/environment in current shell for testing)"
echo "  2. Launch CS2 and verify FPS is normal"
echo ""
echo "Expected GPU routing still active via:"
echo "  __NV_PRIME_RENDER_OFFLOAD=1   → tells NVIDIA driver to handle rendering"
echo "  __GLX_VENDOR_LIBRARY_NAME=nvidia → forces GLX to use NVIDIA vendor library"
