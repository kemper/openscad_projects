"""
Organic root/branch pattern generator.

Uses recursive branching with:
- Smooth cubic Bezier splines through waypoints (not straight segments)
- Perlin-like noise for organic undulation
- Progressive tapering from trunk to fine tendrils
- Randomized branching angles, lengths, and curvature

Usage:
    python root_generator.py [--seed N] [--width W] [--height H] [-o output.svg]
"""

import argparse
import math
import random
from dataclasses import dataclass, field

import svgwrite


@dataclass
class BranchConfig:
    """Tunable parameters for the branching algorithm."""
    # Canvas
    width: float = 500
    height: float = 600

    # Trunk
    trunk_width: float = 22.0
    trunk_start_y: float = 650  # starts below canvas for full coverage
    trunk_length: float = 300

    # Branching
    max_depth: int = 6
    children_range: tuple = (2, 3)  # min/max children per branch
    branch_angle_range: tuple = (20, 50)  # degrees from parent direction
    branch_length_factor: tuple = (0.6, 0.9)  # child length relative to parent
    taper_factor: float = 0.6  # width multiplier per depth level

    # Curvature / organic feel
    waypoints_per_branch: int = 12  # more = smoother curves
    undulation_amplitude: float = 0.08  # lateral wobble as fraction of length
    undulation_frequency: float = 1.5  # number of wobbles per branch

    # Variation
    angle_jitter: float = 15  # random angle variation in degrees
    length_jitter: float = 0.2  # random length variation as fraction

    # Pruning
    min_width: float = 0.6  # stop branching below this stroke width
    min_length: float = 8  # stop branching below this length

    # Style
    color: str = "#c8944a"
    bg_color: str = "#1a1a1a"


@dataclass
class Branch:
    """A single branch with its waypoints and children."""
    waypoints: list  # list of (x, y) tuples
    width_start: float
    width_end: float
    depth: int
    children: list = field(default_factory=list)


def noise_1d(t, seed=0):
    """Smooth pseudo-noise using low-frequency sine harmonics."""
    # Use few, low-frequency harmonics for gentle organic undulation
    val = (
        math.sin(t * 1.8 + seed * 7.3) * 0.6
        + math.sin(t * 3.1 + seed * 2.1) * 0.3
        + math.sin(t * 5.7 + seed * 11.4) * 0.1
    )
    return val


def generate_branch_waypoints(start_x, start_y, angle, length, config, rng, depth):
    """Generate smooth waypoints along a branch with organic undulation."""
    n = config.waypoints_per_branch
    waypoints = []

    # Direction vector
    dx = math.cos(angle)
    dy = math.sin(angle)

    # Perpendicular vector for undulation
    px = -dy
    py = dx

    # Random seed for this branch's noise
    noise_seed = rng.random() * 100

    for i in range(n + 1):
        t = i / n

        # Base position along branch
        x = start_x + dx * length * t
        y = start_y + dy * length * t

        # Organic undulation (sinuous S-curves)
        # Amplitude increases toward middle, zero at endpoints
        envelope = math.sin(t * math.pi)  # 0 at start/end, 1 at middle
        wobble = noise_1d(t * config.undulation_frequency, noise_seed)
        amp = config.undulation_amplitude * length * envelope

        x += px * wobble * amp
        y += py * wobble * amp

        # Slight gravitational curve for branches (subtle droop/lift)
        if depth > 0:
            gravity = 0.05 * length * t * t
            # Branches going up get slight outward curve
            y -= gravity * 0.3

        waypoints.append((x, y))

    return waypoints


def waypoints_to_smooth_svg_path(waypoints):
    """Convert waypoints to a smooth SVG path using cubic Bezier curves.

    Uses Catmull-Rom to Bezier conversion for smooth interpolation
    through all waypoints.
    """
    if len(waypoints) < 2:
        return ""

    n = len(waypoints)

    # Start path at first point
    parts = [f"M{waypoints[0][0]:.1f},{waypoints[0][1]:.1f}"]

    if n == 2:
        parts.append(f"L{waypoints[1][0]:.1f},{waypoints[1][1]:.1f}")
        return " ".join(parts)

    # Catmull-Rom to cubic Bezier conversion
    # For each segment between waypoints[i] and waypoints[i+1],
    # we need waypoints[i-1] and waypoints[i+2] for tangent computation
    tension = 0.45  # controls curve smoothness through waypoints

    for i in range(n - 1):
        p0 = waypoints[max(i - 1, 0)]
        p1 = waypoints[i]
        p2 = waypoints[min(i + 1, n - 1)]
        p3 = waypoints[min(i + 2, n - 1)]

        # Catmull-Rom tangents
        t1x = (p2[0] - p0[0]) * tension
        t1y = (p2[1] - p0[1]) * tension
        t2x = (p3[0] - p1[0]) * tension
        t2y = (p3[1] - p1[1]) * tension

        # Convert to cubic Bezier control points
        cp1x = p1[0] + t1x / 3
        cp1y = p1[1] + t1y / 3
        cp2x = p2[0] - t2x / 3
        cp2y = p2[1] - t2y / 3

        parts.append(
            f"C{cp1x:.1f},{cp1y:.1f} {cp2x:.1f},{cp2y:.1f} {p2[0]:.1f},{p2[1]:.1f}"
        )

    return " ".join(parts)


def generate_tree(config, rng):
    """Generate the full branching tree structure."""
    branches = []

    def recurse(start_x, start_y, angle, length, width, depth, side_bias=0):
        if depth > config.max_depth:
            return
        if width < config.min_width:
            return
        if length < config.min_length:
            return

        # Generate waypoints for this branch
        waypoints = generate_branch_waypoints(
            start_x, start_y, angle, length, config, rng, depth
        )

        end_width = width * config.taper_factor
        branch = Branch(
            waypoints=waypoints,
            width_start=width,
            width_end=end_width,
            depth=depth,
        )
        branches.append(branch)

        # End point of this branch
        end_x, end_y = waypoints[-1]

        # Generate children
        n_children = rng.randint(*config.children_range)

        # Build branch points: tip + midpoint branches for density
        branch_points = []

        # Always branch from the tip
        for _ in range(max(1, n_children - 1)):
            branch_points.append((end_x, end_y, 1.0))

        # Branch from midpoints too for denser coverage
        if depth < config.max_depth - 1:
            # Add 1-2 mid-branch spawn points
            n_mid = 1 if depth > 1 else 2
            for _ in range(n_mid):
                t = rng.uniform(0.4, 0.8)
                mid_idx = int(len(waypoints) * t)
                mid_x, mid_y = waypoints[mid_idx]
                branch_points.append((mid_x, mid_y, 0.75))

        # Alternate left/right to ensure spread on both sides
        side = 1
        for i, (bx, by, length_scale) in enumerate(branch_points):
            # Alternate sides, with some randomness
            if i % 2 == 0:
                side = 1
            else:
                side = -1

            # Add randomness to side choice
            if rng.random() < 0.3:
                side = -side

            # Apply side bias from parent to encourage spread
            if side_bias != 0 and rng.random() < 0.6:
                side = side_bias

            base_angle_offset = rng.uniform(
                config.branch_angle_range[0],
                config.branch_angle_range[1],
            )
            base_angle_offset *= side

            # Add jitter
            base_angle_offset += rng.uniform(
                -config.angle_jitter, config.angle_jitter
            )

            child_angle = angle + math.radians(base_angle_offset)

            # Soft bias: gently discourage branches from going straight down
            # but allow all other directions including slightly downward
            # (angle -pi/2 = up, 0 = right, -pi = left, pi/2 = down)
            downward_angle = math.pi / 2
            angle_from_down = abs(child_angle - downward_angle)
            if angle_from_down < 0.4:
                # Push away from straight down
                if child_angle < downward_angle:
                    child_angle -= 0.5
                else:
                    child_angle += 0.5

            # Randomize child length
            length_factor = rng.uniform(*config.branch_length_factor)
            child_length = length * length_factor * length_scale
            child_length *= 1 + rng.uniform(
                -config.length_jitter, config.length_jitter
            )

            child_width = width * config.taper_factor

            recurse(bx, by, child_angle, child_length, child_width,
                    depth + 1, side_bias=side)

    # Start trunk centered, going upward
    start_x = config.width / 2
    trunk_angle = -math.pi / 2 + rng.uniform(-0.05, 0.05)

    # Main trunk
    recurse(
        start_x, config.trunk_start_y,
        trunk_angle, config.trunk_length, config.trunk_width,
        depth=0,
    )

    # Add extra primary branches directly off the trunk at various heights
    # to ensure wide, natural coverage filling the canvas
    n_extra = 8
    for i in range(n_extra):
        # Spawn from various heights along the trunk
        spawn_t = 0.15 + (i / n_extra) * 0.7 + rng.uniform(-0.05, 0.05)
        spawn_y = config.trunk_start_y - config.trunk_length * spawn_t
        spawn_x = start_x + rng.uniform(-8, 8)

        # Alternate sides with varied upward angles
        side = -1 if i % 2 == 0 else 1
        # Each branch goes somewhat upward and outward
        base_up = -math.pi / 2  # straight up
        # Higher branches angle more steeply upward to fill top of canvas
        upward_bias = 0.15 * (i / n_extra)  # steeper for higher branches
        angle_offset = side * rng.uniform(0.3, 1.0) * (1 - upward_bias)
        ea = base_up + angle_offset

        recurse(
            spawn_x, spawn_y,
            ea,
            config.trunk_length * rng.uniform(0.55, 0.85),
            config.trunk_width * rng.uniform(0.4, 0.6),
            depth=1,
            side_bias=side,
        )

    return branches


def render_svg(branches, config, filename):
    """Render branches to SVG with smooth curves and tapering."""
    dwg = svgwrite.Drawing(
        filename,
        size=(f"{config.width}px", f"{config.height}px"),
        viewBox=f"0 0 {config.width} {config.height}",
    )

    # Background
    dwg.add(dwg.rect(
        insert=(0, 0),
        size=(config.width, config.height),
        fill=config.bg_color,
    ))

    # Sort by depth (draw thick branches first, thin on top)
    branches_sorted = sorted(branches, key=lambda b: b.depth)

    for branch in branches_sorted:
        path_d = waypoints_to_smooth_svg_path(branch.waypoints)
        if not path_d:
            continue

        # Average width for this branch (could do variable-width with
        # multiple overlapping paths, but stroke-width is simpler)
        avg_width = (branch.width_start + branch.width_end) / 2

        dwg.add(dwg.path(
            d=path_d,
            stroke=config.color,
            stroke_width=avg_width,
            fill="none",
            stroke_linecap="round",
            stroke_linejoin="round",
        ))

    dwg.save()
    print(f"Saved: {filename}")


def main():
    parser = argparse.ArgumentParser(description="Generate organic root patterns")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    parser.add_argument("--width", type=float, default=500)
    parser.add_argument("--height", type=float, default=600)
    parser.add_argument("-o", "--output", default="tmp/roots_algo.svg")
    parser.add_argument("--max-depth", type=int, default=5)
    parser.add_argument("--trunk-width", type=float, default=18.0)
    parser.add_argument("--undulation", type=float, default=0.25,
                        help="Organic wobble amplitude (0=straight, 0.5=very wavy)")
    args = parser.parse_args()

    config = BranchConfig(
        width=args.width,
        height=args.height,
        max_depth=args.max_depth,
        trunk_width=args.trunk_width,
        undulation_amplitude=args.undulation,
    )

    rng = random.Random(args.seed)
    branches = generate_tree(config, rng)
    render_svg(branches, config, args.output)
    print(f"Generated {len(branches)} branches")


if __name__ == "__main__":
    main()
