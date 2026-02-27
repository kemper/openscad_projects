// Two-Color Shelf — proof of concept for multi-color 3MF export
// Splits the shelf into a body and a colored accent band along the top rim.
//
// Render specific parts via the command line:
//   openscad -D 'part="body"' -o body.stl shelf_two_color.scad
//   openscad -D 'part="accent"' -o accent.stl shelf_two_color.scad
//
// Units: millimeters

// --- Part Selection ---
part = "all";  // "body", "accent", or "all"

// --- Shelf Parameters ---
width  = 125;
height = 125;
depth  = 120;
wall   = 4;
radius = 20;

// --- Accent Band ---
accent_height = 8;  // height of the colored top band

// --- Track Parameters ---
track_width      = 10;
track_depth      = 2;
track_length_pct = 75;
dovetail_angle   = 25;

tracks_top    = 1;
tracks_bottom = 0;
tracks_left   = 1;
tracks_right  = 0;

$fn = 180;

track_length   = depth * track_length_pct / 100;
dovetail_extra = track_depth * tan(dovetail_angle);

module rounded_rect(w, h, r) {
    offset(r = r)
        square([w - 2 * r, h - 2 * r], center = true);
}

module shelf_body_shape(w, h, d, wall, r) {
    linear_extrude(height = d)
        difference() {
            rounded_rect(w, h, r);
            rounded_rect(w - 2 * wall, h - 2 * wall, r);
        }
}

module horizontal_tracks(count, wall_width, wall_y, inward_dir) {
    if (count > 0) {
        segment = wall_width / count;
        for (i = [0 : count - 1]) {
            x_pos = -wall_width / 2 + segment * (i + 0.5);
            linear_extrude(height = track_length)
                polygon([
                    [x_pos - track_width / 2,                  wall_y],
                    [x_pos + track_width / 2,                  wall_y],
                    [x_pos + track_width / 2 + dovetail_extra, wall_y + inward_dir * track_depth],
                    [x_pos - track_width / 2 - dovetail_extra, wall_y + inward_dir * track_depth]
                ]);
        }
    }
}

module vertical_tracks(count, wall_height, wall_x, inward_dir) {
    if (count > 0) {
        segment = wall_height / count;
        for (i = [0 : count - 1]) {
            y_pos = -wall_height / 2 + segment * (i + 0.5);
            linear_extrude(height = track_length)
                polygon([
                    [wall_x,                            y_pos - track_width / 2],
                    [wall_x,                            y_pos + track_width / 2],
                    [wall_x + inward_dir * track_depth, y_pos + track_width / 2 + dovetail_extra],
                    [wall_x + inward_dir * track_depth, y_pos - track_width / 2 - dovetail_extra]
                ]);
        }
    }
}

// Full shelf with tracks subtracted
module full_shelf() {
    difference() {
        shelf_body_shape(width, height, depth, wall, radius);
        horizontal_tracks(tracks_top, width, height / 2, -1);
        horizontal_tracks(tracks_bottom, width, -height / 2, 1);
        vertical_tracks(tracks_right, height, width / 2, -1);
        vertical_tracks(tracks_left, height, -width / 2, 1);
    }
}

// Accent band: top rim of the shelf
module accent_region() {
    translate([0, height / 2 - accent_height / 2, depth / 2])
        cube([width + 1, accent_height, depth + 1], center = true);
}

// Accent piece (colored top band)
module shelf_accent() {
    intersection() {
        full_shelf();
        accent_region();
    }
}

// Body (everything except the accent band)
module shelf_body() {
    difference() {
        full_shelf();
        accent_region();
    }
}

// --- Render selected part ---
if (part == "body") {
    shelf_body();
} else if (part == "accent") {
    shelf_accent();
} else {
    shelf_body();
    color("royalblue") shelf_accent();
}
