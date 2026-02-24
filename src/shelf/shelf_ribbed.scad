// Ribbed Shelf Variant
// Imports the base shelf and subtracts semicircular grooves along the depth axis.
// Grooves are centered within each free segment between track zones for symmetry.
// Pattern wraps around rounded corners.
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
tracks_bottom    = 0;
tracks_left      = 1;
tracks_right     = 0;

// --- Groove Parameters ---
groove_radius  = 1;    // radius of semicircular groove
groove_spacing = 4;    // center-to-center distance between grooves
style_margin   = 2;    // clearance around track zones

$fn = 180;

hw = width / 2;
hh = height / 2;
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

// Grooves centered within each free segment on a horizontal wall
module wall_grooves_h(wall_y, track_count) {
    segs = free_segments(track_count, width);
    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        n = max(1, floor((seg_len - 2 * groove_radius) / groove_spacing) + 1);
        span = (n - 1) * groove_spacing;
        center = (seg[0] + seg[1]) / 2;
        for (i = [0 : n - 1]) {
            x = center - span / 2 + i * groove_spacing;
            translate([x, wall_y, -1])
                cylinder(r = groove_radius, h = depth + 2, $fn = 20);
        }
    }
}

// Grooves centered within each free segment on a vertical wall
module wall_grooves_v(wall_x, track_count) {
    segs = free_segments(track_count, height);
    for (seg = segs) {
        seg_len = seg[1] - seg[0];
        n = max(1, floor((seg_len - 2 * groove_radius) / groove_spacing) + 1);
        span = (n - 1) * groove_spacing;
        center = (seg[0] + seg[1]) / 2;
        for (i = [0 : n - 1]) {
            y = center - span / 2 + i * groove_spacing;
            translate([wall_x, y, -1])
                cylinder(r = groove_radius, h = depth + 2, $fn = 20);
        }
    }
}

// Grooves along each rounded corner arc
module corner_grooves(cx, cy, start_angle) {
    arc_len = 3.14159265 * radius / 2;
    n = max(1, floor(arc_len / groove_spacing));
    angle_step = 90 / n;
    for (i = [0 : n - 1]) {
        a = start_angle + angle_step * (i + 0.5);
        translate([cx + radius * cos(a), cy + radius * sin(a), -1])
            cylinder(r = groove_radius, h = depth + 2, $fn = 20);
    }
}

module ribbed_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);
        // Flat wall grooves (centered per segment)
        wall_grooves_h(height / 2, tracks_top);
        wall_grooves_h(-height / 2, tracks_bottom);
        wall_grooves_v(width / 2, tracks_right);
        wall_grooves_v(-width / 2, tracks_left);
        // Corner grooves
        corner_grooves(hw - radius, -hh + radius, -90);
        corner_grooves(hw - radius,  hh - radius,   0);
        corner_grooves(-hw + radius,  hh - radius,  90);
        corner_grooves(-hw + radius, -hh + radius, 180);
        // Track grooves
        horizontal_tracks(tracks_top, width, height / 2, -1);
        horizontal_tracks(tracks_bottom, width, -height / 2, 1);
        vertical_tracks(tracks_right, height, width / 2, -1);
        vertical_tracks(tracks_left, height, -width / 2, 1);
    }
}

ribbed_shelf();
