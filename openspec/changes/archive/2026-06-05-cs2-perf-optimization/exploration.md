# Exploration: cs2-perf-optimization

## Current State

### Hardware Profile
- **CPU**: Intel i5-10300H (4 cores / 8 threads), max 4.5GHz
- **Current CPU governor**: `powersave` (scaling at 86% of max)
- **Available governors**: `performance`, `powersave`
- **RAM**: 14GB total, 5.6GB used
- **GPU primary**: NVIDIA GTX 1650 Mobile / Max-Q — 4GB VRAM, driver 580.159.03
- **GPU secondary**: Intel UHD (integrated) — rendering desktop (87MB VRAM used)
- **Optimus mode**: `on-demand` (managed by `prime-select`)
- **Session**: Wayland (XDG_SESSION_TYPE=wayland)
- **Kernel**: 7.0.0-22-generic
- **AC status**: Always plugged in when gaming

### Software Profile
- **Steam**: installed at `~/.local/share/Steam`
- **CS2 app ID**: 730
- **CS2 install path**: `~/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/`
- **CS2 launcher**: `cs2.sh` (explicitly sets `SDL_VIDEO_DRIVER=x11`)
- **CS2 launch options**: NONE currently set
- **CS2 cfg directory**: `game/cfg/` exists, `autoexec.cfg` does not exist
- **gamemode**: PACKAGES installed (`gamemode`, `gamemode-daemon`, `libgamemode0`, `libgamemodeauto0` all at 1.8.2-2build1) — BUT `gamemoded` systemd service is `inactive` and `not-found`
- **cpupower**: installed (`/usr/bin/cpupower`)
- **cpufreq-set**: NOT installed
- **nvidia-settings**: installed (`/usr/bin/nvidia-settings`)
- **switcherooctl**: installed (`/usr/bin/switcherooctl`)
- **prime-select**: installed (`/usr/bin/prime-select`)
- **power-profiles-daemon**: active and running (`performance`, `balanced`, `power-saver` available)
- **Default systemd target**: `graphical.target`
- **prime-run**: NOT available
- **vgaswitcheroo**: NOT accessible
- **gamemode config**: `/usr/share/gamemode/gamemode.ini` exists with defaults (`desiredgov=performance`, `renice=0`, `ioprio=0`)
- **steamtinkerlaunch**: NOT configured

### GPU Routing Analysis
- `switcherooctl list` shows:
  - Device 0: Intel UHD — `Default: yes`, `Discrete: no`
  - Device 1: NVIDIA GTX 1650 — `Default: no`, `Discrete: yes`
- Required environment variables for NVIDIA offload: `__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only VK_LOADER_DRIVERS_SELECT=*nvidia*`
- `glxinfo` is NOT available, so OpenGL renderer verification is not possible without installing `mesa-utils`
- `cs2.sh` does NOT set any GPU-related environment variables; it relies on the runtime environment

### CPU Governor Analysis
- Current governor is `powersave`, throttling the CPU to ~86% of max frequency
- `power-profiles-daemon` is running and offers `performance` profile
- `cpupower` is available but no cpufrequtils
- No existing `tlp`, `auto-cpufreq`, or other CPU tuning services installed
- The `gamemode.ini` default already targets `desiredgov=performance` when gamemode is active

### Wayland / XWayland Analysis
- `cs2.sh` explicitly enforces `SDL_VIDEO_DRIVER=x11` if unset
- This means CS2 will run on XWayland under the current Wayland session
- Valve's comment in `cs2.sh`: "a recent attempt at allowing SDL to default to Wayland caused a number of customer issues so keep the default at X11 for now"
- **No additional forcing needed** — CS2 already handles this

### Gamemode Analysis
- The gamemode packages are installed, but the systemd service is missing
- The `gamemoded` binary exists at `/usr/bin/gamemoded`
- The `gamemoderun` wrapper exists at `/usr/games/gamemoderun`
- The default configuration targets `performance` governor and `SCHED_ISO` (off), renice=0
- For GPU tuning, `nv_powermizer_mode=1` (Prefer Maximum Performance) is possible but requires `coolbits` in `nvidia-xconfig` and explicit `accept-responsibility` in config

## Affected Areas
- **GPU routing**: `~/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/cs2.sh` (indirectly, via Steam launch options)
- **Steam launch options**: stored in `~/.local/share/Steam/userdata/*/config/localconfig.vdf`
- **CPU governor**: system-level, via `cpupower` or `power-profiles-daemon` or gamemode
- **CS2 autoexec**: `~/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/cfg/autoexec.cfg`
- **Gamemode config**: `/etc/gamemode.ini` (if created) or `~/.config/gamemode.ini`
- **Systemd service**: custom service for CPU governor persistence if gamemode is not used

## Approaches

### 1. Steam Launch Options + Gamemode (Recommended)
Use Steam's built-in launch options to force NVIDIA GPU and wrap with gamemode.

- **Steam launch options**: `__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only VK_LOADER_DRIVERS_SELECT=*nvidia* gamemoderun %command% -novid -high +fps_max 0`
- **Gamemode config**: Update `/etc/gamemode.ini` or `~/.config/gamemode.ini` to:
  - `desiredgov=performance` (already default)
  - `renice=10` (or `5` for mild priority boost)
  - `ioprio=0` (already default)
  - Optionally enable `nv_powermizer_mode=1` if `coolbits` is configured
- **Enable gamemoded service**: Create a systemd user service or enable the system service if it exists

| Pros | Cons | Effort |
|------|------|--------|
| Isolated to CS2, no global system changes | Requires gamemode daemon to be active | Low |
| Gamemode automatically reverts CPU governor after game | If gamemode service is broken, CPU tuning fails | Low |
| NVIDIA offload only applies to CS2 | May need to install `mesa-utils` for verification | Low |
| Uses existing tools (switcherooctl, gamemode) | | Low |

### 2. System-Level Persistent Tuning
Make global, persistent changes that apply to the entire system.

- **GPU**: Set `__NV_PRIME_RENDER_OFFLOAD=1` globally in `/etc/environment` or `~/.config/environment.d/` (NOT recommended for desktop use)
- **CPU**: Create a systemd service or udev rule that sets `cpupower frequency-set -g performance` on AC adapter plug-in
- **Alternative**: Use `power-profiles-daemon` `performance` profile persistently (but this affects battery when unplugged)

| Pros | Cons | Effort |
|------|------|--------|
| Fully persistent across reboots | Affects all applications, not just CS2 | Medium |
| No per-game configuration | May reduce battery life if accidentally unplugged | Medium |
| | `power-profiles-daemon` performance profile may not be as aggressive as `cpupower` | Medium |
| | More complex to implement and maintain | Medium |

### 3. Hybrid Approach (Best of Both)
Combine game-specific GPU routing with system-level CPU governor management, using gamemode as the bridge.

- **GPU**: Steam launch options with NVIDIA offload env vars (same as Approach 1)
- **CPU**: Gamemode handles governor switching; if gamemode fails, fallback to `power-profiles-daemon` set to `performance` before gaming
- **NVIDIA tuning**: Use `nvidia-settings` to set "Prefer Maximum Performance" for the CS2 profile (or globally)
- **CS2 autoexec.cfg**: Add `fps_max 0`, `rate 786432`, `engine_low_latency_sleep_after_client_tick true` (if supported), `snd_mixahead 0.05`

| Pros | Cons | Effort |
|------|------|--------|
| GPU isolated to CS2, CPU managed by gamemode | Most complex to implement | Medium |
| If gamemode fails, power-profiles-daemon is fallback | Requires verifying multiple moving parts | Medium |
| Can add NVIDIA-specific tuning via gamemode.ini | `coolbits` needed for NVIDIA overclocking/PM mode | Medium |
| Best performance potential | | Medium |

## Quick Wins

### Steam Launch Options (immediate, no persistence needed)
```
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only VK_LOADER_DRIVERS_SELECT=*nvidia* gamemoderun %command% -novid -high +fps_max 0
```
- `__NV_PRIME_RENDER_OFFLOAD=1`: Forces NVIDIA GPU for Vulkan (CS2 uses Vulkan on Linux)
- `__VK_LAYER_NV_optimus=NVIDIA_only`: Ensures NVIDIA is selected for Optimus
- `VK_LOADER_DRIVERS_SELECT=*nvidia*`: Filters Vulkan loader to NVIDIA only
- `gamemoderun %command%`: Wraps CS2 with gamemode for CPU tuning
- `-novid`: Skips intro video
- `-high`: Sets high process priority (Source 2)
- `+fps_max 0`: Uncaps FPS (default is 400 or lower)

### CS2 autoexec.cfg
Create `~/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/cfg/autoexec.cfg`:
```
fps_max 0
rate 786432
cl_cmdrate 128
cl_updaterate 128
engine_low_latency_sleep_after_client_tick true
snd_mixahead 0.05
```
Note: Some commands may not apply in CS2 (Source 2) vs CS:GO (Source 1). Verify in-game.

### NVIDIA PowerMizer
Use `nvidia-settings` to set "Prefer Maximum Performance" globally or create an application profile for CS2.

### CPU Governor (if gamemode not active)
```bash
sudo cpupower frequency-set -g performance
```
Or use `powerprofilesctl set performance`.

## Recommendation

**Adopt Approach 3 (Hybrid)**, but implement it in phases:

1. **Phase 1 (Immediate)**: Set Steam launch options with NVIDIA offload + gamemoderun. This alone should fix the GPU routing and provide CPU governor switching via gamemode.
2. **Phase 2 (Validation)**: Verify gamemode is actually switching the governor. If `gamemoded` service remains broken, fix the service or use a systemd user unit.
3. **Phase 3 (Tuning)**: Add autoexec.cfg and NVIDIA PowerMizer tuning. Create `gamemode.ini` with `nv_powermizer_mode=1` if `coolbits` is enabled.

This approach is the most robust because:
- GPU offload is isolated to CS2 (no desktop breakage)
- CPU governor is managed dynamically (gamemode reverts on exit)
- It provides fallback options if any component fails
- It aligns with the user's constraint (always plugged in)

## Risks

- **Gamemode service broken**: `gamemoded` is `inactive` and `not-found` as a systemd unit. The service may need to be manually started or the package may be missing a systemd unit file. This could prevent CPU governor switching.
- **NVIDIA offload not working**: `glxinfo` is not installed, so we cannot easily verify which GPU is being used. If the env vars are wrong, CS2 may still run on Intel UHD.
- **Wayland issues**: While CS2 forces X11, XWayland performance on NVIDIA with the 580 driver series may have issues. If frame drops persist, consider switching to an X11 session.
- **PowerMizer requires `coolbits`**: Enabling NVIDIA "Prefer Maximum Performance" via gamemode requires `nvidia-xconfig` with `coolbits` enabled, which may be considered risky for laptop GPUs.
- **CS2 console commands changed**: Source 2 may have different console commands than CS:GO. Some autoexec.cfg commands may be ignored or cause warnings.
- **Battery not optimized**: Since the user is always plugged in, we can ignore battery optimizations. However, if the laptop is unplugged accidentally, `performance` governor will drain battery quickly.

## Ready for Proposal

**Yes**, with the following prerequisites for the orchestrator to communicate to the user:

1. Confirm whether gamemode daemon is expected to be active (it is installed but the service is not running). We may need to start it manually or investigate why the systemd unit is missing.
2. Decide whether to install `mesa-utils` (for `glxinfo`) to verify GPU routing.
3. Decide on the level of NVIDIA tuning (just offload, or also PowerMizer).
4. Confirm the user is comfortable with a custom systemd service for CPU governor if gamemode fails.

---
*Exploration generated by sdd-explore executor*
*Date: 2026-06-05*
