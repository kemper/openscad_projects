// Terraced Shelf Variant
// Walls have horizontal step-downs along the depth axis.
// Deeper steps toward the back create a modern architectural stepped facade.
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
tracks_bottom    = 1;
tracks_left      = 1;
tracks_right     = 1;

// --- Terrace Parameters ---
step_count     = 6;     // number of distinct steps
step_max_depth = 1.5;   // deepest step recess (at the back)
style_margin   = 2;     // clearance around track zones

$fn = 180;

step_size = depth / step_count;
hw = width / 2;
hh = height / 2;

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

// Step cuts on flat wall portions
module terrace_flat_cuts() {
    flat_w = width - 2 * radius;
    flat_h = height - 2 * radius;

    for (s = [0 : step_count - 1]) {
        d = step_max_depth * (step_count - 1 - s) / max(step_count - 1, 1);
        z = s * step_size;
        if (d > 0.01) {
            translate([-width / 2 + radius, height / 2 - d, z])
                cube([flat_w, d + 1, step_size + 0.01]);
            translate([-width / 2 + radius, -height / 2 - 1, z])
                cube([flat_w, d + 1, step_size + 0.01]);
            translate([width / 2 - d, -height / 2 + radius, z])
                cube([d + 1, flat_h, step_size + 0.01]);
            translate([-width / 2 - 1, -height / 2 + radius, z])
                cube([d + 1, flat_h, step_size + 0.01]);
        }
    }
}

// Corner terrace cuts using rotate_extrude
module terrace_corner_cuts() {
    corners = [
        [hw - radius, -hh + radius, -90],
        [hw - radius,  hh - radius,   0],
        [-hw + radius,  hh - radius,  90],
        [-hw + radius, -hh + radius, 180]
    ];

    for (s = [0 : step_count - 1]) {
        d = step_max_depth * (step_count - 1 - s) / max(step_count - 1, 1);
        z = s * step_size;
        if (d > 0.01) {
            for (c = corners) {
                translate([c[0], c[1], z])
                    rotate([0, 0, c[2]])
                        rotate_extrude(angle = 90, $fn = 48)
                            translate([radius - d, 0])
                                square([d + 0.1, step_size + 0.01]);
            }
        }
    }
}

module terraced_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);
        difference() {
            terrace_flat_cuts();
            track_zone_masks();
        }
        terrace_corner_cuts();
        horizontal_tracks(tracks_top, width, height / 2, -1);
        horizontal_tracks(tracks_bottom, width, -height / 2, 1);
        vertical_tracks(tracks_right, height, width / 2, -1);
        vertical_tracks(tracks_left, height, -width / 2, 1);
    }
}

terraced_shelf();
