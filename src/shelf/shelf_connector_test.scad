// Connector Fit Test Piece
// A short wall section with dovetail track + a matching connector strip.
// Print both flat, then slide the strip into the wall groove to test fit.
// Units: millimeters
//
// Parameters match shelf.scad and shelf_connector.scad

// --- Track Parameters (must match shelf.scad) ---
track_width    = 10;
track_depth    = 2;
dovetail_angle = 25;
wall           = 4;

// --- FDM Tolerances (must match shelf_connector.scad) ---
clearance = 0.10;

// --- Test Piece Size ---
test_length = 30;  // sliding direction — enough to check fit

// --- Derived ---
dovetail_extra = track_depth * tan(dovetail_angle);
half_thickness = track_depth - clearance;
narrow_half_w  = (track_width - 2 * clearance) / 2;
wide_half_w    = narrow_half_w + dovetail_extra;

// Margin around the groove so the wall section is structurally sound
wall_section_width = track_width + 2 * dovetail_extra + 10;

$fn = 180;

// --- Wall section with dovetail groove ---
module wall_section() {
    difference() {
        // Solid block representing a chunk of shelf wall
        translate([-wall_section_width / 2, -wall / 2, 0])
            cube([wall_section_width, wall, test_length]);

        // Dovetail groove cut into the outer face (y = wall/2 side)
        linear_extrude(height = test_length)
            polygon([
                [-track_width / 2,                  wall / 2],
                [ track_width / 2,                  wall / 2],
                [ track_width / 2 + dovetail_extra, wall / 2 - track_depth],
                [-track_width / 2 - dovetail_extra, wall / 2 - track_depth]
            ]);
    }
}

// --- Short connector strip (bowtie cross-section) ---
module connector_strip() {
    linear_extrude(height = test_length)
        polygon([
            [-wide_half_w,   -half_thickness],
            [ wide_half_w,   -half_thickness],
            [ narrow_half_w,  0],
            [ wide_half_w,    half_thickness],
            [-wide_half_w,    half_thickness],
            [-narrow_half_w,  0]
        ]);
}

// Lay out side by side for printing
wall_section();

translate([wall_section_width / 2 + wide_half_w + 5, 0, 0])
    connector_strip();
