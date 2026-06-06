# Proposal: CS2 Performance Optimization

## Intent

CS2 runs at ~30 FPS with drops on this laptop (i5-10300H, GTX 1650 Mobile, 14GB RAM). Root causes: Intel UHD used as default GPU instead of GTX 1650, CPU governor stuck at `powersave`, gamemoded service inactive, no CS2-specific tuning. Target: stable 60+ FPS.

## Scope

### In Scope
- Force GTX 1650 as global primary GPU via system-wide environment variables
- Set CPU governor to `performance` permanently via systemd + power-profiles-daemon
- Activate and configure gamemoded with optimized gamemode.ini
- Apply CS2 Steam launch options: NVIDIA offload + gamemoderun + performance flags
- Deploy CS2 autoexec.cfg with FPS and network tuning
- All changes survive reboots

### Out of Scope
- NVIDIA PowerMizer tuning (requires coolbits — follow-up change)
- Kernel parameter tuning
- Compositor/vsync configuration
- CS2 video settings (in-game menu)

## Capabilities

> Contract with sdd-spec. Each New Capability → `openspec/specs/<name>/spec.md`.

### New Capabilities
- `gpu-primary-nvidia`: Force GTX 1650 as global primary GPU via `/etc/environment` + prime config
- `cpu-performance-governor`: Permanent `performance` CPU governor via systemd oneshot + power-profiles-daemon
- `gamemode-config`: Active gamemoded service with tuned `/etc/gamemode.ini`
- `cs2-launch-options`: Optimized Steam launch options combining NVIDIA offload, gamemoderun, and engine flags
- `cs2-autoexec`: CS2 autoexec.cfg with FPS caps, network rates, and debug overlay

### Modified Capabilities
None — greenfield project.

## Approach

**GPU**: Set `__NV_PRIME_RENDER_OFFLOAD=1`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__VK_LAYER_NV_optimus=NVIDIA_only`, `DRI_PRIME=1` in `/etc/environment`. Install `mesa-utils` for verification.

**CPU**: Create a systemd oneshot service that runs `powerprofilesctl set performance` at boot. Ensures global, permanent `performance` profile without touching cpupower directly.

**Gamemode**: Enable `gamemoded.service`, write `/etc/gamemode.ini` with renice, ionice, and custom scripts. CS2 launch uses `gamemoderun`.

**CS2 launch**: `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia gamemoderun %command% -novid -high -threads 4 +fps_max 0`

**Autoexec**: Deploy to `~/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/cfg/autoexec.cfg` with `+exec autoexec.cfg` in launch options.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `/etc/environment` | Modified | GPU offload env vars |
| `/etc/systemd/system/` | New | CPU performance service unit |
| `/etc/gamemode.ini` | Modified | Gamemode tuning |
| Steam launch options | Modified | CS2-specific flags |
| `.../cfg/autoexec.cfg` | New | CS2 FPS/network config |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| gamemoded service broken on install | Med | Verify with `gamemoded -t`; fallback: launch options only |
| NVIDIA offload env vars break non-CS2 apps | Low | `/etc/environment` applies broadly; test Firefox/Chrome rendering |
| Source 2 console commands differ from CS:GO | Low | Verify each command in CS2 console; remove non-functional ones |

## Rollback Plan

- **GPU**: Remove env vars from `/etc/environment`, reboot
- **CPU**: `systemctl disable cpu-performance.service`, reboot
- **Gamemode**: `systemctl disable --now gamemoded`
- **CS2 launch**: Clear in Steam UI
- **Autoexec**: Delete the file, remove `+exec` from launch options

## Dependencies

- `mesa-utils` (not installed — provides glxinfo for GPU verification)
- `gamemode` (installed 1.8.2, gamemoded service needs enabling)
- `power-profiles-daemon` (installed and active)

## Success Criteria

- [ ] `glxinfo | grep "OpenGL renderer"` shows NVIDIA GTX 1650
- [ ] `powerprofilesctl get` returns `performance`
- [ ] `systemctl is-active gamemoded` returns `active`
- [ ] CS2 launches with NVIDIA GPU and shows `cl_showfps` overlay ≥ 60 FPS stable
