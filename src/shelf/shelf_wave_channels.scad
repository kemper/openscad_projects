// Wave Channels Shelf Variant
// Basket-weave grid with sinusoidal (wavy) gap channels instead of straight lines.
// Creates an organic, woven-reed look. Checkerboard under-crossings remain flat for contrast.
// Corners use standard (non-wavy) woven treatment for clean transitions.
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
strand_width = 6;       // width of each woven strand
gap          = 1;       // visible channel between strands
weave_depth  = 1.0;     // recess depth for "under" crossings
gap_depth    = 1.5;     // depth of gap channels (deeper than weave)
style_margin = 2;       // clearance around track zones

// --- Wave Parameters ---
wave_amp    = 1.5;      // amplitude of channel undulation (mm)
wave_period = 30;       // wavelength of undulation (mm)
wave_steps  = 16;       // segments per channel for smoothness

$fn = 180;

pitch   = strand_width + gap;
hw      = width / 2;
hh      = height / 2;
tz_half = track_width / 2 + style_margin;

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

// Wavy basket weave on a horizontal wall (top or bottom)
module wavy_weave_h(wall_y, track_count) {
    segs = free_segments(track_count, width);
    z_rows   = max(1, floor(depth / pitch));
    z_extent = z_rows * pitch - gap;
    z_off    = (depth - z_extent) / 2;

    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        cols    = max(1, floor(seg_len / pitch));
        x_extent = cols * pitch - gap;
        x_off    = seg[0] + (seg_len - x_extent) / 2;

        // Wavy horizontal gap channels (between Z-rows)
        // Z position undulates based on X position
        for (i = [0 : z_rows - 2]) {
            base_z = z_off + i * pitch + strand_width;
            dx = x_extent / wave_steps;
            for (s = [0 : wave_steps - 1]) {
                sx = x_off + s * dx;
                mid_x = sx + dx / 2;
                wave_offset = wave_amp * sin(mid_x * 360 / wave_period);
                translate([sx,
                           wall_y > 0 ? wall_y - gap_depth : wall_y - 1,
                           base_z + wave_offset])
                    cube([dx + 0.01, gap_depth + 1, gap]);
            }
        }

        // Wavy vertical gap channels (between X-columns)
        // X position undulates based on Z position
        for (j = [0 : cols - 2]) {
            base_x = x_off + j * pitch + strand_width;
            dz = z_extent / wave_steps;
            for (s = [0 : wave_steps - 1]) {
                sz = z_off + s * dz;
                mid_z = sz + dz / 2;
                wave_offset = wave_amp * sin(mid_z * 360 / wave_period);
                translate([base_x + wave_offset,
                           wall_y > 0 ? wall_y - gap_depth : wall_y - 1,
                           sz])
                    cube([gap, gap_depth + 1, dz + 0.01]);
            }
        }

        // Checkerboard under-crossings (flat, same as woven)
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

// Wavy basket weave on a vertical wall (left or right)
module wavy_weave_v(wall_x, track_count) {
    segs = free_segments(track_count, height);
    z_rows   = max(1, floor(depth / pitch));
    z_extent = z_rows * pitch - gap;
    z_off    = (depth - z_extent) / 2;

    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        cols    = max(1, floor(seg_len / pitch));
        y_extent = cols * pitch - gap;
        y_off    = seg[0] + (seg_len - y_extent) / 2;

        // Wavy horizontal gap channels (between Z-rows)
        // Z position undulates based on Y position
        for (i = [0 : z_rows - 2]) {
            base_z = z_off + i * pitch + strand_width;
            dy = y_extent / wave_steps;
            for (s = [0 : wave_steps - 1]) {
                sy = y_off + s * dy;
                mid_y = sy + dy / 2;
                wave_offset = wave_amp * sin(mid_y * 360 / wave_period);
                translate([wall_x > 0 ? wall_x - gap_depth : wall_x - 1,
                           sy,
                           base_z + wave_offset])
                    cube([gap_depth + 1, dy + 0.01, gap]);
            }
        }

        // Wavy vertical gap channels (between Y-columns)
        // Y position undulates based on Z position
        for (j = [0 : cols - 2]) {
            base_y = y_off + j * pitch + strand_width;
            dz = z_extent / wave_steps;
            for (s = [0 : wave_steps - 1]) {
                sz = z_off + s * dz;
                mid_z = sz + dz / 2;
                wave_offset = wave_amp * sin(mid_z * 360 / wave_period);
                translate([wall_x > 0 ? wall_x - gap_depth : wall_x - 1,
                           base_y + wave_offset,
                           sz])
                    cube([gap_depth + 1, gap, dz + 0.01]);
            }
        }

        // Checkerboard under-crossings (flat, same as woven)
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

// Corner weave (non-wavy, reused from shelf_woven pattern)
module corner_weave(cx, cy, start_angle) {
    z_rows   = max(1, floor(depth / pitch));
    z_extent = z_rows * pitch - gap;
    z_off    = (depth - z_extent) / 2;

    arc_len       = PI * radius / 2;
    angle_per_mm  = 90 / arc_len;
    strand_angle  = strand_width * angle_per_mm;
    gap_angle     = gap * angle_per_mm;
    pitch_angle   = pitch * angle_per_mm;
    cols          = max(1, floor(arc_len / pitch));
    total_angle   = cols * pitch_angle - gap_angle;
    center_offset = (90 - total_angle) / 2;

    // Horizontal gap rings (between Z-rows)
    for (i = [0 : z_rows - 2]) {
        translate([cx, cy, z_off + i * pitch + strand_width])
            rotate([0, 0, start_angle])
                rotate_extrude(angle = 90)
                    translate([radius - gap_depth, 0, 0])
                        square([gap_depth + 1, gap]);
    }

    // Vertical (radial) gap channels (between angular columns)
    for (j = [0 : cols - 2]) {
        translate([cx, cy, z_off])
            rotate([0, 0, start_angle + center_offset + j * pitch_angle + strand_angle])
                rotate_extrude(angle = gap_angle)
                    translate([radius - gap_depth, 0, 0])
                        square([gap_depth + 1, z_extent]);
    }

    // Checkerboard under-crossings
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

module wavy_woven_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);

        // Wavy basket weave on all four walls
        wavy_weave_h(hh, tracks_top);
        wavy_weave_h(-hh, tracks_bottom);
        wavy_weave_v(hw, tracks_right);
        wavy_weave_v(-hw, tracks_left);

        // Corner weave (non-wavy for clean transitions)
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

wavy_woven_shelf();
