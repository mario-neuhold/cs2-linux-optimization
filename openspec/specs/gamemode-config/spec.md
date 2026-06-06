# Gamemode Configuration Specification

## Purpose
Enable the gamemoded daemon and configure it for per-game process and I/O priority tuning.
CPU governor management is explicitly OUT OF SCOPE (handled by cpu-performance-governor).

## Requirements

### Requirement: Gamemoded Daemon Active at Boot

The system MUST enable and start `gamemoded.service` so it is running on every boot.

#### Scenario: Gamemoded running after reboot

- GIVEN `gamemoded.service` is enabled via `systemctl enable gamemoded`
- WHEN the system boots
- THEN `systemctl is-active gamemoded` returns `active`

#### Scenario: Gamemode self-test passes

- GIVEN `gamemoded.service` is active
- WHEN `gamemoded -t` is executed
- THEN the command exits with code 0 and reports no failures

### Requirement: Gamemode INI Configuration

The system MUST write a `gamemode.ini` configuration file with I/O and process priority
tuning. The file MUST NOT include governor switching (managed by cpu-performance-governor).

Required settings:
- `renice = -10`
- `ioprio = 0`
- `inhibit_screensaver = 1`

#### Scenario: CS2 process reniced during gameplay

- GIVEN `gamemoded.service` is active and CS2 is launched with `gamemoderun`
- WHEN CS2 is running
- THEN `ps -o ni -p $(pgrep cs2)` returns `-10`
- AND `systemctl status gamemoded` shows the CS2 process registered

#### Scenario: Screensaver inhibited during gameplay

- GIVEN `gamemode.ini` sets `inhibit_screensaver = 1`
- WHEN CS2 is running via `gamemoderun`
- THEN the system screensaver and display sleep do NOT activate during the session
