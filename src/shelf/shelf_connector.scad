// Connector Strip for Modular Shelf System
// Slides into the back-to-back dovetail tracks of two adjacent shelf pieces.
// Bowtie/hourglass cross-section locks into dovetail grooves to prevent pull-apart.
// Print flat on the bed for best strength.
// Units: millimeters
//
// IMPORTANT: track_width, track_depth, and dovetail_angle must match shelf.scad

// --- Track Parameters (must match shelf.scad) ---
track_width      = 10;   // width of groove at wall surface
track_depth      = 2;    // depth of groove in the shelf
track_length_pct = 75;   // percentage of shelf depth covered by groove
shelf_depth      = 120;  // depth of the shelf (to derive track length)
dovetail_angle   = 25;   // degrees from vertical (must match shelf.scad)

// --- FDM Tolerances ---
clearance = 0.2;  // clearance per side for FDM fit

// --- Derived Dimensions ---
track_length    = shelf_depth * track_length_pct / 100;
strip_length    = track_length - 1;  // 1mm shorter for easy insertion
dovetail_extra  = track_depth * tan(dovetail_angle);
half_thickness  = track_depth - clearance;
narrow_half_w   = (track_width - 2 * clearance) / 2;
wide_half_w     = narrow_half_w + dovetail_extra;

$fn = 180;

// Bowtie cross-section: wide at top and bottom edges, narrow at center
module connector_strip() {
    linear_extrude(height = strip_length)
        polygon([
            [-wide_half_w,   -half_thickness],  // bottom-left (wide, locks in shelf A)
            [ wide_half_w,   -half_thickness],  // bottom-right (wide)
            [ narrow_half_w,  0],               // center-right (narrow pinch at joint)
            [ wide_half_w,    half_thickness],  // top-right (wide, locks in shelf B)
            [-wide_half_w,    half_thickness],  // top-left (wide)
            [-narrow_half_w,  0]                // center-left (narrow pinch at joint)
        ]);
}

connector_strip();
