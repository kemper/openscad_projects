// Shelf Bin/Drawer — Fluted Front with Handle
// Decorative vertical fluting on the front face and a small pull handle.
// Units: millimeters

// --- Shelf Parameters (must match shelf.scad) ---
width  = 175;
height = 175;
depth  = 90;
wall   = 4;
radius = 20;

// --- Bin Parameters ---
bin_wall        = 2;    // wall/floor thickness (left, right, back)
face_thickness  = 3;    // front wall thickness (thicker for fluting)
clearance       = 0.5;  // gap per side so bin slides in/out smoothly
height_fraction = 1/3;  // bin height as fraction of shelf opening height

// --- Flute Parameters ---
flute_radius = 4;     // radius of curvature of each groove
flute_depth  = 1.5;   // how deep grooves cut into the front face
flute_count  = 16;    // number of vertical grooves

// --- Handle Parameters ---
handle_width    = 60;   // width of the handle bar
handle_height   = 6;    // vertical size of the handle bar
handle_depth    = 10;   // how far handle protrudes from front face
handle_rounding = 2.5;  // edge rounding radius

$fn = 180;

// --- Derived Dimensions ---
opening_width  = width - 2 * wall;
opening_height = height - 2 * wall;

bin_width       = opening_width - 2 * clearance;
bin_full_height = opening_height - 2 * clearance;
bin_radius      = radius - clearance;
bin_height      = bin_full_height * height_fraction;
bin_top_y       = -bin_full_height / 2 + bin_height;

flute_span = bin_width - 2 * bin_radius;
flute_step = flute_span / (flute_count - 1);

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

// Bin body: single solid piece with floor, 4 walls, open top
module bin_body() {
    difference() {
        linear_extrude(height = depth)
            bin_profile();

        translate([0, 0, face_thickness])
            linear_extrude(height = depth - face_thickness - bin_wall)
                rounded_rect(bin_width - 2 * bin_wall, bin_full_height - 2 * bin_wall, bin_radius - bin_wall);
    }
}

// Vertical flute grooves on the front face
module flutes() {
    for (i = [0 : flute_count - 1]) {
        x = -flute_span / 2 + i * flute_step;
        translate([x, 0, flute_depth - flute_radius])
            rotate([90, 0, 0])
                cylinder(r = flute_radius, h = bin_full_height, center = true, $fn = 32);
    }
}

// Rounded handle bar protruding from the front face
module handle() {
    r = handle_rounding;
    // Back of handle embeds 2mm into face for solid connection over flute grooves
    translate([0, bin_top_y - handle_height / 2 - 2, 2 - handle_depth / 2])
        minkowski() {
            cube([handle_width - 2 * r, handle_height - 2 * r, handle_depth - 2 * r], center = true);
            sphere(r = r, $fn = 32);
        }
}

// Complete bin with fluted front and handle
module bin() {
    difference() {
        bin_body();
        flutes();
    }
    handle();
}

bin();
