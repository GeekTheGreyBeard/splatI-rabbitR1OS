# Rabbit/OpenClaw System Change Requests

This file tracks requested system-level changes that should be considered for
the next Rabbit/OpenClaw build or curated app install profile.

## 2026-06-21 Camera Replacement

Problem: the current camera app is not acceptable for the Rabbit/OpenClaw
device identity. The subject preview is too small, and the app does not expose
the front/rear rotation or flip controls needed for normal use.

Target behavior:

- Large live subject preview sized for the Rabbit R1 display.
- Simple capture control that is easy to use on the small screen.
- Front/rear camera switch.
- Mirror/flip handling for user-facing camera use.
- Rotation handling so preview and saved images match expected orientation.
- Candidate path may be a better installed camera app, configuration of an
  existing app, or a purpose-built lightweight OpenClaw camera app.

Decision note: hardware PTT is no longer a build requirement. OpenClaw
Realtime Talk is the required voice experience and does not depend on the
side-button bridge.
