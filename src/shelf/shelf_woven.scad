// Woven Basket-Weave Shelf Variant
// Three-layer basket-weave texture on all walls:
//   1. Surface (0mm)      — "over" strands at full wall height
//   2. Weave recess (-1mm) — "under" strands in checkerboard pattern
//   3. Gap channels (-1.5mm) — narrow channels separating strands
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

// --- Weave Parameters ---
strand_width = 6;      // width of each woven strand
gap          = 1;      // visible channel between strands
weave_depth  = 1.0;    // recess depth for "under" crossings
gap_depth    = 1.5;    // depth of gap channels (deeper than weave)
style_margin = 2;      // clearance around track zones

$fn = 180;

pitch   = strand_width + gap;
hw      = width / 2;
hh      = height / 2;
tz_half = track_width / 2 + style_margin;

// --- Track zone computation ---
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

// Basket weave on a horizontal wall (top or bottom)
module weave_h(wall_y, track_count) {
    segs = free_segments(track_count, width);
    z_rows   = max(1, floor(depth / pitch));
    z_extent = z_rows * pitch - gap;
    z_off    = (depth - z_extent) / 2;

    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        cols    = max(1, floor(seg_len / pitch));
        x_extent = cols * pitch - gap;
        x_off    = seg[0] + (seg_len - x_extent) / 2;

        // Horizontal gap channels (between Z-rows)
        for (i = [0 : z_rows - 2]) {
            translate([x_off,
                       wall_y > 0 ? wall_y - gap_depth : wall_y - 1,
                       z_off + i * pitch + strand_width])
                cube([x_extent, gap_depth + 1, gap]);
        }

        // Vertical gap channels (between X-columns)
        for (j = [0 : cols - 2]) {
            translate([x_off + j * pitch + strand_width,
                       wall_y > 0 ? wall_y - gap_depth : wall_y - 1,
                       z_off])
                cube([gap, gap_depth + 1, z_extent]);
        }

        // Checkerboard under-crossings
        for (i = [0 : z_rows - 1]) {
            for (j = [0 : cols - 1]) {
                if ((i + j) % 2 == 0) {
                    translate([x_off + j * pitch,
                               wall_y > 0 ? wall_y - weave_depth : wall_y - 1,
                               z_off + i * pitch])
                        cube([strand_width, weave_depth + 1, strand_width]);
                }
            }
        }
    }
}

// Basket weave on a vertical wall (left or right)
module weave_v(wall_x, track_count) {
    segs = free_segments(track_count, height);
    z_rows   = max(1, floor(depth / pitch));
    z_extent = z_rows * pitch - gap;
    z_off    = (depth - z_extent) / 2;

    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        cols    = max(1, floor(seg_len / pitch));
        y_extent = cols * pitch - gap;
        y_off    = seg[0] + (seg_len - y_extent) / 2;

        // Horizontal gap channels (between Z-rows)
        for (i = [0 : z_rows - 2]) {
            translate([wall_x > 0 ? wall_x - gap_depth : wall_x - 1,
                       y_off,
                       z_off + i * pitch + strand_width])
                cube([gap_depth + 1, y_extent, gap]);
        }

        // Vertical gap channels (between Y-columns)
        for (j = [0 : cols - 2]) {
            translate([wall_x > 0 ? wall_x - gap_depth : wall_x - 1,
                       y_off + j * pitch + strand_width,
                       z_off])
                cube([gap_depth + 1, gap, z_extent]);
        }

        // Checkerboard under-crossings
        for (i = [0 : z_rows - 1]) {
            for (j = [0 : cols - 1]) {
                if ((i + j) % 2 == 0) {
                    translate([wall_x > 0 ? wall_x - weave_depth : wall_x - 1,
                               y_off + j * pitch,
                               z_off + i * pitch])
                        cube([weave_depth + 1, strand_width, strand_width]);
                }
            }
        }
    }
}

// Full basket-weave pattern around corners
module corner_weave(cx, cy, start_angle) {
    z_rows   = max(1, floor(depth / pitch));
    z_extent = z_rows * pitch - gap;
    z_off    = (depth - z_extent) / 2;

    // Angular layout for corner columns
    arc_len       = PI * radius / 2;
    angle_per_mm  = 90 / arc_len;
    strand_angle  = strand_width * angle_per_mm;
    gap_angle     = gap * angle_per_mm;
    pitch_angle   = pitch * angle_per_mm;
    cols          = max(1, floor(arc_len / pitch));
    total_angle   = cols * pitch_angle - gap_angle;
    center_offset = (90 - total_angle) / 2;

    // 1. Horizontal gap rings (between Z-rows)
    for (i = [0 : z_rows - 2]) {
        translate([cx, cy, z_off + i * pitch + strand_width])
            rotate([0, 0, start_angle])
                rotate_extrude(angle = 90)
                    translate([radius - gap_depth, 0, 0])
                        square([gap_depth + 1, gap]);
    }

    // 2. Vertical (radial) gap channels (between angular columns)
    for (j = [0 : cols - 2]) {
        translate([cx, cy, z_off])
            rotate([0, 0, start_angle + center_offset + j * pitch_angle + strand_angle])
                rotate_extrude(angle = gap_angle)
                    translate([radius - gap_depth, 0, 0])
                        square([gap_depth + 1, z_extent]);
    }

    // 3. Checkerboard under-crossings
    for (i = [0 : z_rows - 1]) {
        for (j = [0 : cols - 1]) {
            if ((i + j) % 2 == 0) {
                translate([cx, cy, z_off + i * pitch])
                    rotate([0, 0, start_angle + center_offset + j * pitch_angle])
                        rotate_extrude(angle = strand_angle)
                            translate([radius - weave_depth, 0, 0])
                                square([weave_depth + 1, strand_width]);
            }
        }
    }
}

module woven_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);
        // Basket weave on all four walls
        weave_h(hh, tracks_top);
        weave_h(-hh, tracks_bottom);
        weave_v(hw, tracks_right);
        weave_v(-hw, tracks_left);
        // Corner weave continuity
        corner_weave(hw - radius, -hh + radius, -90);
        corner_weave(hw - radius,  hh - radius,   0);
        corner_weave(-hw + radius,  hh - radius,  90);
        corner_weave(-hw + radius, -hh + radius, 180);
        // Track grooves
        horizontal_tracks(tracks_top, width, hh, -1);
        horizontal_tracks(tracks_bottom, width, -hh, 1);
        vertical_tracks(tracks_right, height, hw, -1);
        vertical_tracks(tracks_left, height, -hw, 1);
    }
}

woven_shelf();
