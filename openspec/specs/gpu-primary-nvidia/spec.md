# GPU Primary NVIDIA Specification

## Purpose
Force GTX 1650 Mobile as the primary GPU for the entire system by setting global environment
variables, replacing Intel UHD as the default renderer.

## Requirements

### Requirement: Global NVIDIA Environment Variables

The system MUST set NVIDIA offload environment variables in `/etc/environment` so that all
graphical applications use the GTX 1650 as the primary renderer.

Variables required:
- `__NV_PRIME_RENDER_OFFLOAD=1`
- `__GLX_VENDOR_LIBRARY_NAME=nvidia`
- `__VK_LAYER_NV_optimus=NVIDIA_only`
- `DRI_PRIME=1`

#### Scenario: NVIDIA renderer active after reboot

- GIVEN the environment variables are set in `/etc/environment`
- WHEN the system reboots and any OpenGL/Vulkan application launches
- THEN `glxinfo | grep "OpenGL renderer"` MUST return a string containing "NVIDIA"
- AND the Intel UHD GPU MUST NOT be reported as the active renderer

#### Scenario: Variables persist across reboots

- GIVEN the variables are written to `/etc/environment`
- WHEN the system reboots
- THEN `cat /etc/environment` contains all four NVIDIA variables
- AND no pre-existing unrelated variable is overwritten

#### Scenario: Rollback removes NVIDIA routing

- GIVEN the NVIDIA variables are present in `/etc/environment`
- WHEN the four NVIDIA variables are removed from `/etc/environment` and the system reboots
- THEN `glxinfo | grep "OpenGL renderer"` returns the Intel UHD renderer
- AND no residual NVIDIA routing is active
