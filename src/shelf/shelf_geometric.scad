// Geometric Panel Shelf Variant
// Wall faces divided into recessed rectangular panels with raised borders.
// Alternating panel depths create a subtle shadow pattern.
// Panels are centered within each free segment for symmetry around track zones.
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
tracks_left      = 1;
tracks_right     = 1;

// --- Panel Parameters ---
panel_size   = 18;    // panel cell size (width and height of each grid cell)
border       = 2;     // border width between panels
panel_depth1 = 1.0;   // shallow panel recess
panel_depth2 = 1.5;   // deep panel recess (alternating checkerboard)
style_margin = 2;     // clearance around track zones

$fn = 180;

panel_inner = panel_size - border;  // actual recessed area per cell
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

// Panels on a horizontal wall, centered per segment
module panels_h(wall_y, cut_dir, track_count) {
    segs = free_segments(track_count, width);
    rows = floor(depth / panel_size);
    z_offset = (depth - rows * panel_size) / 2;

    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        cols = floor(seg_len / panel_size);
        if (cols > 0) {
            x_offset = (seg_len - cols * panel_size) / 2 + seg[0];
            for (col = [0 : cols - 1]) {
                cx = x_offset + col * panel_size + panel_size / 2;
                for (row = [0 : rows - 1]) {
                    cz = z_offset + row * panel_size + panel_size / 2;
                    d = ((row + col) % 2 == 0) ? panel_depth1 : panel_depth2;
                    y_pos = (cut_dir == -1)
                        ? wall_y - d
                        : wall_y - 1;
                    translate([cx - panel_inner / 2, y_pos, cz - panel_inner / 2])
                        cube([panel_inner, d + 1, panel_inner]);
                }
            }
        }
    }
}

// Panels on a vertical wall, centered per segment
module panels_v(wall_x, cut_dir, track_count) {
    segs = free_segments(track_count, height);
    rows = floor(depth / panel_size);
    z_offset = (depth - rows * panel_size) / 2;

    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        cols = floor(seg_len / panel_size);
        if (cols > 0) {
            y_offset = (seg_len - cols * panel_size) / 2 + seg[0];
            for (col = [0 : cols - 1]) {
                cy = y_offset + col * panel_size + panel_size / 2;
                for (row = [0 : rows - 1]) {
                    cz = z_offset + row * panel_size + panel_size / 2;
                    d = ((row + col) % 2 == 0) ? panel_depth1 : panel_depth2;
                    x_pos = (cut_dir == -1)
                        ? wall_x - d
                        : wall_x - 1;
                    translate([x_pos, cy - panel_inner / 2, cz - panel_inner / 2])
                        cube([d + 1, panel_inner, panel_inner]);
                }
            }
        }
    }
}

module geometric_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);
        panels_h(height / 2, -1, tracks_top);
        panels_h(-height / 2, 1, tracks_bottom);
        panels_v(width / 2, -1, tracks_right);
        panels_v(-width / 2, 1, tracks_left);
        // Track grooves
        horizontal_tracks(tracks_top, width, height / 2, -1);
        horizontal_tracks(tracks_bottom, width, -height / 2, 1);
        vertical_tracks(tracks_right, height, width / 2, -1);
        vertical_tracks(tracks_left, height, -width / 2, 1);
    }
}

geometric_shelf();
