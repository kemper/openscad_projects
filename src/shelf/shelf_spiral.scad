// Spiral Wrap Shelf Variant
// Diagonal groove channels wrapping continuously around the shelf like thread on a spool.
// The spiral advances in Z as it goes counterclockwise around the perimeter (viewed from back).
// Corners use staircase-helix approximation so the grooves wrap through the rounded edges.
// Units: millimeters

use <shelf.scad>

// --- Shelf Parameters (must match shelf.scad) ---
width  = 125;
height = 125;
depth  = 120;
wall   = 4;
radius = 20;

// --- Track Parameters (must match shelf.scad) ---
track_width      = 10;
track_depth      = 2;
track_length_pct = 75;
dovetail_angle   = 25;
tracks_top       = 1;
tracks_bottom    = 1;
tracks_left      = 0;
tracks_right     = 0;

// --- Spiral Parameters ---
spiral_angle = 30;      // degrees from horizontal
strand_width = 6;       // width of each strand between grooves
gap          = 1;       // groove width
gap_depth    = 1.5;     // how deep grooves cut into wall
style_margin = 2;       // clearance around track zones
corner_steps = 12;      // arc segments per corner channel (more = smoother helix)

$fn = 180;

pitch   = strand_width + gap;
hw      = width / 2;
hh      = height / 2;
tz_half = track_width / 2 + style_margin;

// Derived corner geometry
arc_len       = PI * radius / 2;
z_per_d       = pitch / cos(spiral_angle);    // Z spacing between channels
z_advance_corner = arc_len * tan(spiral_angle); // Z gained traversing one corner

// --- Track zone computation (same as shelf_woven.scad) ---
function track_zone_bounds(count, wall_len) =
    [for (i = [0 : count - 1])
        let(seg = wall_len / count,
            c = -wall_len / 2 + seg * (i + 0.5))
        [c - tz_half, c + tz_half]
    ];

function free_segments(count, wall_len) =
    let(fs = -wall_len / 2 + radius,
        fe = wall_len / 2 - radius)
    count == 0 ? [[fs, fe]] :
    let(z = track_zone_bounds(count, wall_len),
        first = fs < z[0][0] - 0.5 ? [[fs, z[0][0]]] : [],
        middle = count < 2 ? [] :
            [for (i = [0 : count - 2])
                if (z[i][1] < z[i + 1][0] - 0.5)
                    [z[i][1], z[i + 1][0]]
            ],
        last = z[count - 1][1] < fe - 0.5 ? [[z[count - 1][1], fe]] : []
    )
    concat(first, middle, last);

// Diagonal channels on a horizontal wall (top or bottom)
module spiral_h(wall_y, track_count, angle_sign) {
    segs = free_segments(track_count, width);

    for (seg = segs) {
        seg_start = seg[0];
        seg_end   = seg[1];
        seg_width = seg_end - seg_start;
        seg_cx    = (seg_start + seg_end) / 2;

        channel_len = seg_width / cos(spiral_angle) + 1;
        z_shift = seg_width * tan(spiral_angle);

        i_min = floor(-z_shift / z_per_d) - 1;
        i_max = ceil(depth / z_per_d) + 1;

        for (i = [i_min : i_max]) {
            z0 = i * z_per_d;
            cz = z0 + (seg_width / 2) * tan(spiral_angle);

            translate([seg_cx,
                       wall_y > 0 ? wall_y - gap_depth : wall_y - 1,
                       cz])
                rotate([0, angle_sign * spiral_angle, 0])
                    translate([-channel_len / 2, 0, -gap / 2])
                        cube([channel_len, gap_depth + 1, gap]);
        }
    }
}

// Diagonal channels on a vertical wall (left or right)
module spiral_v(wall_x, track_count, angle_sign) {
    segs = free_segments(track_count, height);

    for (seg = segs) {
        seg_start = seg[0];
        seg_end   = seg[1];
        seg_height = seg_end - seg_start;
        seg_cy    = (seg_start + seg_end) / 2;

        channel_len = seg_height / cos(spiral_angle) + 1;

        i_min = floor(-seg_height * tan(spiral_angle) / z_per_d) - 1;
        i_max = ceil(depth / z_per_d) + 1;

        for (i = [i_min : i_max]) {
            z0 = i * z_per_d;
            cz = z0 + (seg_height / 2) * tan(spiral_angle);

            translate([wall_x > 0 ? wall_x - gap_depth : wall_x - 1,
                       seg_cy,
                       cz])
                rotate([angle_sign * spiral_angle, 0, 0])
                    translate([0, -channel_len / 2, -gap / 2])
                        cube([gap_depth + 1, channel_len, gap]);
        }
    }
}

// Helical channels on a corner — staircase approximation
// Each channel is broken into corner_steps arc segments at progressively advancing Z.
module spiral_corner(cx, cy, start_angle) {
    step_angle    = 90 / corner_steps;
    dz_per_step   = z_advance_corner / corner_steps;
    groove_z      = max(gap, dz_per_step);  // extend to cover Z rise per step

    n_channels = ceil((depth + z_advance_corner) / z_per_d) + 2;

    for (ch = [0 : n_channels - 1]) {
        z_base = ch * z_per_d - z_advance_corner;

        for (s = [0 : corner_steps - 1]) {
            z = z_base + s * dz_per_step;

            if (z > -groove_z && z < depth) {
                translate([cx, cy, max(0, min(z, depth - groove_z))])
                    rotate([0, 0, start_angle + s * step_angle])
                        rotate_extrude(angle = step_angle + 0.5)
                            translate([radius - gap_depth, 0, 0])
                                square([gap_depth + 1, groove_z]);
            }
        }
    }
}

module spiral_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);

        // Flat walls — angle signs create continuous counterclockwise spiral:
        // Right wall:  Z increases upward (Y+)
        // Top wall:    Z increases leftward (X-)
        // Left wall:   Z increases downward (Y-)
        // Bottom wall: Z increases rightward (X+)
        spiral_h(hh, tracks_top, -1);       // top wall
        spiral_h(-hh, tracks_bottom, 1);    // bottom wall
        spiral_v(hw, tracks_right, 1);      // right wall
        spiral_v(-hw, tracks_left, -1);     // left wall

        // Corner helixes (continuous wrap)
        spiral_corner(hw - radius, -hh + radius, -90);  // bottom-right
        spiral_corner(hw - radius,  hh - radius,   0);  // top-right
        spiral_corner(-hw + radius,  hh - radius,  90); // top-left
        spiral_corner(-hw + radius, -hh + radius, 180); // bottom-left

        // Track grooves
        horizontal_tracks(tracks_top, width, hh, -1);
        horizontal_tracks(tracks_bottom, width, -hh, 1);
        vertical_tracks(tracks_right, height, hw, -1);
        vertical_tracks(tracks_left, height, -hw, 1);
    }
}

spiral_shelf();
