// Perforated Screen Shelf Variant
// Walls have arrays of punched holes in a hex-offset pattern.
// Light passes through, giving an open architectural look.
// Holes are centered within each free segment for symmetry and wrap around corners.
// Units: millimeters

use <shelf.scad>

// --- Shelf Parameters (must match shelf.scad) ---
width  = 250;
height = 125;
depth  = 120;
wall   = 4;
radius = 20;

// --- Track Parameters (must match shelf.scad) ---
track_width      = 10;
track_depth      = 2;
track_length_pct = 75;
dovetail_angle   = 25;
tracks_top       = 0;
tracks_bottom    = 2;
tracks_left      = 2;
tracks_right     = 1;

// --- Perforation Parameters ---
hole_radius  = 4;        // radius (or half-width) of each hole
hole_spacing = 12;       // center-to-center spacing
hole_shape   = "hexagon"; // "circle", "square", "diamond", or "hexagon"
style_margin = 2;        // clearance around track zones

$fn = 180;

hw = width / 2;
hh = height / 2;
tz_half = track_width / 2 + style_margin;
row_height = hole_spacing * sin(60);  // vertical spacing for hex offset

// --- Hole punch shape (base-centered, extends along +Z) ---
module hole_punch(h) {
    if (hole_shape == "square") {
        translate([-hole_radius, -hole_radius, 0])
            cube([hole_radius * 2, hole_radius * 2, h]);
    } else if (hole_shape == "diamond") {
        rotate([0, 0, 45])
            translate([-hole_radius, -hole_radius, 0])
                cube([hole_radius * 2, hole_radius * 2, h]);
    } else if (hole_shape == "hexagon") {
        cylinder(r = hole_radius, h = h, $fn = 6);
    } else {
        cylinder(r = hole_radius, h = h, $fn = 24);
    }
}

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

// Holes through a horizontal wall, centered per segment
module holes_h(wall_y, track_count) {
    segs = free_segments(track_count, width);
    z_start = hole_radius;
    z_end   = depth - hole_radius;
    rows = floor((z_end - z_start) / row_height);
    y_start = wall_y > 0 ? wall_y - wall - 1 : wall_y - 1;

    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        usable = seg_len - 2 * hole_radius;
        if (usable > 0) {
            cols = max(1, floor(usable / hole_spacing) + 1);
            span = (cols - 1) * hole_spacing;
            seg_center = (seg[0] + seg[1]) / 2;

            for (row = [0 : rows]) {
                z = z_start + row * row_height;
                x_shift = (row % 2 == 0) ? 0 : hole_spacing / 2;
                for (col = [0 : cols - 1]) {
                    x = seg_center - span / 2 + col * hole_spacing + x_shift;
                    if (x >= seg[0] + hole_radius && x <= seg[1] - hole_radius)
                        translate([x, y_start, z])
                            rotate([-90, 0, 0])
                                hole_punch(wall + 2);
                }
            }
        }
    }
}

// Holes through a vertical wall, centered per segment
module holes_v(wall_x, track_count) {
    segs = free_segments(track_count, height);
    z_start = hole_radius;
    z_end   = depth - hole_radius;
    rows = floor((z_end - z_start) / row_height);
    x_start = wall_x > 0 ? wall_x - wall - 1 : wall_x - 1;

    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        usable = seg_len - 2 * hole_radius;
        if (usable > 0) {
            cols = max(1, floor(usable / hole_spacing) + 1);
            span = (cols - 1) * hole_spacing;
            seg_center = (seg[0] + seg[1]) / 2;

            for (row = [0 : rows]) {
                z = z_start + row * row_height;
                y_shift = (row % 2 == 0) ? 0 : hole_spacing / 2;
                for (col = [0 : cols - 1]) {
                    y = seg_center - span / 2 + col * hole_spacing + y_shift;
                    if (y >= seg[0] + hole_radius && y <= seg[1] - hole_radius)
                        translate([x_start, y, z])
                            rotate([0, 90, 0])
                                hole_punch(wall + 2);
                }
            }
        }
    }
}

// Holes through corner walls (radially oriented)
module corner_holes(cx, cy, start_angle) {
    arc_len = 3.14159265 * radius / 2;
    usable = arc_len - 2 * hole_radius;
    z_start = hole_radius;
    z_end   = depth - hole_radius;
    rows = floor((z_end - z_start) / row_height);

    if (usable > 0) {
        cols = max(1, floor(usable / hole_spacing) + 1);
        span = (cols - 1) * hole_spacing;
        angle_per_mm = 90 / arc_len;

        for (row = [0 : rows]) {
            z = z_start + row * row_height;
            arc_shift = (row % 2 == 0) ? 0 : hole_spacing / 2;
            for (col = [0 : cols - 1]) {
                arc_pos = -span / 2 + col * hole_spacing + arc_shift;
                if (abs(arc_pos) <= usable / 2) {
                    a = start_angle + 45 + arc_pos * angle_per_mm;
                    translate([cx + (radius + 1) * cos(a),
                               cy + (radius + 1) * sin(a), z])
                        rotate([0, 0, a])
                            rotate([0, -90, 0])
                                hole_punch(wall + 2);
                }
            }
        }
    }
}

module perforated_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);
        // Flat wall holes (centered per segment)
        holes_h(height / 2, tracks_top);
        holes_h(-height / 2, tracks_bottom);
        holes_v(width / 2, tracks_right);
        holes_v(-width / 2, tracks_left);
        // Corner holes
        corner_holes(hw - radius, -hh + radius, -90);
        corner_holes(hw - radius,  hh - radius,   0);
        corner_holes(-hw + radius,  hh - radius,  90);
        corner_holes(-hw + radius, -hh + radius, 180);
        // Track grooves
        horizontal_tracks(tracks_top, width, height / 2, -1);
        horizontal_tracks(tracks_bottom, width, -height / 2, 1);
        vertical_tracks(tracks_right, height, width / 2, -1);
        vertical_tracks(tracks_left, height, -width / 2, 1);
    }
}

perforated_shelf();
