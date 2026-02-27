// Smiley Cube — test model for per-face paint_color 3MF export
// A 40mm cube with a smiley face on the top surface.
//
// Render specific parts via the command line:
//   openscad -D 'part="body"' -o body.stl smiley_cube.scad
//   openscad -D 'part="face"' -o face.stl smiley_cube.scad
//
// Units: millimeters

// --- Part Selection ---
part = "all";  // "body", "face", or "all"

// --- Cube Parameters ---
cube_size = 40;

// --- Smiley Parameters ---
feature_depth = 0.4;  // thin raised features flush with top

// Eyes: two circles in the upper half of the top face
eye_radius = 3;
eye_spacing = 12;  // distance between eye centers
eye_y_offset = 6;  // offset from center toward top

// Mouth: crescent arc in the lower half
mouth_outer_r = 10;
mouth_inner_r = 7;
mouth_y_offset = -2;  // center of mouth arcs (below center)
mouth_clip_y = -3;    // clip above this Y relative to mouth center

$fn = 80;

// --- Modules ---

module eye(x_pos, y_pos) {
    translate([cube_size/2 + x_pos, cube_size/2 + y_pos, cube_size - feature_depth])
        cylinder(r=eye_radius, h=feature_depth);
}

module mouth() {
    translate([cube_size/2, cube_size/2 + mouth_y_offset, cube_size - feature_depth])
        linear_extrude(height=feature_depth)
            intersection() {
                difference() {
                    circle(r=mouth_outer_r);
                    circle(r=mouth_inner_r);
                }
                // Clip to bottom half of the arc
                translate([0, mouth_clip_y, 0])
                    square([mouth_outer_r * 3, mouth_outer_r * 2], center=true);
            }
}

module smiley_features() {
    eye(-eye_spacing/2, eye_y_offset);
    eye(eye_spacing/2, eye_y_offset);
    mouth();
}

module cube_body() {
    difference() {
        cube([cube_size, cube_size, cube_size]);
        smiley_features();
    }
}

// --- Render selected part ---
if (part == "body") {
    cube_body();
} else if (part == "face") {
    smiley_features();
} else {
    cube_body();
    color("gold") smiley_features();
}
