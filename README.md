# kos-workspace

Orbital mechanics and guidance library built on the [kOS](https://ksp-kos.github.io/KOS/) scriptable flight computer platform. All astrodynamics algorithms are implemented from scratch without black-box solvers.

## Core Library (`src/core/`)

| Module | What it implements |
|---|---|
| `orbit.ks` | Kepler's equation (Newton-Raphson, elliptic/hyperbolic/near-parabolic), vis-viva, Keplerian element conversions, true/mean anomaly, time-of-flight, Hohmann phase angles, reference frame rotations (TZN, RNP, PQW, inertial) with flight-path-angle corrections for non-circular orbits |
| `node.ks` | Maneuver planning: apsis changes at arbitrary true anomaly, orbital plane changes, SOI escape targeting |
| `burn.ks` | Tsiolkovsky rocket equation, burn duration with mass depletion, split-burn timing |
| `engine.ks` | Multi-engine throttle management, pressure-dependent Isp, flameout detection |
| `trig.ks` | Hyperbolic trig (`sinh`, `cosh`, `asinh`, `acosh`) for hyperbolic orbit math |
| `geo_nav.ks` | Haversine great-circle distance and bearing |

## Flight Scripts (`src/scripts/`)

| Script | What it does |
|---|---|
| `launch.ks` | Launch guidance with azimuth correction for body rotation, velocity-scheduled gravity turn, TWR throttle control, auto-staging, and circularization |
| `transfer.ks` | Hohmann and bi-elliptic transfer planning with atmospheric safety checks |
| `transfer_to.ks` | Encounter targeting with phase angle timing, golden-section periapsis minimization, and bisection altitude convergence |
| `circular_escape.ks` | Directional SOI escape with body rotation correction and hyperbolic trajectory geometry |
| `midcourse.ks` | Mid-course correction via Newton iteration with finite-difference Jacobian, simultaneously targeting inclination and periapsis |
| `land.ks` | Powered descent with closed-form stopping distance under continuous thrust with varying mass, and throttle modulation for terminal descent |
| `hop.ks` | Suborbital hop with impact-point convergence steering and mid-course corrections |
| `target_angle.ks` | Co-orbital phasing via period-matching bi-elliptic maneuver |

## Tools (`tools/`)

- **`build.py`**: BFS dependency resolver and package builder for deploying script sets to flight computers
- **`telnet.py`**: Telnet client for commanding kOS CPUs with error detection
