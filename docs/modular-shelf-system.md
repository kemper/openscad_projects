# Modular Shelf System — Design Knowledge

## Overview

A modular shelf system made of 3D-printed (FDM) pieces that connect together without glue or hardware. Each shelf unit is a hollow cuboid (rectangular tube) with open front and back faces. Units connect via dovetail track-and-strip connectors that are invisible from the front when assembled.

## Files

- `src/shelf.scad` — The shelf unit, smooth exterior (parametric)
- `src/shelf_ribbed.scad` — Ribbed texture variant (imports shelf.scad via `use`)
- `src/shelf_connector.scad` — The connector strip that joins two shelf units

## Shelf Unit Shape

The shelf is a hollow rectangular tube: a rounded-rectangle cross-section extruded along the depth axis. Front and back faces are fully open.

**How it's built in OpenSCAD:**
1. A 2D rounded rectangle is created using `offset(r)` on a smaller square
2. A second, smaller rounded rectangle (inset by wall thickness) is subtracted to create the hollow profile
3. The 2D profile is `linear_extrude`d along the depth (Z axis)
4. Dovetail track grooves are subtracted from the outer walls

**Key design choice:** Both the inner and outer rounded corners use the same radius value. This was a deliberate requirement — the interior rounding matches the exterior rounding.

**Orientation in OpenSCAD:** The cross-section sits in the XY plane (centered at origin), and depth runs along the Z axis. When printed, the shelf would typically lay with one open face on the build plate.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `width` | 125mm | Left to right |
| `height` | 125mm | Top to bottom |
| `depth` | 120mm | Front to back (the open axis) |
| `wall` | 4mm | Wall thickness |
| `radius` | 20mm | Corner rounding radius |
| `track_width` | 10mm | Width of dovetail groove at wall surface |
| `track_depth` | 2mm | How deep groove cuts into wall |
| `track_length_pct` | 75 | % of depth covered by track (from back) |
| `dovetail_angle` | 15° | Angle from vertical — controls lock strength |
| `tracks_top` | 1 | Number of tracks on top wall |
| `tracks_bottom` | 1 | Number of tracks on bottom wall |
| `tracks_left` | 1 | Number of tracks on left wall |
| `tracks_right` | 1 | Number of tracks on right wall |

## Connector System

### Problem Solved

Shelf units need to be joined together (side-by-side, stacked, or both) with connectors that are strong, require no glue/hardware, and are invisible from the front when assembled.

### How It Works

1. Each shelf wall can have dovetail-shaped grooves (tracks) cut into its outer surface
2. Tracks run along the depth axis, starting from the back edge and covering 75% of the depth — they stop before the front face, hiding the joint
3. When two shelf units are placed together (e.g., stacked), their tracks align back-to-back
4. A connector strip slides into the combined channel from the back and is tapped in
5. The dovetail profile mechanically prevents pull-apart — no glue needed

### Track Cross-Section (Dovetail)

```
     wall surface (narrow opening)
    ┌──────────┐  ← track_width
     \        /
      \      /     ← dovetail_angle from vertical
       \    /
    ┌──────────────┐  ← track_width + 2 * track_depth * tan(angle)
        deeper in wall
```

The groove is trapezoidal: narrow at the wall surface, wider deeper in. This prevents the connector from pulling straight out.

### Connector Strip Cross-Section (Bowtie)

```
    ┌──────────────┐  wide (locks into shelf A's groove)
     \            /
      \          /
       ┤ narrow ├    ← pinch at the joint between shelves
      /          \
     /            \
    └──────────────┘  wide (locks into shelf B's groove)
```

A 6-point polygon forming an hourglass/bowtie shape. Each wide end locks into one shelf's dovetail, the narrow center sits at the joint between the two shelves.

### FDM Tolerances

The connector strip dimensions include 0.2mm clearance per side to account for FDM printing variance. This is controlled by the `clearance` parameter in `shelf_connector.scad`. If prints are too tight or too loose, adjust this value.

### Connector Strip Dimensions (derived)

- Width (at narrow center): `track_width - 2 * clearance` = 9.6mm
- Width (at wide edges): narrow + `2 * track_depth * tan(dovetail_angle)` ≈ 10.67mm
- Thickness: `2 * track_depth - 2 * clearance` = 3.6mm
- Length: `track_length - 1mm` = 89mm (1mm shorter for easy insertion)

## Multi-Track Support (Rectangular Shelves)

Shelf units can be any width/height — not just square. Each wall independently takes an integer track count (0 = no tracks). Tracks are automatically evenly spaced.

**Example:** A 250mm x 125mm shelf with `tracks_top = 2` places two tracks on the top wall, each centered at 62.5mm and 187.5mm from the left edge. This aligns exactly with two 125mm-wide shelves sitting on top.

**Track positioning formula:** For track `i` of `n` on a wall of length `L`:
```
position_i = -L/2 + (L/n) * (i + 0.5)
```

This evenly divides the wall into `n` segments and centers one track in each segment.

## Design Decisions and Rationale

### Why dovetail instead of rectangular tracks?
Rectangular tracks only hold via friction — pieces can pull apart easily. The dovetail provides mechanical interlock perpendicular to the sliding direction.

### Why 15° dovetail angle?
At 15° with 2mm track depth, each side widens ~0.54mm at the base. This provides meaningful mechanical lock while keeping the angle gentle enough for clean FDM printing without supports. Increase for stronger lock (harder to insert), decrease for easier sliding.

### Why 75% track length?
The track starts at the back and covers 75% of the depth. The remaining 25% at the front is track-free, ensuring the connector is completely hidden when viewing the shelf from the front. This also leaves solid wall at the front edge for structural strength.

### Why 2mm track depth on a 4mm wall?
Cutting halfway into the wall balances connector strength with wall integrity. Going deeper would weaken the wall; going shallower would make the dovetail too subtle to lock effectively.

### Why a separate connector strip (not integrated tongue-and-groove)?
A separate strip allows any wall to connect to any other wall — you're not locked into matching male/female sides. This maximizes modularity: the same shelf piece works anywhere in the grid.

### Why explicit polygon coordinates (not rotate/mirror)?
The track groove modules use direct polygon coordinates for each wall direction rather than rotating/mirroring a single base shape. This is more verbose but much easier to reason about and debug — rotation/mirror chains in OpenSCAD are error-prone, especially when the dovetail direction matters.

## Overriding Parameters via CLI

OpenSCAD supports parameter overrides from the command line using `-D`:

```bash
# Build a 250x125 shelf with 2 tracks top/bottom, none on sides
openscad -o dist/shelf_wide.stl -D 'width=250' -D 'tracks_top=2' -D 'tracks_bottom=2' -D 'tracks_left=0' -D 'tracks_right=0' src/shelf.scad
```

## Texture System

### Architecture

Texture variants are separate `.scad` files that import the base `shelf.scad` via `use <shelf.scad>`. This means:
- `shelf.scad` is the smooth variant and the single source of truth for shelf geometry and track logic
- Texture files call `shelf()` from shelf.scad, then subtract texture geometry from the result
- The top-level `shelf();` call in shelf.scad is NOT executed when imported via `use` (only modules are imported)
- Texture files redeclare shelf/track parameters (same defaults) — these are used only for texture placement calculations
- CLI `-D` overrides are global and affect both the imported shelf.scad and the texture file, so overrides stay in sync

### Adding a New Texture Variant

1. Create `src/shelf_<name>.scad`
2. Add `use <shelf.scad>` at the top
3. Redeclare shelf and track parameters (copy from shelf.scad, same defaults)
4. Add texture-specific parameters
5. Create a module that calls `shelf()` inside a `difference()` and subtracts the texture geometry
6. Texture geometry must avoid track zones — use `is_clear()` function pattern (see shelf_ribbed.scad)

### Ribbed Texture (`shelf_ribbed.scad`)

Semicircular grooves carved into the exterior walls, running along the depth axis (front-to-back).

**How it works:**
- Cylinders are placed at each outer wall surface, running the full depth along Z
- `difference()` subtracts them from the shelf, creating semicircular channels
- Grooves are centered on the flat portion of each wall (avoiding rounded corners)
- Grooves near dovetail tracks are automatically skipped

**Groove parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `groove_radius` | 1mm | Radius of semicircular groove (controls depth and width) |
| `groove_spacing` | 4mm | Center-to-center distance between grooves |
| `groove_margin` | 2mm | Min clearance between groove edge and track edge |

**Track avoidance logic:** A groove at position `p` is skipped if any track center `t` satisfies:
```
abs(p - t) < track_width/2 + groove_margin + groove_radius
```

**Flat zone calculation:** Grooves are only placed on the flat portions of each wall (between the rounded corners). For a horizontal wall, grooves span from `x = -width/2 + radius` to `x = width/2 - radius`, with the pattern centered within that zone.

**FDM printing note:** Subtractive grooves (carved into the surface) were chosen over additive ribs (raised above the surface) because they print more reliably on FDM — no thin features that can break or warp.

## Shared Parameters Warning

`shelf_connector.scad` and `shelf_ribbed.scad` both duplicate parameters from `shelf.scad`. If you change default values in one file, you **must** update them in all files, or the parts won't fit together. These are intentionally not shared via `include` to keep each file independently buildable. CLI `-D` overrides are global and keep everything in sync automatically.
