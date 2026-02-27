// Shelf Bin/Drawer
// A shallow drawer that slides into the shelf opening along the depth axis.
// Sits at the bottom of the shelf opening; open top lets items peek out.
// Left/right sides follow the shelf's inner curved profile at the bottom.
// Units: millimeters

// --- Shelf Parameters (must match shelf.scad) ---
width  = 175;
height = 175;
depth  = 90;
wall   = 4;
radius = 20;

// --- Bin Parameters ---
bin_wall        = 2;    // wall/floor thickness (left, right, back)
face_thickness  = 3;    // front wall thickness (thicker for future texture)
clearance       = 0.5;  // gap per side so bin slides in/out smoothly
height_fraction = 1/3;  // bin height as fraction of shelf opening height

$fn = 180;

// --- Derived Dimensions ---
opening_width  = width - 2 * wall;
opening_height = height - 2 * wall;

bin_width       = opening_width - 2 * clearance;
bin_full_height = opening_height - 2 * clearance;
bin_radius      = radius - clearance;
bin_height      = bin_full_height * height_fraction;

// A centered rounded rectangle in 2D
module rounded_rect(w, h, r) {
    offset(r = r)
        square([w - 2 * r, h - 2 * r], center = true);
}

// 2D outer profile: bottom portion of the shelf's inner rounded rect
module bin_profile() {
    intersection() {
        rounded_rect(bin_width, bin_full_height, bin_radius);
        translate([0, -(bin_full_height - bin_height) / 2])
            square([bin_width + 1, bin_height], center = true);
    }
}

// Complete bin: single solid piece with floor, 4 walls, open top
module bin() {
    difference() {
        // Outer solid — full shelf depth
        linear_extrude(height = depth)
            bin_profile();

        // Inner void — leaves front wall (face_thickness) and back wall (bin_wall)
        translate([0, 0, face_thickness])
            linear_extrude(height = depth - face_thickness - bin_wall)
                rounded_rect(bin_width - 2 * bin_wall, bin_full_height - 2 * bin_wall, bin_radius - bin_wall);
    }
}

bin();
