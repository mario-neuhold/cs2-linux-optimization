# CPU Performance Governor Specification

## Purpose
Set the CPU scaling governor to `performance` permanently for all cores, ensuring the
i5-10300H runs at full turbo speed at all times regardless of load or idle state.

## Requirements

### Requirement: Permanent Performance Governor via Systemd

The system MUST set the CPU governor to `performance` for all cores at boot via a systemd
service and MUST NOT revert to `powersave` on idle.

The preferred implementation MUST use `powerprofilesctl set performance` if
power-profiles-daemon is active, falling back to `cpupower frequency-set -g performance`
for all cores.

#### Scenario: All cores run performance governor after reboot

- GIVEN the systemd service is enabled
- WHEN the system boots
- THEN `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor` returns `performance` for every core
- AND the governor does NOT revert to `powersave` after 5 minutes of idle

#### Scenario: CPU reaches full turbo under load

- GIVEN the performance governor is active
- WHEN a CPU-intensive process runs (e.g., a game or compilation)
- THEN `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq` shows frequencies at or near 4500000 (4.5GHz)

#### Scenario: Rollback restores default governor

- GIVEN the systemd service is enabled
- WHEN the service is disabled (`systemctl disable --now <service>`) and the system reboots
- THEN `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` returns `powersave`
