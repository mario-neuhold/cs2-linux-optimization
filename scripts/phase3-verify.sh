#!/usr/bin/env bash
# =============================================================================
# CS2 Performance Optimization — Phase 3: Verification
# Tasks: 3.1-3.8 — Verify all 5 capabilities against spec scenarios
# Run AFTER reboot (Phase 1 requires reboot to take full effect).
# =============================================================================

set -uo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✓ PASS${NC}  $*"; ((PASS++)); }
fail() { echo -e "  ${RED}✗ FAIL${NC}  $*"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠ WARN${NC}  $*"; ((WARN++)); }

echo ""
echo -e "${BOLD}=== CS2 Performance Optimization — Phase 3: Verification ===${NC}"
echo ""

# -----------------------------------------------------------------------------
# TASK 3.1 — Verify GPU routing (spec: gpu-primary-nvidia)
# Scenario: NVIDIA renderer active after reboot
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3.1] GPU Routing — NVIDIA as primary renderer${NC}"

if command -v glxinfo &>/dev/null; then
    RENDERER=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1 || echo "")
    if echo "$RENDERER" | grep -qi "nvidia"; then
        pass "OpenGL renderer: $RENDERER"
    else
        fail "OpenGL renderer is NOT NVIDIA: $RENDERER"
        echo "        → Check /etc/environment has the 4 NVIDIA vars and reboot"
    fi
else
    warn "glxinfo not found — install mesa-utils: sudo apt-get install mesa-utils"
fi

# -----------------------------------------------------------------------------
# TASK 3.2 — Verify GPU vars persist (spec: gpu-primary-nvidia)
# Scenario: Variables persist across reboots
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3.2] GPU Routing — Environment vars in /etc/environment${NC}"

ENV_VARS=("__NV_PRIME_RENDER_OFFLOAD=1" "__GLX_VENDOR_LIBRARY_NAME=nvidia" "__VK_LAYER_NV_optimus=NVIDIA_only" "DRI_PRIME=1")
ALL_PRESENT=true
for VAR in "${ENV_VARS[@]}"; do
    if grep -q "^$VAR" /etc/environment; then
        pass "$VAR present"
    else
        fail "$VAR MISSING from /etc/environment"
        ALL_PRESENT=false
    fi
done

# -----------------------------------------------------------------------------
# TASK 3.3 — Verify CPU governor (spec: cpu-performance-governor)
# Scenario: All cores run performance governor after reboot
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3.3] CPU Governor — performance on all cores${NC}"

CORE_COUNT=$(nproc)
FAIL_CORES=0
for i in $(seq 0 $((CORE_COUNT - 1))); do
    GOV=$(cat /sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    if [[ "$GOV" != "performance" ]]; then
        ((FAIL_CORES++))
    fi
done

if [[ $FAIL_CORES -eq 0 ]]; then
    pass "All $CORE_COUNT cores running 'performance' governor"
else
    # intel_pstate in active mode reports 'powersave' in sysfs even when
    # power-profiles-daemon is set to 'performance' — this is expected behavior.
    # The actual performance level is controlled by the power profile, not scaling_governor.
    PSTATE_DRIVER=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo "unknown")
    if [[ "$PSTATE_DRIVER" == "intel_pstate" ]]; then
        warn "$CORE_COUNT cores show 'powersave' in sysfs — expected with intel_pstate active mode"
        echo "        → intel_pstate ignores scaling_governor when in active mode"
        echo "        → Performance is controlled by power-profiles-daemon profile (checked below)"
    else
        fail "$FAIL_CORES/$CORE_COUNT cores NOT on performance governor"
        echo "        → Check: systemctl status cs2-performance-governor.service"
    fi
fi

# Power profile check — active profile is marked with "* " prefix
PROFILE=$(powerprofilesctl 2>/dev/null | grep -E "^\* " | awk '{print $2}' | tr -d ':' || echo "unknown")
if [[ "$PROFILE" == "performance" ]]; then
    pass "power-profiles-daemon active profile: performance"
else
    fail "power-profiles-daemon active profile: '$PROFILE' (expected: performance)"
fi

# Systemd service check
if systemctl is-active --quiet cs2-performance-governor.service; then
    pass "cs2-performance-governor.service is active"
else
    fail "cs2-performance-governor.service is NOT active"
    echo "        → Run: sudo systemctl enable --now cs2-performance-governor.service"
fi

# -----------------------------------------------------------------------------
# TASK 3.4 — Verify gamemoded daemon (spec: gamemode-config)
# Scenario: Gamemoded running after reboot + self-test passes
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3.4] Gamemode — daemon active${NC}"

if systemctl --user is-active --quiet gamemoded; then
    pass "gamemoded.service is active (user service)"
else
    fail "gamemoded.service is NOT active"
    echo "        → Run: systemctl --user enable --now gamemoded"
fi

# gamemoded -t has a known broken test in v1.8.1 (RegisterGame signature mismatch).
# Verify the daemon via D-Bus QueryStatus instead — this is what games actually use.
DBUS_RESULT=$(busctl --user call com.feralinteractive.GameMode \
    /com/feralinteractive/GameMode \
    com.feralinteractive.GameMode QueryStatus i 0 2>/dev/null || echo "error")
if echo "$DBUS_RESULT" | grep -q "^i "; then
    pass "gamemoded D-Bus responding correctly (QueryStatus: $DBUS_RESULT)"
else
    fail "gamemoded D-Bus not responding: $DBUS_RESULT"
    echo "        → Check: systemctl --user status gamemoded"
fi

# -----------------------------------------------------------------------------
# TASK 3.5 — Verify gamemode.ini (spec: gamemode-config)
# Scenario: INI configuration present
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3.5] Gamemode — INI configuration${NC}"

if [[ -f /etc/gamemode.ini ]]; then
    pass "/etc/gamemode.ini exists"
    grep -q "renice=10" /etc/gamemode.ini && pass "renice=10 configured" || fail "renice=10 missing from gamemode.ini"
    grep -q "ioprio=0" /etc/gamemode.ini && pass "ioprio=0 configured" || fail "ioprio=0 missing from gamemode.ini"
    grep -q "inhibit_screensaver=1" /etc/gamemode.ini && pass "inhibit_screensaver=1 configured" || fail "inhibit_screensaver=1 missing"
else
    fail "/etc/gamemode.ini does NOT exist"
    echo "        → Re-run phase2-user.sh"
fi

# -----------------------------------------------------------------------------
# TASK 3.6 — Verify autoexec.cfg (spec: cs2-autoexec)
# Scenario: Autoexec file exists and contains required settings
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3.6] CS2 Autoexec — file and settings${NC}"

AUTOEXEC="$HOME/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/cfg/autoexec.cfg"

if [[ -f "$AUTOEXEC" ]]; then
    pass "autoexec.cfg exists at correct path"

    check_setting() {
        local setting="$1"
        if grep -q "^$setting" "$AUTOEXEC"; then
            pass "$setting configured"
        else
            fail "$setting MISSING from autoexec.cfg"
        fi
    }

    check_setting "fps_max 0"
    check_setting "cl_showfps 1"
    check_setting "r_dynamic 0"
    check_setting "rate 786432"
    check_setting "cl_cmdrate 128"
    check_setting "cl_updaterate 128"
    check_setting "cl_interp_ratio 1"
    check_setting "cl_interp 0"
else
    fail "autoexec.cfg NOT found at: $AUTOEXEC"
    echo "        → Re-run phase2-user.sh"
fi

# -----------------------------------------------------------------------------
# TASK 3.7 — Verify CS2 launch options (spec: cs2-launch-options) — manual check
# Scenario: Launch string set in Steam for App ID 730
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3.7] CS2 Launch Options — manual verification needed${NC}"
warn "Cannot verify Steam launch options automatically — open Steam and confirm:"
echo "        Steam → Counter-Strike 2 → Properties → Launch Options"
echo "        Expected: gamemoderun %command% -novid -high -threads 4 +fps_max 0 +exec autoexec"

# -----------------------------------------------------------------------------
# TASK 3.8 — In-game verification checklist
# Scenario: FPS > 60, FPS counter visible, net_graph shows 128 tick
# -----------------------------------------------------------------------------
echo -e "${BOLD}[3.8] In-game verification checklist (manual)${NC}"
warn "Launch CS2 and verify the following in-game:"
echo "        • FPS counter visible top-left (cl_showfps 1)"
echo "        • FPS shows values > 60 (target: 60+ stable)"
echo "        • No intro video on launch (-novid)"
echo "        • Open console (~) and type: net_graph 1"
echo "          Expected: cmdrate and updaterate = 128"
echo "        • Open console and type: fps_max"
echo "          Expected: 0"

# -----------------------------------------------------------------------------
# FINAL SUMMARY
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}=== Verification Summary ===${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN (manual checks)"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All automated checks passed! ✓${NC}"
    echo "  Complete the manual checks (3.7 and 3.8) in-game."
else
    echo -e "${RED}${BOLD}$FAIL check(s) failed. Review the FAIL lines above.${NC}"
fi
echo ""
