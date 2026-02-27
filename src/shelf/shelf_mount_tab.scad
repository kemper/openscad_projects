// Wall Mount Tab for Modular Shelf System
// Glue to the flat outside wall of a shelf piece, toward the back.
// Countersunk screw hole for wall mounting.
// Print flat (screw hole facing up).
// Units: millimeters

// --- Shelf size (change to match your shelf piece) ---
shelf_width = 87.5;  // 175 or 87.5

// --- Shelf Parameters (must match shelf.scad) ---
corner_radius = 20;  // shelf corner rounding radius

// --- Tab Parameters ---
tab_thickness  = 16;    // how far tab protrudes from shelf wall
tab_corner_r   = 4;    // rounding on tab edges
tab_height     = 20;   // extent along shelf depth (front-to-back)
screw_count    = 1;    // number of screw holes evenly spaced
screw_shaft_d  = 5;    // clearance hole for screw shaft
screw_head_d   = 10;   // countersink diameter
screw_head_h   = 2.5;  // countersink depth

// --- Derived ---
flat_width = shelf_width - 2 * corner_radius;
tab_width  = flat_width - 10;  // 5mm margin each side of flat zone

$fn = 60;

module mount_tab() {
    difference() {
        // Rounded rectangle body
        linear_extrude(height = tab_thickness)
            offset(r = tab_corner_r)
                square([tab_width - 2 * tab_corner_r,
                        tab_height - 2 * tab_corner_r], center = true);

        // Countersunk screw holes, evenly spaced along width
        for (i = [0 : screw_count - 1]) {
            x = -tab_width / 2 + tab_width / screw_count * (i + 0.5);
            translate([x, 0, -0.1]) {
                cylinder(d = screw_shaft_d, h = tab_thickness + 0.2);
                translate([0, 0, tab_thickness - screw_head_h + 0.1])
                    cylinder(d1 = screw_shaft_d, d2 = screw_head_d,
                             h = screw_head_h + 0.1);
            }
        }
    }
}

mount_tab();
