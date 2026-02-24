// Simple Parametric Lampshade using Grid Pattern Technique
// Parameters for the lampshade
lamp_diameter = 100;      // Diameter of the lampshade
lamp_height = 120;        // Height of the lampshade
wall_thickness = 2;       // Thickness of the base wall

// Pattern parameters
shape_type = "polygon";   // "polygon" or "star"
num_sides = 6;            // Number of sides for polygon
num_points = 5;           // Number of points for star
pattern_size = 15;        // Size of the pattern elements
pattern_thickness = 2;    // Thickness of the pattern walls
pattern_depth = 3;        // How much the pattern extends from the surface
vertical_count = 8;       // Number of pattern elements vertically (reduced for faster rendering)
horizontal_count = 12;    // Number of pattern elements horizontally (reduced for faster rendering)

// Top and bottom ring parameters
ring_height = 10;         // Height of the solid rings at top and bottom
has_top_ring = true;      // Whether to include a solid ring at the top
has_bottom_ring = true;   // Whether to include a solid ring at the bottom
include_bottom = true;    // Whether to include a bottom surface

// Function to generate the points for a regular polygon
function regular_polygon_points(size, sides) =
  [for (i = [0 : sides - 1]) [size * cos(i * 360 / sides), size * sin(i * 360 / sides)]];

// Function to generate the points for a star shape
function star_shape(points, size) =
  [for (i = [0 : points * 2 - 1])
    let (angle = i * 180 / points, r = i % 2 ? size / 2 : size)
    [r * cos(angle), r * sin(angle)]];

// Module to create a single hollow polygon with arbitrary sides
module hollow_polygon(sides, size, wall, height) {
  difference() {
    linear_extrude(height = height) {
      polygon(points = regular_polygon_points(size, sides));
    }
    translate([0, 0, -0.05])
    linear_extrude(height = height + 0.1) {
      polygon(points = regular_polygon_points(size - wall*2, sides));
    }
  }
}

// Module to create a single hollow star
module hollow_star(points, size, wall, height) {
  difference() {
    linear_extrude(height = height) {
      polygon(points = star_shape(points, size));
    }
    translate([0, 0, -0.05])
    linear_extrude(height = height + 0.1) {
      polygon(points = star_shape(points, size - wall*2));
    }
  }
}

// Module for the base cylindrical shape of the lampshade
module lampshade_base() {
  difference() {
    cylinder(h = lamp_height, d = lamp_diameter, center = false, $fn=60);
    translate([0, 0, -0.1])
      cylinder(h = lamp_height + 0.2, d = lamp_diameter - wall_thickness*2, center = false, $fn=60);
    
    // Remove the top if no top ring
    if (!has_top_ring) {
      translate([0, 0, lamp_height - ring_height])
        cylinder(h = ring_height + 0.1, d = lamp_diameter + 1, center = false, $fn=60);
    }
    
    // Remove the bottom if no bottom ring
    if (!has_bottom_ring) {
      translate([0, 0, -0.1])
        cylinder(h = ring_height + 0.1, d = lamp_diameter + 1, center = false, $fn=60);
    }
    
    // Remove the bottom face if not including bottom
    if (!include_bottom) {
      translate([0, 0, -0.1])
        cylinder(h = wall_thickness + 0.2, d = lamp_diameter - wall_thickness*2, center = false, $fn=60);
    }
  }
}

// Module to create the complete lampshade with patterns
module lampshade() {
  difference() {
    // Base lampshade
    lampshade_base();
    
    // Calculate spacing
    vertical_step = (lamp_height - (has_top_ring ? ring_height : 0) - (has_bottom_ring ? ring_height : 0)) / vertical_count;
    horizontal_step = 360 / horizontal_count;
    
    // Pattern area
    pattern_start_height = has_bottom_ring ? ring_height : 0;
    pattern_end_height = lamp_height - (has_top_ring ? ring_height : 0);
    
    // Create the grid pattern
    for (v = [0 : vertical_count - 1]) {
      v_pos = pattern_start_height + vertical_step/2 + v * vertical_step;
      
      for (h = [0 : horizontal_count - 1]) {
        h_angle = h * horizontal_step;
        
        // Position for the pattern on cylinder
        translate([
          (lamp_diameter/2) * cos(h_angle),
          (lamp_diameter/2) * sin(h_angle),
          v_pos
        ])
        rotate([90, 0, h_angle]) 
        translate([0, 0, -pattern_depth/2]) {
          // Choose the shape based on parameter
          if (shape_type == "polygon") {
            hollow_polygon(num_sides, pattern_size, pattern_thickness, pattern_depth);
          } else if (shape_type == "star") {
            hollow_star(num_points, pattern_size, pattern_thickness, pattern_depth);
          }
        }
      }
    }
  }
}

// Render the lampshade
lampshade();
