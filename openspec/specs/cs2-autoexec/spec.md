# CS2 Autoexec Configuration Specification

## Purpose
Create a CS2 autoexec.cfg with FPS uncap, performance rendering settings, and
network optimization parameters for 128-tick servers.

## Requirements

### Requirement: Autoexec File Exists and Is Sourced

The file MUST exist at:
`~/.local/share/Steam/steamapps/common/Counter-Strike Global Offensive/game/cfg/autoexec.cfg`

The file MUST be sourced automatically via `+exec autoexec` in Steam launch options.

#### Scenario: Autoexec sourced on CS2 launch

- GIVEN the file exists and `+exec autoexec` is in launch options
- WHEN CS2 starts
- THEN the console shows no "file not found" error for autoexec
- AND `fps_max` value in-game matches the value set in the file

### Requirement: FPS and Rendering Settings

The autoexec MUST set FPS and rendering variables for maximum performance.

Required settings:
- `fps_max 0` — uncap FPS
- `cl_showfps 1` — show FPS counter (MAY be disabled after initial verification)
- `r_dynamic 0` — disable dynamic lighting

#### Scenario: FPS counter visible in-game

- GIVEN `cl_showfps 1` is in autoexec
- WHEN CS2 is running
- THEN the FPS counter is visible in the top-left corner of the screen

#### Scenario: Dynamic lighting disabled

- GIVEN `r_dynamic 0` is in autoexec
- WHEN CS2 is running
- THEN no dynamic light sources cast real-time shadows on map geometry

### Requirement: Network Rate Optimization

The autoexec MUST set network rate variables tuned for 128-tick servers.

Required settings:
- `rate 786432`
- `cl_cmdrate 128`
- `cl_updaterate 128`
- `cl_interp_ratio 1`
- `cl_interp 0`

#### Scenario: Network settings applied at launch

- GIVEN the network vars are in autoexec
- WHEN CS2 is running and `net_graph 1` is enabled in console
- THEN the net graph shows cmd rate and update rate at 128
- AND interp values match the configured settings
