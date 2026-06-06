# Tasks: CS2 Performance Optimization

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~80-120 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single apply (system config, no PRs) |
| Delivery strategy | ask-always |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | System-level config (GPU + CPU) | N/A — direct apply | Requires sudo + reboot; batch both to avoid double reboot |
| 2 | User-level config (gamemode + autoexec) | N/A — direct apply | No sudo needed; no reboot |
| 3 | Verification pass | N/A — manual run | Post-reboot validation of all 5 capabilities |

## Phase 1: System-Level Changes (sudo + reboot required)

- [x] 1.1 Install `mesa-utils` package: `sudo apt install -y mesa-utils` — included in phase1-system.sh
- [x] 1.2 Append 4 NVIDIA GPU routing vars to `/etc/environment` — included in phase1-system.sh
- [x] 1.3 Create `/etc/systemd/system/cs2-performance-governor.service` with oneshot + `powerprofilesctl set performance` — included in phase1-system.sh
- [x] 1.4 Enable and start CPU governor service: `sudo systemctl enable --now cs2-performance-governor.service` — included in phase1-system.sh
- [x] 1.5 Reboot to apply `/etc/environment` GPU vars and confirm CPU governor service starts on boot

## Phase 2: User-Level Changes (no reboot)

- [x] 2.1 Create `/etc/gamemode.ini` with renice=10, ioprio=0, inhibit_screensaver=1, whitelist=cs2 — included in phase2-user.sh
- [x] 2.2 Enable gamemoded user service: `systemctl --user enable --now gamemoded` — included in phase2-user.sh
- [x] 2.3 Enable linger for gamemoded: `loginctl enable-linger $USER` — included in phase2-user.sh
- [x] 2.4 Create directory `~/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/cfg/` if missing — included in phase2-user.sh
- [x] 2.5 Create `autoexec.cfg` at the above path with fps_max 0, cl_showfps 1, r_dynamic 0, rate 786432, cl_cmdrate 128, cl_updaterate 128, cl_interp_ratio 1, cl_interp 0 — included in phase2-user.sh
- [x] 2.6 Set CS2 Steam launch options: `gamemoderun %command% -novid -high -threads 4 +fps_max 0 +exec autoexec` — MANUAL STEP (Steam UI)

## Phase 3: Verification

- [x] 3.1 Verify `gpu-primary-nvidia`: `glxinfo | grep "OpenGL renderer"` → contains "NVIDIA GeForce GTX 1650"
- [x] 3.2 Verify `cpu-performance-governor`: `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` → `performance`
- [x] 3.3 Verify `cpu-performance-governor`: `powerprofilesctl get` → `performance`
- [x] 3.4 Verify `gamemode-config`: `systemctl --user is-active gamemoded` → `active`
- [x] 3.5 Verify `gamemode-config`: `gamemoded -t` → exit code 0
- [x] 3.6 Verify `cs2-launch-options`: Launch CS2 from Steam → nointro video plays, FPS counter visible
- [x] 3.7 Verify `cs2-autoexec`: In CS2 console, `fps_max` → `0`
- [x] 3.8 Verify `cs2-autoexec`: In CS2 console, `net_graph 1` → cmdrate/updaterate = 128