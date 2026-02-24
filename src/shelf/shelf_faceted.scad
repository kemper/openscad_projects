// Faceted / Low-Poly Shelf Variant
// Exterior walls have a zigzag/sawtooth profile along the depth axis,
// creating angled planar facets that catch light differently.
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
tracks_left      = 0;
tracks_right     = 0;

// --- Facet Parameters ---
facet_size  = 15;    // length of each facet pair along depth
facet_depth = 1.5;   // max depth of each V-groove between facets
style_margin = 2;    // clearance around track zones

$fn = 180;

facet_steps = 40;    // resolution for the zigzag approximation
dz = depth / facet_steps;
hw = width / 2;
hh = height / 2;

// Triangle wave: ramps up and down with period = facet_size
function triangle_wave(z) =
    let(phase = (z / facet_size) - floor(z / facet_size))
    facet_depth * (phase < 0.5 ? 2 * phase : 2 * (1 - phase));

// Track zone masks
module track_zone_masks() {
    mask_w = track_width + 2 * style_margin;
    if (tracks_top > 0) {
        seg = width / tracks_top;
        for (i = [0 : tracks_top - 1]) {
            x = -width / 2 + seg * (i + 0.5);
            translate([x - mask_w / 2, height / 2 - wall - 1, -1])
                cube([mask_w, wall + 2, depth + 2]);
        }
    }
    if (tracks_bottom > 0) {
        seg = width / tracks_bottom;
        for (i = [0 : tracks_bottom - 1]) {
            x = -width / 2 + seg * (i + 0.5);
            translate([x - mask_w / 2, -height / 2 - 1, -1])
                cube([mask_w, wall + 2, depth + 2]);
        }
    }
    if (tracks_right > 0) {
        seg = height / tracks_right;
        for (i = [0 : tracks_right - 1]) {
            y = -height / 2 + seg * (i + 0.5);
            translate([width / 2 - wall - 1, y - mask_w / 2, -1])
                cube([wall + 2, mask_w, depth + 2]);
        }
    }
    if (tracks_left > 0) {
        seg = height / tracks_left;
        for (i = [0 : tracks_left - 1]) {
            y = -height / 2 + seg * (i + 0.5);
            translate([-width / 2 - 1, y - mask_w / 2, -1])
                cube([wall + 2, mask_w, depth + 2]);
        }
    }
}

// Faceted cuts on flat wall portions
module facet_flat_cuts() {
    flat_w = width - 2 * radius;
    flat_h = height - 2 * radius;

    for (i = [0 : facet_steps - 1]) {
        z = i * dz;
        d = triangle_wave(z);
        if (d > 0.01) {
            translate([-width / 2 + radius, height / 2 - d, z])
                cube([flat_w, d + 1, dz + 0.01]);
            translate([-width / 2 + radius, -height / 2 - 1, z])
                cube([flat_w, d + 1, dz + 0.01]);
            translate([width / 2 - d, -height / 2 + radius, z])
                cube([d + 1, flat_h, dz + 0.01]);
            translate([-width / 2 - 1, -height / 2 + radius, z])
                cube([d + 1, flat_h, dz + 0.01]);
        }
    }
}

// Corner facet cuts using rotate_extrude
module facet_corner_cuts() {
    corners = [
        [hw - radius, -hh + radius, -90],
        [hw - radius,  hh - radius,   0],
        [-hw + radius,  hh - radius,  90],
        [-hw + radius, -hh + radius, 180]
    ];

    for (i = [0 : facet_steps - 1]) {
        z = i * dz;
        d = triangle_wave(z);
        if (d > 0.01) {
            for (c = corners) {
                translate([c[0], c[1], z])
                    rotate([0, 0, c[2]])
                        rotate_extrude(angle = 90, $fn = 48)
                            translate([radius - d, 0])
                                square([d + 0.1, dz + 0.01]);
            }
        }
    }
}

module faceted_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);
        difference() {
            facet_flat_cuts();
            track_zone_masks();
        }
        facet_corner_cuts();
        horizontal_tracks(tracks_top, width, height / 2, -1);
        horizontal_tracks(tracks_bottom, width, -height / 2, 1);
        vertical_tracks(tracks_right, height, width / 2, -1);
        vertical_tracks(tracks_left, height, -width / 2, 1);
    }
}

faceted_shelf();
