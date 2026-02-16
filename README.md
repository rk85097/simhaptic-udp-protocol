# SimHaptic External UDP Telemetry Protocol

**Protocol Version:** 1
**SimHaptic Version:** 2.2.2+
**Last Updated:** 2026-02-16

---

## Table of Contents

1. [Overview](#1-overview)
2. [Connection Setup](#2-connection-setup)
3. [Packet Format](#3-packet-format)
4. [Complete Field Reference](#4-complete-field-reference)
5. [Enum Reference](#5-enum-reference)
6. [Effect Data Requirements](#6-effect-data-requirements)
7. [Best Practices](#7-best-practices)
8. [Connection Verification (Ping/Pong)](#8-connection-verification-pingpong)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Overview

The SimHaptic External UDP Protocol allows **any flight simulator or vehicle simulator** to send telemetry data to SimHaptic, enabling the full suite of haptic effects without requiring a native integration.

Instead of SimHaptic connecting to your simulator directly, **your simulator sends UDP packets to SimHaptic**. SimHaptic receives this data and processes it exactly as it does for natively supported simulators (MSFS, X-Plane, DCS, IL-2, Falcon BMS).

### How It Works

```
┌─────────────────────┐     Telemetry (JSON)       ┌─────────────────────┐
│                     │  ───────────────────────►  │                     │
│  Your Simulator     │  <SimHaptic-IP>:19872      │    SimHaptic        │
│                     │    20-60 packets/sec       │                     │
│  (sends telemetry)  │                            │  (drives haptics)   │
│                     │     Ping (JSON)            │                     │
│                     │  ───────────────────────►  │                     │
│                     │     Pong (JSON)            │                     │
│                     │   ◄─────────────────────── │                     │
└─────────────────────┘                            └─────────────────────┘
```

### Key Points

- **Protocol**: JSON over UDP
- **Telemetry**: Your simulator sends telemetry **to** SimHaptic (one-way, no response).
- **Ping/Pong**: Your simulator can send a **ping** packet to verify SimHaptic is reachable. SimHaptic replies with a **pong** (see [Section 8](#8-connection-verification-pingpong)). Telemetry packets do **not** trigger a pong.
- **Target**: `127.0.0.1` (localhost) or the LAN IP of the SimHaptic PC, port `19872` (configurable)
- **Rate**: Send packets at your simulation frame rate, ideally **20-60 Hz**
- **Partial data is fine**: Only send the fields you have. Missing fields default to zero/false. Effects that depend on missing data simply won't activate.

---

## 2. Connection Setup

### Network Details

| Setting           | Value                                      |
|-------------------|--------------------------------------------|
| Protocol          | UDP (SOCK_DGRAM)                           |
| IP Address        | `127.0.0.1` (localhost) or LAN IP of the SimHaptic PC |
| Port              | `19872` (configurable in SimHaptic settings)|
| Max Packet Size   | 4096 bytes                                 |
| Encoding          | UTF-8                                      |

### Connection Lifecycle

1. **SimHaptic opens a UDP socket** and listens on all network interfaces (`0.0.0.0`) on the configured port when "External UDP" is selected. This means it accepts packets from localhost as well as from other machines on your LAN.
2. **Your simulator sends packets** to that port. No handshake is needed.
3. **SimHaptic considers itself "connected"** as soon as it receives the first valid packet.
4. **SimHaptic considers itself "paused/disconnected"** if no packets arrive for more than **1 second**, or if the `isPaused` field is set to `true` in the packet.
5. **To reconnect**, simply start sending packets again. SimHaptic auto-reconnects.

### Important

- SimHaptic must be running with "External UDP" selected **before** your simulator starts sending, or simultaneously. SimHaptic continuously listens once started.
- Only one simulator should send to the port at a time. SimHaptic processes packets sequentially.

---

## 3. Packet Format

Each UDP packet is a single **JSON object** encoded as a UTF-8 string. No framing, no length prefix, no newlines required - just the raw JSON bytes.

### Required Fields

Every packet **must** include:

| Field           | Type   | Description                              |
|-----------------|--------|------------------------------------------|
| `sh`            | int    | Protocol version. Must be `1`.           |
| `aircraftTitle` | string | Name/identifier of the current aircraft. |

The `sh` field identifies the packet as a SimHaptic telemetry packet and specifies the protocol version. The `aircraftTitle` is used to detect aircraft changes (loading a new aircraft triggers profile reloading).

### All Other Fields Are Optional

Every other field is optional. If omitted, SimHaptic uses the default value (typically `0`, `0.0`, or `false`). Effects that depend on missing data will simply not activate.

### Aircraft Change Detection

When `aircraftTitle` changes between packets, SimHaptic treats it as a new aircraft load event. This triggers:
- Effect profile reloading
- Aircraft type recalculation
- State resets

Send the same `aircraftTitle` consistently for the same aircraft. Only change it when the user actually switches aircraft.

---

## 4. Complete Field Reference

### 4.1 Metadata Fields

| JSON Field      | Type   | Default   | Description |
|-----------------|--------|-----------|-------------|
| `sh`            | int    | *(required)* | Protocol version. Must be `1`. |
| `aircraftTitle` | string | *(required)* | Aircraft name/identifier. Used for profile matching and change detection. |
| `acType`        | string | `"piston"` | Aircraft category. Determines which effect behaviors are used. See [Enum: acType](#51-actype). |
| `engineType`    | string | `"Piston"` | Engine type. Affects engine sound selection and effect behavior. See [Enum: engineType](#52-enginetype). |
| `surfaceType`   | string | `"Concrete"` | Current ground surface type. Affects ground roll, bumps, and grass effects. See [Enum: surfaceType](#53-surfacetype). |

### 4.2 Boolean State Fields

| JSON Field          | Type | Default | Description |
|---------------------|------|---------|-------------|
| `batteryState`      | bool | `false` | `true` when electrical power (battery/generator) is available. |
| `hasRetractableGear`| bool | `false` | `true` if the aircraft has retractable landing gear. |
| `hasFloats`         | bool | `false` | `true` if the aircraft has floats (seaplane). |
| `isParkingBrakeSet` | bool | `false` | `true` when the parking brake is engaged. |
| `isFuelPumpOn`      | bool | `false` | `true` when the fuel pump is active. |
| `isTowConnected`    | bool | `false` | `true` when a tow rope is connected (gliders). |
| `canopyJettison`    | bool | `false` | `true` when the canopy has been jettisoned (military). |
| `isCannonFireOn`    | bool | `false` | `true` when guns/cannons are actively firing. |
| `isAutoFlapsOn`     | bool | `false` | `true` when auto-flaps mode is engaged. |
| `isPaused`          | bool | `false` | `true` when the simulation is paused. When `true`, SimHaptic treats the sim as paused and stops all effects. When `false` (or omitted), SimHaptic runs effects normally. This allows explicit pause signaling without stopping packet transmission. |
| `isInCockpit`       | bool | `true`  | `true` when the camera is in cockpit view. Effects are muted when `false`. **Default is `true`** - only set to `false` if you want to mute effects in external views. |

See also: [Section 4.8](#48-engine--propulsion-per-engine) for per-engine booleans (`engine1Running`, `engine1StarterOn`, etc.) and [Section 4.5](#45-landing-gear-per-gear) for per-gear ground contact booleans (`gearFrontOnGround`, etc.).

### 4.3 Float Fields - Flight Performance

| JSON Field              | Type  | Unit           | Default | Range       | Description |
|-------------------------|-------|----------------|---------|-------------|-------------|
| `agl`                   | float | feet           | `0.0`   | 0+          | Altitude Above Ground Level. |
| `ias`                   | float | knots          | `0.0`   | 0+          | Indicated Airspeed. |
| `groundSpeed`           | float | knots          | `0.0`   | 0+          | Ground speed. |
| `vso`                   | float | knots          | `0.0`   | 0+          | Stall speed (VS0 - stall speed in landing configuration). Used as reference for ground roll effects. |
| `vne`                   | float | knots          | `0.0`   | 0+          | Never-Exceed speed (VNE). Used for overspeed detection. |
| `gforce`                | float | G              | `0.0`   | any         | Current G-force. Normal flight = ~1.0. Positive = pull up, negative = push over. |
| `verticalSpeed`         | float | feet/min (fpm) | `0.0`   | any         | Vertical speed. Negative = descending. Used for touchdown detection. |
| `stallPercentage`       | float | 0.0 - 1.0     | `0.0`   | 0.0 - 1.0  | Stall proximity. 0 = no stall, 1 = full stall. Alternative to `isStalling` for gradual stall effects. |
| `windshieldWindVelocity`| float | knots          | `0.0`   | 0+          | Wind velocity on the windshield. |
| `densityAltFt`          | float | feet           | `0.0`   | any         | Density altitude. Used for helicopter VRS/ETL calculations. |

### 4.4 Float Fields - Aircraft Attitude & Accelerations

| JSON Field          | Type  | Unit    | Default | Range   | Description |
|---------------------|-------|---------|---------|---------|-------------|
| `acPitch`           | float | degrees | `0.0`   | -90/+90 | Aircraft pitch angle. Nose up = positive. |
| `acRoll`            | float | degrees | `0.0`   | -180/+180 | Aircraft roll/bank angle. Right wing down = positive. |
| `relativeYaw`       | float | degrees | `0.0`   | any     | Relative yaw / sideslip angle. |
| `accX`              | float | G       | `0.0`   | any     | Longitudinal acceleration (forward/back). Used for catapult detection (> 1.4G). |
| `bodyAccelerationY` | float | G       | `0.0`   | any     | Lateral body acceleration. Used for turbulence detection. |

### 4.5 Landing Gear (Per-Gear)

| JSON Field           | Type  | Unit   | Default | Range     | Description |
|----------------------|-------|--------|---------|-----------|-------------|
| `gearFrontPosition`  | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Front/nose gear position. 0 = up, 1 = down. Use intermediate values during transit. |
| `gearLeftPosition`   | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Left main gear position. |
| `gearRightPosition`  | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Right main gear position. |
| `gearFrontOnGround`  | bool  | -      | `false` | -         | Front/nose gear is touching the ground. |
| `gearLeftOnGround`   | bool  | -      | `false` | -         | Left main gear is touching the ground. |
| `gearRightOnGround`  | bool  | -      | `false` | -         | Right main gear is touching the ground. |

**Ground contact detection**: SimHaptic considers the aircraft "on the ground" when **any** gear is on the ground. Many effects (touchdown, ground roll, brakes, etc.) depend on this. Set the relevant gear booleans to `true` when wheels are in contact with the surface. For fixed-gear aircraft, the gear positions stay at 1.0 and you only need to update the on-ground booleans.

### 4.6 Float Fields - Control Surfaces & Other Positions

| JSON Field          | Type  | Unit   | Default | Range     | Description |
|---------------------|-------|--------|---------|-----------|-------------|
| `flapsPosition`     | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Flaps extension. 0 = retracted, 1 = fully extended. |
| `spoilersPosition`  | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Spoilers / speed brakes position. 0 = retracted, 1 = fully deployed. |
| `brakes`            | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Wheel brake input amount. 0 = no braking, 1 = full brakes. |
| `doorPos`           | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Door / canopy position. 0 = closed, 1 = fully open. |
| `hookPos`           | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Tail hook position (carrier aircraft). 0 = up, 1 = down. |
| `wingPos`           | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Variable wing sweep or fold position. 0 = forward/unfolded, 1 = swept/folded. |
| `fuelProbePos`      | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Aerial refueling probe position. 0 = retracted, 1 = extended. |
| `dragChute`         | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Drag chute deployment. 0 = stowed, >0 = deployed. |

### 4.7 Float Fields - Control Inputs

| JSON Field | Type  | Unit    | Default | Range        | Description |
|------------|-------|---------|---------|--------------|-------------|
| `yokeX`    | float | -1 to 1 | `0.0`  | -1.0 - 1.0  | Yoke/stick lateral position. -1 = full left, +1 = full right. |
| `yokeY`    | float | -1 to 1 | `0.0`  | -1.0 - 1.0  | Yoke/stick longitudinal position. -1 = full forward, +1 = full back. |

### 4.8 Engine & Propulsion (Per-Engine)

The protocol supports up to 4 engines. For single-engine aircraft, use `engine1*` fields only.

| JSON Field               | Type  | Unit   | Default | Range      | Description |
|--------------------------|-------|--------|---------|------------|-------------|
| `engine1Speed`           | float | %      | `0.0`   | 0 - 100    | Engine 1 speed as percentage of max. For jets: N1%. For pistons: RPM%. |
| `engine2Speed`           | float | %      | `0.0`   | 0 - 100    | Engine 2 speed. |
| `engine3Speed`           | float | %      | `0.0`   | 0 - 100    | Engine 3 speed. |
| `engine4Speed`           | float | %      | `0.0`   | 0 - 100    | Engine 4 speed. |
| `engine1Running`         | bool  | -      | `false` | -          | Engine 1 is running. |
| `engine2Running`         | bool  | -      | `false` | -          | Engine 2 is running. |
| `engine3Running`         | bool  | -      | `false` | -          | Engine 3 is running. |
| `engine4Running`         | bool  | -      | `false` | -          | Engine 4 is running. |
| `engine1StarterOn`       | bool  | -      | `false` | -          | Engine 1 starter motor active. |
| `engine2StarterOn`       | bool  | -      | `false` | -          | Engine 2 starter motor active. |
| `engine3StarterOn`       | bool  | -      | `false` | -          | Engine 3 starter motor active. |
| `engine4StarterOn`       | bool  | -      | `false` | -          | Engine 4 starter motor active. |
| `engine1AfterburnerRatio`| float | 0 - 1  | `0.0`   | 0.0 - 1.0  | Engine 1 afterburner level. 0 = off, 1 = full afterburner. |
| `engine2AfterburnerRatio`| float | 0 - 1  | `0.0`   | 0.0 - 1.0  | Engine 2 afterburner level. |
| `engine3AfterburnerRatio`| float | 0 - 1  | `0.0`   | 0.0 - 1.0  | Engine 3 afterburner level. |
| `engine4AfterburnerRatio`| float | 0 - 1  | `0.0`   | 0.0 - 1.0  | Engine 4 afterburner level. |
| `engine1ReverseThrust`   | float | 0 - 1  | `0.0`   | 0.0 - 1.0  | Engine 1 reverse thrust. 0 = off, 1 = full reverse. |
| `engine2ReverseThrust`   | float | 0 - 1  | `0.0`   | 0.0 - 1.0  | Engine 2 reverse thrust. |
| `engine3ReverseThrust`   | float | 0 - 1  | `0.0`   | 0.0 - 1.0  | Engine 3 reverse thrust. |
| `engine4ReverseThrust`   | float | 0 - 1  | `0.0`   | 0.0 - 1.0  | Engine 4 reverse thrust. |
| `apu`                    | float | 0 - 1  | `0.0`   | 0.0 - 1.0  | APU (Auxiliary Power Unit) status/speed. 0 = off, 1 = running. |

**Single-engine aircraft**: Just send `engine1Speed`, `engine1Running`, etc. Leave engine 2-4 fields unset.

**How SimHaptic uses per-engine data currently**: SimHaptic aggregates per-engine data internally — for example, the engine vibration effect uses the average speed across running engines, and "engine running" is true if any engine is running. In the future, SimHaptic will support routing individual engines to specific shakers, at which point the per-engine data enables that without any changes on your side.

### 4.9 Float Fields - Weight & Geometry

| JSON Field      | Type  | Unit   | Default | Description |
|-----------------|-------|--------|---------|-------------|
| `emptyWeight`   | float | lbs    | `0.0`   | Aircraft empty weight. |
| `totalWeight`   | float | lbs    | `0.0`   | Current total weight (fuel + payload). Used for helicopter VRS/ETL. |
| `maxGrossWeight`| float | lbs    | `0.0`   | Maximum gross weight. Used for helicopter VRS/ETL weight factor. |
| `wingSpanM`     | float | meters | `0.0`   | Wing span in meters. Used for wingtip strike detection (gliders). |

### 4.10 Helicopter-Specific (Per-Rotor)

| JSON Field      | Type  | Unit   | Default | Range     | Description |
|-----------------|-------|--------|---------|-----------|-------------|
| `collective`    | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Helicopter collective input. 0 = full down, 1 = full up. |
| `rotor1RpmNorm` | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Main rotor RPM normalized. 0 = stopped, 1 = 100% RPM. |
| `rotor2RpmNorm` | float | 0 - 1  | `0.0`   | 0.0 - 1.0 | Second rotor RPM normalized. For tandem-rotor helicopters (e.g., CH-47 Chinook) or tail rotor if available. |

**Single-rotor helicopters**: Just send `rotor1RpmNorm`. Leave `rotor2RpmNorm` unset.

### 4.11 Integer Fields - Ordnance & Countermeasures

| JSON Field       | Type | Default | Description |
|------------------|------|---------|-------------|
| `gunShellsCount` | int  | `0`     | Current gun/cannon ammunition count. SimHaptic detects firing by monitoring count *changes*. |
| `bombsCount`     | int  | `0`     | Current bomb count. Drop detected by count *decrease*. |
| `fuelTanksCount` | int  | `0`     | Current external fuel tank count. Drop detected by count *decrease*. |
| `otherItemCount` | int  | `0`     | Miscellaneous payload item count. Drop detected by count *decrease*. |
| `missilesCount`  | int  | `0`     | Current missile/rocket count. Launch detected by count *decrease*. |
| `flareCount`     | int  | `0`     | Current flare/chaff count. Release detected by count *decrease*. |

**Important note on ordnance fields:** SimHaptic detects weapon events by monitoring **changes** in these counters. For example, if `gunShellsCount` goes from 500 to 498 between packets, SimHaptic triggers the gun firing effect. The absolute values don't matter - only the changes do. Start with the actual loaded count and decrement as items are used.

### 4.12 Float Field - Damage

| JSON Field | Type  | Default | Range     | Description |
|------------|-------|---------|-----------|-------------|
| `damage`   | float | `0.0`   | 0.0 - 1.0 | Aircraft damage level. SimHaptic detects new hits by monitoring *increases* in this value. Start at 0, increase as damage accumulates. |

---

## 5. Enum Reference

These fields accept string values. Values are **case-sensitive**.

### 5.1 acType

Aircraft category. Determines which effect algorithms and behaviors are used.

| Value          | Description |
|----------------|-------------|
| `"piston"`     | Piston-engine aircraft (Cessna 172, Piper, etc.) |
| `"turboprop"`  | Turboprop aircraft (King Air, TBM, etc.) |
| `"jet"`        | Jet aircraft (airliners, business jets) |
| `"helicopter"` | Rotary-wing aircraft. Enables helicopter-specific effects (VRS, ETL, blade slapping). |
| `"seaplane"`   | Seaplane / amphibious aircraft |
| `"glider"`     | Glider / sailplane. Enables glider-specific effects (wind, tow disconnect, wingtip strike). |
| `"military"`   | Military aircraft (fighters, bombers). Enables combat effects. |

### 5.2 engineType

Engine type. Affects engine vibration sound selection and behavior.

| Value          | Description |
|----------------|-------------|
| `"Piston"`     | Piston/reciprocating engine |
| `"Jet"`        | Jet/turbofan engine |
| `"Turboprop"`  | Turboprop engine |
| `"Helo"`       | Helicopter turboshaft engine |
| `"None"`       | No engine (glider) |

### 5.3 surfaceType

Current ground surface type. Affects ground roll character, bump frequency, and grass effects.

| Value      | Description |
|------------|-------------|
| `"Hard"`   | Hard/paved surface (concrete, asphalt, tarmac, etc.). Enables `ground_roll` and `ground_bumps` effects. |
| `"Soft"`   | Soft/unpaved surface (grass, dirt, sand, snow, etc.). Enables `grass_roll` effect. |
| `"Water"`  | Water surface. Disables touchdown effect. |

Default: `"Hard"`

---

## 6. Effect Data Requirements

This is the most important section for simulator developers. For each haptic effect, this table shows **exactly which telemetry fields you must send** for that effect to work.

### How to Read This Table

- **Effect**: The haptic effect name
- **Required Fields**: All JSON fields that must be sent with valid data for the effect to activate
- **Priority**: How important this effect typically is (Core = most users want it, Extended = nice to have, Specialized = only certain aircraft types)
- **Per-component fields**: Engine, gear, and rotor data uses per-component field names (e.g., `engine1Speed`, `gearFrontOnGround`). When the table shows a range like `engine1Running` – `engine4Running`, send fields for each engine your aircraft has — a single-engine aircraft only needs `engine1Running`. The "Why It's Needed" column explains how SimHaptic aggregates them (any, average, or max).

### 6.1 Core Flight Effects

These are the effects most users expect. Prioritize implementing these fields first.

#### Engine Vibrations
> Continuous vibration from the engine through the airframe. The most fundamental effect.

| Required Field     | Why It's Needed |
|--------------------|-----------------|
| `engine1Speed` – `engine4Speed` | Vibration intensity scales with engine speed (0-100%). SimHaptic averages across running engines. Send for each engine your aircraft has. |
| `groundSpeed`      | Vibration reduces with speed (wind noise masks engine) |
| `acType`           | Helicopter engines behave differently |
| `engineType`       | Sound selection depends on engine type |
| `engine1Running` – `engine4Running` | Effect only active when at least one engine is running |

#### Touchdown
> Impact vibration when the aircraft lands.

| Required Field       | Why It's Needed |
|----------------------|-----------------|
| `verticalSpeed`      | Landing intensity scales with descent rate (fpm) |
| `gearFrontOnGround` / `gearLeftOnGround` / `gearRightOnGround` | Triggers on air-to-ground transition (any gear touching ground) |
| `agl`                | Must be near ground (< 50 ft recent history) |
| `surfaceType`        | No effect on water landings |

#### Ground Roll
> Continuous vibration while rolling on a hard runway.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `groundSpeed`     | Intensity increases with speed |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only active when any gear is on the ground |
| `agl`             | Confirms ground contact |
| `vso`             | Used as reference speed for intensity curve |
| `surfaceType`     | Only activates on hard surfaces (concrete, asphalt, tarmac, etc.) |

#### G-Force
> Airframe shaking under high G-loads.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `gforce`          | Effect activates above user-configurable threshold (default 1.5G) |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Behavior differs on ground vs. in flight |

#### Stall
> Airframe buffet during aerodynamic stall.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `stallPercentage` | Primary driver. 0.0 = no stall, 1.0 = full stall. **This value is used directly as the effect intensity** — a value of 0.5 means 50% stall buffet intensity. For the best experience, ramp this value gradually as the aircraft approaches stall (e.g. start at 0.1-0.2 near stall onset, increase toward 1.0 in a deep stall) rather than sending a hard 0/1 switch. |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Disabled on ground |
| `agl`             | Minimum altitude threshold (10 ft) for activation |

#### Flaps Movement
> Vibration/thump when flaps extend or retract.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `flapsPosition`   | Effect detects *changes* in position. Must send continuously. |
| `engine1Running` – `engine4Running` | Behavior varies with engine state. Effect checks if **any** engine is running. |
| `isAutoFlapsOn`   | Effect is suppressed when auto-flaps are active |

#### Gear Up/Down
> Mechanical vibration during gear extension/retraction.

| Required Field                   | Why It's Needed |
|----------------------------------|-----------------|
| `gearFrontPosition` / `gearLeftPosition` / `gearRightPosition` | Effect detects *movement* (position changes between packets) |

#### Overspeed
> Airframe shaking when exceeding VNE.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `ias`          | Compared against VNE |
| `vne`          | Never-exceed speed. Effect starts at VNE-10 knots. |

### 6.2 Ground Effects

#### Ground Bumps
> Random bump impacts while taxiing at speed on hard surfaces.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `groundSpeed`     | Higher speed = more frequent bumps |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only active when any gear is on the ground |
| `agl`             | Confirms ground contact |
| `surfaceType`     | Only on hard surfaces |

#### Grass Roll
> Soft rumble while rolling on grass/dirt surfaces.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `groundSpeed`     | Intensity increases with speed |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only active when any gear is on the ground |
| `agl`             | Confirms ground contact |
| `surfaceType`     | Only activates on soft surfaces (grass, dirt, sand, etc.) |
| `vso`             | Reference speed for intensity curve |

#### Brakes
> Vibration from wheel braking.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `brakes`          | Brake input amount (0-1) |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only active when any gear is on the ground |
| `groundSpeed`     | Effect fades as speed decreases |

#### Parking Brake
> Thump when parking brake is set or released.

| Required Field       | Why It's Needed |
|----------------------|-----------------|
| `isParkingBrakeSet`  | Triggers on state *change* (set or release) |

#### Reverse Thrust
> Engine rumble during thrust reverser deployment.

| Required Field          | Why It's Needed |
|-------------------------|-----------------|
| `engine1ReverseThrust` – `engine4ReverseThrust` | Intensity matches reverser engagement (0-1). SimHaptic uses the **max** across all engines. Send for each engine your aircraft has. |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only active when any gear is on the ground |
| `engine1Running` – `engine4Running` | Requires at least one engine running |

### 6.3 Aerodynamic Effects

#### Flaps Drag
> Continuous vibration from extended flaps in flight.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `flapsPosition`   | Intensity scales with flap extension |
| `agl`             | Fades in above 5 ft AGL |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only active in flight (all gear off ground) |

#### Gear Drag
> Vibration from extended landing gear in flight.

| Required Field         | Why It's Needed |
|------------------------|-----------------|
| `gearFrontPosition` / `gearLeftPosition` / `gearRightPosition` | Intensity scales with gear extension |
| `hasRetractableGear`    | Only activates for retractable gear aircraft |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only active in flight (all gear off ground) |
| `agl`                   | Fades in above 5 ft AGL |

#### Air Brake Drag
> Vibration from deployed speed brakes in flight.

| Required Field      | Why It's Needed |
|---------------------|-----------------|
| `spoilersPosition`  | Intensity scales with brake extension |
| `ias`               | Speed factor applied |
| `vne`               | Used to calculate speed factor |

#### Air Brake Movement
> Vibration during speed brake extension/retraction.

| Required Field      | Why It's Needed |
|---------------------|-----------------|
| `spoilersPosition`  | Effect detects *movement* (position changes) |

#### Turbulence
> Airframe shaking from atmospheric turbulence.

| Required Field        | Why It's Needed |
|-----------------------|-----------------|
| `bodyAccelerationY`   | Primary input: lateral acceleration variability indicates turbulence |
| `agl`                 | Altitude factor |
| `ias`                 | Speed factor |
| `vne`                 | Speed normalization |
| `gforce`              | Zero-crossing detection for turbulence indication |
| `yokeY`               | Filters out pilot-induced accelerations |
| `relativeYaw`         | Filters out rudder-induced accelerations |
| `stallPercentage`     | Filters out stall-induced shaking |

#### Glider Wind
> Wind noise/vibration over the glider airframe.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `ias`          | Intensity scales linearly with airspeed |
| `vne`          | Used to normalize speed |

#### Airframe Airflow
> Vibration from abrupt control movements disturbing airflow.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `yokeX`        | Lateral stick movement rate |
| `yokeY`        | Longitudinal stick movement rate |
| `ias`          | Speed factor for airflow intensity |

### 6.4 Engine & Systems Effects

#### Engine Rumble
> Low-frequency engine roughness vibration while stationary.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `engine1Speed` – `engine4Speed` | Engine speed variability analyzed for roughness. SimHaptic averages across running engines. |
| `groundSpeed`     | Only active at low speed (< 15 knots) |
| `engineType`      | Behavior varies by engine type |
| `acType`          | Behavior varies by aircraft type |

#### Engine Start (Piston)
> Torque vibration during piston engine startup.

| Required Field       | Why It's Needed |
|----------------------|-----------------|
| `engine1StarterOn` – `engine4StarterOn` | Triggers when **any** starter activates |
| `engine1Speed` – `engine4Speed` | Tracks engine acceleration during start |

#### Engine Stop (Piston)
> Torque vibration during piston engine shutdown.

| Required Field            | Why It's Needed |
|---------------------------|-----------------|
| `engine1Speed` – `engine4Speed` | Tracks engine deceleration. SimHaptic derives power-producing state from speed internally. |
| `engine1StarterOn` – `engine4StarterOn` | Excludes starter restarts |
| `engine1Running` – `engine4Running` | Confirms engine was running |

#### Avionics
> Gentle electrical equipment vibration.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `batteryState`    | Active when electrical power is on |
| `groundSpeed`     | Fades out above 25 knots (masked by other vibrations) |

#### Fuel Pump
> Gentle fuel pump vibration.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `isFuelPumpOn`    | Active when fuel pump is on |
| `groundSpeed`     | Fades out with speed |

#### APU
> Auxiliary power unit vibration on the ground.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `apu`             | APU speed/status (0-1) |
| `groundSpeed`     | Fades out above 15 knots |

#### Afterburner
> Deep rumble from afterburner engagement.

| Required Field              | Why It's Needed |
|-----------------------------|-----------------|
| `engine1AfterburnerRatio` – `engine4AfterburnerRatio` | Intensity matches afterburner level (0-1). SimHaptic uses the **max** across all engines. Send for each engine your aircraft has. |

### 6.5 Mechanical Movement Effects

#### Door Open/Close
> Vibration during door or canopy movement.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `doorPos`      | Effect detects *movement* and direction of door (0-1) |

#### Controls Deflection
> Thump when control surfaces hit their stops.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `yokeX`          | Triggers when value exceeds 0.99 (full deflection) |
| `yokeY`          | Triggers when value exceeds 0.99 (full deflection) |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only active when any gear is on the ground |

#### Hook Up/Down
> Vibration during tail hook extension/retraction.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `hookPos`      | Effect detects *movement* (position changes) |

#### Wing Fold/Sweep
> Vibration during variable-geometry wing movement.

| Required Field     | Why It's Needed |
|--------------------|-----------------|
| `wingPos`          | Effect detects *movement rate* |
| `isAutoFlapsOn`    | Suppressed during auto-flaps |
| `engine1Running` – `engine4Running` | Engine state affects intensity. Effect checks if **any** engine is running. |

#### Fuel Probe
> Vibration during aerial refueling probe deployment.

| Required Field  | Why It's Needed |
|-----------------|-----------------|
| `fuelProbePos`  | Effect detects *movement* (position changes) |

#### Drag Chute
> Vibration from drag chute deployment and deceleration.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `dragChute`    | Deployment level (0-1) |
| `groundSpeed`  | Effect scales with speed, fades as speed drops |

### 6.6 Combat Effects

#### Gun (Fast)
> High-rate cannon fire vibration.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `gunShellsCount`  | Firing detected by count *decrease* between packets |
| `isCannonFireOn`  | Alternative trigger for specific aircraft |
| `acType`          | Behavior varies by aircraft |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Disabled on ground |

#### Gun (Slow)
> Slow-firing gun vibration (heavy cannons).

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `gunShellsCount`  | Firing detected by count *decrease* |
| `isCannonFireOn`  | Used for specific aircraft types |
| `aircraftTitle`   | Aircraft-specific behavior |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Disabled on ground |

#### Bomb/Fuel Drop
> Impact vibration when ordnance or fuel tanks are released.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `bombsCount`      | Drop detected by count *decrease* |
| `fuelTanksCount`  | Drop detected by count *decrease* |
| `otherItemCount`  | Drop detected by count *decrease* |

#### Missile Launch
> Vibration from missile or rocket launch.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `missilesCount`   | Launch detected by count *decrease* |

#### Flare/Chaff
> Vibration from countermeasure release.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `flareCount`   | Release detected by count *decrease* |

#### Damage
> Impact vibration when the aircraft is hit.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `damage`       | New damage detected by value *increase* (0.0-1.0) |

#### Canopy Jettison
> Explosive vibration when canopy is ejected.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `canopyJettison`  | Triggers on `false` to `true` transition |

#### Catapult
> Intense vibration during carrier catapult launch.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `accX`           | Catapult detected when longitudinal acceleration exceeds 1.4G |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only while on the deck |

### 6.7 Glider-Specific Effects

#### Tow Disconnect
> Snap vibration when tow rope disconnects.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `isTowConnected`  | Triggers on `true` to `false` transition |

#### Wingtip Strike
> Impact when a wingtip touches the ground.

| Required Field | Why It's Needed |
|----------------|-----------------|
| `wingSpanM`      | Wing span in meters (geometry calculation) |
| `acRoll`         | Roll angle determines if wingtip reaches ground |
| `agl`            | Ground proximity check |
| `gearFrontOnGround`, `gearLeftOnGround`, `gearRightOnGround` | Only while on the ground |

### 6.8 Helicopter-Specific Effects

#### VRS (Vortex Ring State)
> Dangerous condition where rotor descends into its own downwash.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `ias`             | Low airspeed is a VRS factor |
| `verticalSpeed`   | Descent rate is primary VRS indicator |
| `collective`      | Collective position affects VRS onset |
| `densityAltFt`    | Higher density altitude worsens VRS |
| `totalWeight`     | Heavier aircraft more susceptible |
| `maxGrossWeight`  | Weight normalization reference |
| `rotor1RpmNorm`   | Rotor RPM factor |

#### ETL (Effective Translational Lift)
> Shudder during transition from hover to forward flight (~16-24 knots).

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `ias`             | ETL peaks around 19 knots airspeed |
| `densityAltFt`    | Affects ETL characteristics |
| `totalWeight`     | Weight factor for ETL intensity |
| `maxGrossWeight`  | Weight normalization reference |

#### Blade Slapping
> Vibration from helicopter blades in certain flight conditions.

| Required Field    | Why It's Needed |
|-------------------|-----------------|
| `gforce`          | G-force loading on rotor |
| `verticalSpeed`   | Descent rate factor |
| `ias`             | Forward speed factor |
| `acPitch`         | Pitch attitude factor |
| `acRoll`          | Bank angle factor |
| `agl`             | Ground proximity factor |

---

## 7. Best Practices

### Update Rate

- **Target 20-60 Hz** (20-60 packets per second). This matches the rate used by natively supported simulators.
- **Minimum 10 Hz** for acceptable effect quality.
- **Maximum ~100 Hz**. Sending faster than this wastes bandwidth with no benefit.
- Keep the rate **consistent**. Sudden rate changes can cause effects to spike or drop.

### Data Quality

- **Send smooth data.** Avoid sending noisy/jittery raw sensor data. Apply basic smoothing or filtering before sending. This is especially important for `bodyAccelerationY`, `gforce`, and `engine1Speed` – `engine4Speed`.
- **Be consistent with units.** SimHaptic expects the exact units listed in the field reference. Sending meters instead of feet for AGL, for example, will cause incorrect effect behavior.
- **Keep ordnance counters accurate.** SimHaptic detects events by monitoring *changes* in count values. If your count jumps erratically, false triggers will occur.
- **Update gear ground contact promptly.** Many effects depend on `gearFrontOnGround` / `gearLeftOnGround` / `gearRightOnGround`. A delayed ground detection will cause the touchdown effect to miss.

### Packet Size

- Keep packets under **4096 bytes**. This is the receive buffer size.
- In practice, a full packet with all fields is well under 2000 bytes, so this should not be a concern.
- You do not need to send all fields in every packet. Only send fields whose values have changed, plus the required fields (`sh`, `aircraftTitle`). However, sending all fields every frame is simpler and perfectly fine within the buffer limit.

### Aircraft Changes

- When the user loads a different aircraft in your simulator, change the `aircraftTitle` field.
- SimHaptic will detect the change and reload effect profiles.
- Do not change `aircraftTitle` every frame or during normal flight. Only change it when the actual aircraft changes.

### Field Persistence

- SimHaptic retains the last received value for each field. If you stop sending a field, it keeps its last value (it does NOT reset to default).
- If you want to explicitly reset a field (e.g., stop firing guns), send the field with its zero/false value.

### Pause State

- **Explicit pause**: Set `isPaused` to `true` in your packets to pause SimHaptic while keeping the connection alive. SimHaptic will show "Paused" and stop all effects. Set it back to `false` (or omit it) to resume.
- **Implicit pause (timeout)**: If no packets arrive for more than **1 second**, SimHaptic automatically enters the paused state.
- **Recommendation**: Use `isPaused` for clean pause/unpause transitions. This avoids the 1-second timeout delay and gives your users instant pause feedback.

### Graceful Disconnection

- SimHaptic considers the connection lost after **1 second** of no packets.
- When your simulator exits, simply stop sending packets. SimHaptic will show "Waiting..." after 1 second.
- When you resume, start sending packets again. Reconnection is automatic.

---

## 8. Connection Verification (Ping/Pong)

Since UDP provides no delivery confirmation, your simulator has no way to know whether SimHaptic is actually running and receiving packets. The ping/pong mechanism solves this.

### How It Works

Send a **ping** packet to SimHaptic. If SimHaptic is running and listening, it immediately responds with a **pong** packet back to your sender address and port.

No pong received? SimHaptic is not running, the port is wrong, or a firewall is blocking traffic.

### Ping Packet Format

Send a JSON packet with `type` set to `"ping"`:

```json
{"sh": 1, "type": "ping"}
```

That's it. No other fields are needed. The `sh` field is required (same as telemetry packets).

Ping packets are **not** treated as telemetry. They do not affect connection state, effect processing, or aircraft detection in SimHaptic.

### Pong Response Format

SimHaptic responds with:

```json
{
  "sh": 1,
  "type": "pong",
  "version": "2.2.2",
  "packetsReceived": 87432,
  "parseErrors": 3,
  "connectedAircraft": "F-16C"
}
```

| Field               | Type   | Description |
|---------------------|--------|-------------|
| `sh`                | int    | Protocol version (always `1`). |
| `type`              | string | Always `"pong"`. |
| `version`           | string | SimHaptic application version. |
| `packetsReceived`   | int    | Total telemetry packets successfully processed since SimHaptic started listening. |
| `parseErrors`       | int    | Total malformed packets received (JSON parse failures). |
| `connectedAircraft` | string | Currently connected aircraft title (empty string if none). |

The pong is sent back to the **exact address and port** that the ping came from (as reported by the OS from the received UDP datagram).

### Sequence Diagram

```
    Simulator                          SimHaptic
       │                                  │
       │   {"sh":1,"type":"ping"}         │
       │ ─────────────────────────────►   │
       │                                  │
       │   {"sh":1,"type":"pong",...}     │
       │ ◄─────────────────────────────   │
       │                                  │
       │   (ping confirmed, start         │
       │    sending telemetry)            │
       │                                  │
       │   {"sh":1,"aircraftTitle":...}   │
       │ ─────────────────────────────►   │
       │   {"sh":1,"aircraftTitle":...}   │
       │ ─────────────────────────────►   │
       │   {"sh":1,"aircraftTitle":...}   │
       │ ─────────────────────────────►   │
       │           ...                    │
       │                                  │
       │   (periodic health check)        │
       │                                  │
       │   {"sh":1,"type":"ping"}         │
       │ ─────────────────────────────►   │
       │                                  │
       │   {"sh":1,"type":"pong",...}     │
       │ ◄─────────────────────────────   │
       │                                  │
       │   (SimHaptic still alive, good)  │
       │                                  │
```

### Recommended Sender Pattern

> **Note:** This is a suggested approach. You are free to implement your own strategy based on your simulator's needs.

Use ping/pong to avoid sending telemetry into the void at full rate when SimHaptic is unreachable:

```
┌──────────────┐     ping, no pong      ┌──────────────┐
│              │ ───────────────────►   │              │
│  PROBING     │     (every ~10s)       │   CONNECTED  │
│              │ ◄───────────────────   │              │
│  Send ping   │     pong received      │  Send telem  │
│  every ~10s  │ ───────────────────►   │ at full rate │
│              │                        │              │
└──────┬───────┘                        └──────┬───────┘
       │                                       │
       │  pong received                        │  no pong for ~5s
       │                                       │
       ▼                                       ▼
┌──────────────┐                        ┌──────────────┐
│  CONNECTED   │                        │  PROBING     │
└──────────────┘                        └──────────────┘
```

**PROBING** (SimHaptic not yet confirmed):
- Send a ping every ~10 seconds
- Do **not** send telemetry at full rate
- On pong received: transition to CONNECTED

**CONNECTED** (SimHaptic confirmed alive):
- Send telemetry at full rate (20-60 Hz)
- Periodically send a ping (e.g., every ~5 seconds) as a health check
- If no pong comes back for ~5 seconds: transition back to PROBING

---

## 9. Troubleshooting

### SimHaptic shows "Waiting..." (red dot)

- Verify "External UDP" is selected in the simulator dropdown.
- Check that your simulator is sending to the correct port (default `19872`).
- If running on the same machine, send to `127.0.0.1` (localhost). If running on a different machine on your LAN, send to the LAN IP of the PC running SimHaptic.
- Verify your JSON is valid. A malformed JSON packet is silently discarded.
- Check firewall settings - ensure inbound UDP traffic on the configured port is allowed. This is especially important for LAN setups where Windows Firewall may block traffic from other machines by default.

### Connected but no effects

- Ensure at least one engine is running (`engine1Running` through `engine4Running`) — required for most effects.
- Check that `aircraftTitle` is not empty.
- Verify that the required fields for the effects you expect are being sent (see Section 6).
- Check that values are in the correct units and ranges.

### Effects are too intense or too weak

- Review the unit expectations. For example, `verticalSpeed` is in feet/min, not m/s.
- `engine1Speed` – `engine4Speed` should be 0-100 (percentage), not raw RPM.
- All position fields (flaps, gear, etc.) should be 0.0-1.0, not 0-100.

### Effects trigger unexpectedly

- Check for noisy data in `bodyAccelerationY`, `gforce`, or `accX`. Apply smoothing.
- Ensure ordnance counts don't fluctuate. Each fluctuation triggers a weapon event.
- Verify `gearFrontOnGround` / `gearLeftOnGround` / `gearRightOnGround` aren't toggling rapidly near the ground.

### Touchdown effect doesn't fire

- SimHaptic requires a transition: at least one gear on-ground boolean (`gearFrontOnGround`, `gearLeftOnGround`, or `gearRightOnGround`) must go from `false` to `true`.
- `verticalSpeed` must be negative (descending) at the moment of touchdown.
- `surfaceType` must not be `"Water"`.
- The aircraft must have been in the air for a meaningful duration before landing.

### Not receiving pong responses

- Ensure SimHaptic is running with "External UDP" selected.
- Check that your ping packet includes `"sh": 1` — it is required.
- Verify you are sending to the correct IP and port.
- Make sure your UDP socket is bound to a port so SimHaptic can send the pong back. If you use an ephemeral (OS-assigned) port, that's fine — SimHaptic replies to whatever source address/port the OS reports.
- Check firewall settings — the pong travels in the reverse direction, which some firewalls may block if they don't track UDP "connections."

### JSON parse errors in SimHaptic log

- Ensure your JSON is properly formatted. Common issues:
  - Trailing commas (not valid JSON)
  - Single quotes instead of double quotes
  - Unescaped special characters in `aircraftTitle`
  - NaN or Infinity float values (not valid JSON - send `0.0` instead)

---

## Appendix A: Ping Packet Template

```json
{"sh": 1, "type": "ping"}
```

## Appendix B: Complete Telemetry Packet Template

Here is a template with every possible field and its default value. Copy this as a starting point and remove fields you don't need:

```json
{
  "sh": 1,
  "aircraftTitle": "",
  "acType": "piston",
  "engineType": "Piston",
  "surfaceType": "Hard",

  "batteryState": false,
  "hasRetractableGear": false,
  "hasFloats": false,
  "isParkingBrakeSet": false,
  "isFuelPumpOn": false,
  "isTowConnected": false,
  "canopyJettison": false,
  "isCannonFireOn": false,
  "isAutoFlapsOn": false,
  "isPaused": false,
  "isInCockpit": true,

  "agl": 0.0,
  "ias": 0.0,
  "groundSpeed": 0.0,
  "vso": 0.0,
  "vne": 0.0,
  "gforce": 0.0,
  "verticalSpeed": 0.0,
  "stallPercentage": 0.0,
  "windshieldWindVelocity": 0.0,
  "densityAltFt": 0.0,

  "acPitch": 0.0,
  "acRoll": 0.0,
  "relativeYaw": 0.0,
  "accX": 0.0,
  "bodyAccelerationY": 0.0,

  "gearFrontPosition": 0.0,
  "gearLeftPosition": 0.0,
  "gearRightPosition": 0.0,
  "gearFrontOnGround": false,
  "gearLeftOnGround": false,
  "gearRightOnGround": false,

  "flapsPosition": 0.0,
  "spoilersPosition": 0.0,
  "brakes": 0.0,
  "doorPos": 0.0,
  "hookPos": 0.0,
  "wingPos": 0.0,
  "fuelProbePos": 0.0,
  "dragChute": 0.0,

  "yokeX": 0.0,
  "yokeY": 0.0,

  "engine1Speed": 0.0,
  "engine2Speed": 0.0,
  "engine3Speed": 0.0,
  "engine4Speed": 0.0,
  "engine1Running": false,
  "engine2Running": false,
  "engine3Running": false,
  "engine4Running": false,
  "engine1StarterOn": false,
  "engine2StarterOn": false,
  "engine3StarterOn": false,
  "engine4StarterOn": false,
  "engine1AfterburnerRatio": 0.0,
  "engine2AfterburnerRatio": 0.0,
  "engine3AfterburnerRatio": 0.0,
  "engine4AfterburnerRatio": 0.0,
  "engine1ReverseThrust": 0.0,
  "engine2ReverseThrust": 0.0,
  "engine3ReverseThrust": 0.0,
  "engine4ReverseThrust": 0.0,
  "apu": 0.0,

  "emptyWeight": 0.0,
  "totalWeight": 0.0,
  "maxGrossWeight": 0.0,
  "wingSpanM": 0.0,

  "collective": 0.0,
  "rotor1RpmNorm": 0.0,
  "rotor2RpmNorm": 0.0,

  "gunShellsCount": 0,
  "bombsCount": 0,
  "fuelTanksCount": 0,
  "otherItemCount": 0,
  "missilesCount": 0,
  "flareCount": 0,

  "damage": 0.0
}
```

---

## Appendix C: Effect Availability Summary

Quick reference showing which effects activate based on aircraft type:

| Effect | All Types | Helicopter | Glider | Military | Notes |
|--------|-----------|------------|--------|----------|-------|
| Engine vibrations | Yes | Yes | - | Yes | |
| Touchdown | Yes | Yes | Yes | Yes | |
| Ground roll | Yes | Yes | Yes | Yes | Hard surfaces only |
| Ground bumps | Yes | Yes | Yes | Yes | Hard surfaces only |
| Grass roll | Yes | Yes | Yes | Yes | Soft surfaces only |
| G-force | Yes | Yes | Yes | Yes | |
| Stall | Yes | - | Yes | Yes | |
| Flaps movement | Yes | - | Yes | Yes | |
| Flaps drag | Yes | - | Yes | Yes | |
| Gear up/down | Yes | - | - | Yes | Needs retractable gear |
| Gear drag | Yes | - | - | Yes | Needs retractable gear |
| Overspeed | Yes | - | Yes | - | |
| Air brake drag | Yes | - | - | Yes | |
| Air brake movement | - | - | - | Yes | |
| Turbulence | Yes | Yes | Yes | - | |
| Brakes | Yes | Yes | Yes | Yes | |
| Parking brake | Yes | Yes | Yes | Yes | |
| Reverse thrust | Yes | - | - | Yes | Jets only |
| Afterburner | - | - | - | Yes | Military jets |
| Engine rumble | Yes | Yes | - | Yes | |
| Engine start | Yes | - | - | Yes | Piston engines |
| Engine stop | Yes | - | - | - | Piston engines |
| Avionics | Yes | Yes | - | Yes | |
| Fuel pump | Yes | - | - | - | |
| APU | - | - | - | Yes | |
| Door open/close | Yes | - | - | Yes | |
| Controls deflection | Yes | - | - | - | |
| Airframe airflow | Yes | Yes | Yes | Yes | |
| Glider wind | - | - | Yes | - | |
| Tow disconnect | - | - | Yes | - | |
| Wingtip strike | - | - | Yes | - | |
| Blade slapping | - | Yes | - | - | |
| VRS | - | Yes | - | - | |
| ETL | - | Yes | - | - | |
| Gun (fast) | - | - | - | Yes | |
| Gun (slow) | - | - | - | Yes | |
| Bomb/fuel drop | - | - | - | Yes | |
| Missile launch | - | - | - | Yes | |
| Flare/chaff | - | - | - | Yes | |
| Damage | - | - | - | Yes | |
| Canopy jettison | - | - | - | Yes | |
| Catapult | - | - | - | Yes | |
| Drag chute | - | - | - | Yes | |
| Hook up/down | - | - | - | Yes | |
| Wing fold/sweep | - | - | - | Yes | |
| Fuel probe | - | - | - | Yes | |

---

## Appendix D: Units Quick Reference

| Quantity | Unit | Example |
|----------|------|---------|
| Altitude (AGL) | feet | `3500.0` = 3500 ft |
| Airspeed (IAS) | knots | `250.0` = 250 kts |
| Ground speed | knots | `240.0` = 240 kts |
| Vertical speed | feet/min | `-700.0` = 700 fpm descent |
| G-force | G | `1.0` = level flight, `4.0` = 4G pull |
| Angles (pitch, roll) | degrees | `15.0` = 15 degrees |
| Accelerations | G | `0.5` = 0.5G lateral |
| Positions (flaps, gear, etc.) | 0.0 - 1.0 | `0.5` = 50% extended |
| Control inputs (yoke) | -1.0 - 1.0 | `-0.3` = 30% left |
| Engine speed | % (0-100) | `85.0` = 85% N1/RPM |
| Weight | lbs | `16000.0` = 16,000 lbs |
| Wing span | meters | `17.0` = 17m span |
| Density altitude | feet | `2500.0` = 2,500 ft DA |
| Damage | 0.0 - 1.0 | `0.3` = 30% damaged |