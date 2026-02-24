// Fluted Shelf Variant
// Wave ridges run along the depth axis (front-to-back),
// creating a corrugated appearance on all exterior walls.
// Pattern wraps around rounded corners and is symmetric around track zones.
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
tracks_left      = 0;
tracks_right     = 0;

// --- Flute Parameters ---
flute_amplitude = 1.5;   // max depth of wave trough
flute_period    = 20;    // target wavelength (auto-adjusted per segment)
style_margin    = 2;     // clearance around track zones

$fn = 180;

// Resolution
wall_res   = 80;   // sample points per straight wall
corner_res = 24;   // sample points per corner arc

// Derived
hw = width / 2;
hh = height / 2;
flat_w = width - 2 * radius;
flat_h = height - 2 * radius;
tz_half = track_width / 2 + style_margin;

// --- Track zone computation ---
// Returns [[start, end], ...] for each track's protected zone on a wall
function track_zone_bounds(count, wall_len) =
    [for (i = [0 : count - 1])
        let(seg = wall_len / count,
            c = -wall_len / 2 + seg * (i + 0.5))
        [c - tz_half, c + tz_half]
    ];

// Returns [[start, end], ...] for each free segment (between track zones)
// on the flat portion of a wall
function free_segments(count, wall_len) =
    let(fs = -wall_len / 2 + radius,
        fe = wall_len / 2 - radius)
    count == 0 ? [[fs, fe]] :
    let(z = track_zone_bounds(count, wall_len),
        first = fs < z[0][0] - 0.5 ? [[fs, z[0][0]]] : [],
        middle = count < 2 ? [] :
            [for (i = [0 : count - 2])
                if (z[i][1] < z[i + 1][0] - 0.5)
                    [z[i][1], z[i + 1][0]]
            ],
        last = z[count - 1][1] < fe - 0.5 ? [[z[count - 1][1], fe]] : []
    )
    concat(first, middle, last);

// --- Wave functions ---
// Fitted wave: n full cosine bumps within a segment, starts and ends at 0
function fitted_wave(t, seg_len) =
    let(n = round(seg_len / flute_period))
    n == 0 ? 0 :
    flute_amplitude * (1 - cos(t * 360 * n)) / 2;

// Wave depth at position p along a wall, given its free segments
function wall_wave_depth(p, segs) =
    let(hits = [for (s = segs)
        if (p >= s[0] && p <= s[1])
            fitted_wave((p - s[0]) / (s[1] - s[0]), s[1] - s[0])
    ])
    len(hits) > 0 ? hits[0] : 0;

// Wave for corner arcs (t from 0 to 1 along the quarter circle)
function corner_wave_depth(t) =
    let(arc_len = 3.14159265 * radius / 2)
    fitted_wave(t, arc_len);

// --- Perimeter point generation ---
// Each point: [x, y, outward_nx, outward_ny, wave_depth]

// Bottom wall: left to right, normal pointing down
function bottom_pts() =
    let(segs = free_segments(tracks_bottom, width))
    [for (i = [0 : wall_res - 1])
        let(t = i / (wall_res - 1),
            x = -hw + radius + t * flat_w,
            d = wall_wave_depth(x, segs))
        [x, -hh, 0, -1, d]
    ];

// Right wall: bottom to top, normal pointing right
function right_pts() =
    let(segs = free_segments(tracks_right, height))
    [for (i = [0 : wall_res - 1])
        let(t = i / (wall_res - 1),
            y = -hh + radius + t * flat_h,
            d = wall_wave_depth(y, segs))
        [hw, y, 1, 0, d]
    ];

// Top wall: right to left, normal pointing up
function top_pts() =
    let(segs = free_segments(tracks_top, width))
    [for (i = [0 : wall_res - 1])
        let(t = i / (wall_res - 1),
            x = hw - radius - t * flat_w,
            d = wall_wave_depth(x, segs))
        [x, hh, 0, 1, d]
    ];

// Left wall: top to bottom, normal pointing left
function left_pts() =
    let(segs = free_segments(tracks_left, height))
    [for (i = [0 : wall_res - 1])
        let(t = i / (wall_res - 1),
            y = hh - radius - t * flat_h,
            d = wall_wave_depth(y, segs))
        [-hw, y, -1, 0, d]
    ];

// Corner arc: quarter circle from start_angle, wave wraps around curve
function corner_arc_pts(cx, cy, start_angle) =
    [for (i = [0 : corner_res - 1])
        let(t = i / (corner_res - 1),
            a = start_angle + t * 90,
            nx = cos(a), ny = sin(a),
            d = corner_wave_depth(t))
        [cx + radius * nx, cy + radius * ny, nx, ny, d]
    ];

// Full CCW perimeter: bottom → BR corner → right → TR corner →
//                     top → TL corner → left → BL corner
function perimeter() = concat(
    bottom_pts(),
    corner_arc_pts(hw - radius, -hh + radius, -90),
    right_pts(),
    corner_arc_pts(hw - radius, hh - radius, 0),
    top_pts(),
    corner_arc_pts(-hw + radius, hh - radius, 90),
    left_pts(),
    corner_arc_pts(-hw + radius, -hh + radius, 180)
);

// --- Cut profile polygon ---
module flute_cut_profile() {
    pts = perimeter();
    n = len(pts);

    // Outer boundary: slightly outward for clean boolean subtraction
    outer = [for (p = pts) [p[0] + 0.1 * p[2], p[1] + 0.1 * p[3]]];

    // Inner boundary: inset by wave depth along outward normal
    inner = [for (p = pts) [p[0] - p[4] * p[2], p[1] - p[4] * p[3]]];

    // Single-path polygon: outer CCW then inner CW (reversed)
    polygon(concat(outer, [for (i = [n - 1 : -1 : 0]) inner[i]]));
}

module fluted_shelf() {
    difference() {
        shelf_body(width, height, depth, wall, radius);

        // Wave cut — extruded full depth
        translate([0, 0, -0.1])
            linear_extrude(height = depth + 0.2)
                flute_cut_profile();

        // Track cuts
        horizontal_tracks(tracks_top, width, height / 2, -1);
        horizontal_tracks(tracks_bottom, width, -height / 2, 1);
        vertical_tracks(tracks_right, height, width / 2, -1);
        vertical_tracks(tracks_left, height, -width / 2, 1);
    }
}

fluted_shelf();
