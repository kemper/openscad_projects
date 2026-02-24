// Modular Shelf Unit with Track-and-Strip Connector System
// A hollow cuboid with open front and back faces, rounded edges along the depth axis.
// Dovetail tracks on outer walls allow connector strips to mechanically join shelf pieces.
// Units: millimeters

// --- Shelf Parameters ---
width  = 125;  // left to right
height = 125;  // top to bottom
depth  = 120;  // front to back (the open axis)
wall   = 4;    // wall thickness
radius = 20;   // corner rounding radius (same for inner and outer edges)

// --- Track Parameters ---
track_width      = 10;   // width of groove at wall surface (narrow opening)
track_depth      = 2;    // how deep each groove cuts into the wall
track_length_pct = 75;   // percentage of depth covered, starting from back
dovetail_angle   = 25;   // degrees from vertical — widens groove deeper in wall

// --- Number of tracks per wall (0 = no tracks on that wall) ---
// Tracks are evenly spaced along the wall length.
// e.g., tracks_top = 2 on a 250mm wide shelf places tracks at 62.5mm and 187.5mm
tracks_top    = 1;
tracks_bottom = 0;
tracks_left   = 1;
tracks_right  = 0;

$fn = 180;

track_length = depth * track_length_pct / 100;
dovetail_extra = track_depth * tan(dovetail_angle);

// A centered rounded rectangle in 2D
module rounded_rect(w, h, r) {
    offset(r = r)
        square([w - 2 * r, h - 2 * r], center = true);
}

// Shelf body: hollow rounded-rect profile extruded along depth
module shelf_body(w, h, d, wall, r) {
    linear_extrude(height = d)
        difference() {
            rounded_rect(w, h, r);
            rounded_rect(w - 2 * wall, h - 2 * wall, r);
        }
}

// Dovetail tracks along a horizontal wall (top or bottom)
// inward_dir: -1 for top wall (groove goes toward -y), +1 for bottom wall (toward +y)
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

// Dovetail tracks along a vertical wall (left or right)
// inward_dir: -1 for right wall (groove goes toward -x), +1 for left wall (toward +x)
module vertical_tracks(count, wall_height, wall_x, inward_dir) {
    if (count > 0) {
        segment = wall_height / count;
        for (i = [0 : count - 1]) {
            y_pos = -wall_height / 2 + segment * (i + 0.5);
            linear_extrude(height = track_length)
                polygon([
                    [wall_x,                        y_pos - track_width / 2],
                    [wall_x,                        y_pos + track_width / 2],
                    [wall_x + inward_dir * track_depth, y_pos + track_width / 2 + dovetail_extra],
                    [wall_x + inward_dir * track_depth, y_pos - track_width / 2 - dovetail_extra]
                ]);
        }
    }
}

// Shelf with dovetail track grooves subtracted
module shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);

        // Top wall tracks (spaced along width)
        horizontal_tracks(tracks_top, width, height / 2, -1);

        // Bottom wall tracks (spaced along width)
        horizontal_tracks(tracks_bottom, width, -height / 2, 1);

        // Right wall tracks (spaced along height)
        vertical_tracks(tracks_right, height, width / 2, -1);

        // Left wall tracks (spaced along height)
        vertical_tracks(tracks_left, height, -width / 2, 1);
    }
}

shelf();
