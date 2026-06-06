# cs2-linux-optimization

Performance optimization for Counter-Strike 2 on Linux (Ubuntu, GNOME, Wayland).

Tested on: **ASUS TUF Gaming F15** — Intel i5-10300H + NVIDIA GTX 1650 Mobile (Optimus)

## Results

| Metric | Before | After |
|--------|--------|-------|
| FPS | ~30 with drops | **~110 stable** |
| GPU active | Intel UHD (integrated) | GTX 1650 ✓ |
| CPU governor | `powersave` | `performance` ✓ |
| Resolution | 5120×1440 (native) | 1920×1080 (optimal) |

## What this does

| Component | Change |
|-----------|--------|
| `/etc/environment` | Routes all rendering to NVIDIA GPU via Optimus offload vars |
| `cs2-performance-governor.service` | Sets CPU to `performance` profile at boot (permanent) |
| `/etc/gamemode.ini` | Configures gamemoded: process priority, I/O tuning, no screensaver |
| `autoexec.cfg` | Uncaps FPS, optimizes render settings, tunes network for 128-tick |
| Steam launch options | Enables gamemode, skips intro, forces fullscreen at 1080p |

## Requirements

- NVIDIA GPU with Optimus (dual-GPU laptop)
- `power-profiles-daemon` (pre-installed on Ubuntu 22.04+)
- `gamemode` package (`sudo apt install gamemode`)
- `mesa-utils` (`sudo apt install mesa-utils`)
- Steam + CS2 installed

## Usage

### First time setup

**Phase 1 — System changes** (requires sudo + reboot):
```bash
bash scripts/phase1-system.sh
sudo reboot
```

**Phase 2 — User changes** (no reboot needed):
```bash
bash scripts/phase2-user.sh
```

**Phase 3 — Set Steam launch options manually:**

Steam → Counter-Strike 2 → Properties → Launch Options:
```
gamemoderun %command% -novid -high -threads 4 +fps_max 0 +exec autoexec -nojoy -w 1920 -h 1080 -fullscreen
```

**Phase 4 — Verify everything works:**
```bash
bash scripts/phase3-verify.sh
```

### Rollback (undo everything)

```bash
bash scripts/rollback.sh
sudo reboot
```

## CS2 autoexec.cfg settings

| Setting | Value | Effect |
|---------|-------|--------|
| `fps_max` | `0` | Uncapped FPS |
| `cl_showfps` | `1` | FPS counter (disable after tuning) |
| `r_dynamic` | `0` | Disable dynamic lighting |
| `mat_queue_mode` | `2` | Async render queue |
| `r_drawtracers_firstperson` | `0` | No bullet tracers (perf) |
| `rate` | `786432` | Max network rate |
| `cl_cmdrate` | `128` | 128-tick commands |
| `cl_updaterate` | `128` | 128-tick updates |
| `cl_interp_ratio` | `1` | Minimal interpolation |
| `cl_interp` | `0` | Minimal interpolation |

## Known issues

### `gamemoded -t` reports failure
This is a **known upstream bug in gamemode v1.8.1** — the test binary uses the wrong D-Bus signature for `RegisterGame`. The daemon itself works correctly. Verify with:
```bash
busctl --user call com.feralinteractive.GameMode \
  /com/feralinteractive/GameMode \
  com.feralinteractive.GameMode QueryStatus i 0
# Expected: i 0 (daemon responding)
```

### CPU governor shows `powersave` in sysfs
`intel_pstate` in active mode always shows `powersave` in `/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor` regardless of the active power profile. This is **expected behavior**. Verify the actual profile:
```bash
powerprofilesctl  # look for "* performance"
```

### `__VK_LAYER_NV_optimus=NVIDIA_only` breaks CS2
This variable blocks Vulkan ICD selection when multiple ICDs are installed. **Do not add it** to `/etc/environment`. Only these two vars are needed for NVIDIA Optimus:
```
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
```

## Next steps (optional)

- **NVIDIA PowerMizer**: force GPU to max clock permanently via `coolbits` xorg option — additional 5–15% GPU performance
- Disable `cl_showfps 1` in autoexec after verifying FPS

## SDD artifacts

Full planning artifacts (exploration, proposal, specs, design, tasks, verify report) are in `openspec/`.
