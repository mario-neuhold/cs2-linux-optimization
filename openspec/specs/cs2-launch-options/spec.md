# CS2 Launch Options Specification

## Purpose
Define the optimized Steam launch options for CS2 (App ID 730) to maximize performance
and ensure correct GPU routing and process priority.

## Requirements

### Requirement: Optimized Launch String for App ID 730

CS2 MUST be launched in Steam with a launch options string that includes all required
performance flags. Order of flags MAY vary.

Required components:
- `gamemoderun %command%` — activates gamemode for the CS2 process
- `-novid` — skips the intro video on launch
- `-high` — requests high OS process priority
- `-threads 4` — sets thread count to match i5-10300H physical core count
- `+fps_max 0` — uncaps the in-game FPS limiter
- `+exec autoexec` — sources autoexec.cfg on launch

#### Scenario: CS2 launches without intro video

- GIVEN the launch options include `-novid`
- WHEN CS2 is started from Steam
- THEN the intro video is skipped and the main menu loads directly

#### Scenario: FPS is uncapped in-game

- GIVEN `+fps_max 0` is in the launch options
- WHEN CS2 is running
- THEN the in-game FPS counter shows values not capped at 30 or 60

#### Scenario: Gamemode applied to CS2 process

- GIVEN `gamemoderun` is in the launch string and `gamemoded` is active
- WHEN CS2 is running
- THEN `ps -o ni -p $(pgrep cs2)` returns a negative nice value
- AND `gamemoded -s` reports CS2 as a registered client

#### Scenario: Rollback clears launch options

- GIVEN launch options are set for App ID 730
- WHEN the user opens Steam → CS2 Properties → Launch Options and clears the field
- THEN CS2 launches with default Steam behavior (no flags applied)
