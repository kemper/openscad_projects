// Tapered Parametric Lampshade using Grid Pattern Technique
// Parameters for the lampshade
top_diameter = 60;        // Diameter at the top of the lampshade
bottom_diameter = 120;    // Diameter at the bottom of the lampshade
lamp_height = 150;        // Height of the lampshade
wall_thickness = 2;       // Thickness of the base wall

// Pattern parameters
shape_type = "polygon";   // "polygon" or "star"
num_sides = 6;            // Number of sides for polygon
num_points = 5;           // Number of points for star
pattern_size_factor = 0.12; // Pattern size as a factor of local diameter
pattern_thickness = 2;    // Thickness of the pattern walls
pattern_depth = 3;        // How much the pattern extends from the surface
vertical_count = 8;       // Number of pattern elements vertically
horizontal_count = 12;    // Number of pattern elements horizontally
vertical_offset = true;   // Whether to offset alternate rows

// Top and bottom ring parameters
ring_height = 10;         // Height of the solid rings at top and bottom
has_top_ring = true;      // Whether to include a solid ring at the top
has_bottom_ring = true;   // Whether to include a solid ring at the bottom
include_bottom = false;   // Whether to include a bottom surface (false for open bottom)

// Light bulb parameters
bulb_holder_diameter = 30;  // Diameter of bulb holder opening

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

// Module for the tapered base shape of the lampshade
module tapered_lampshade_base() {
  difference() {
    // Outer tapered cylinder
    cylinder(h = lamp_height, d1 = bottom_diameter, d2 = top_diameter, center = false, $fn=60);
    
    // Inner tapered cylinder (hollowing out)
    translate([0, 0, -0.1])
      cylinder(h = lamp_height + 0.2, d1 = bottom_diameter - wall_thickness*2, d2 = top_diameter - wall_thickness*2, center = false, $fn=60);
    
    // Remove the top if no top ring
    if (!has_top_ring) {
      translate([0, 0, lamp_height - ring_height])
        cylinder(h = ring_height + 0.1, d = top_diameter + 1, center = false, $fn=60);
    }
    
    // Remove the bottom if no bottom ring
    if (!has_bottom_ring) {
      translate([0, 0, -0.1])
        cylinder(h = ring_height + 0.1, d = bottom_diameter + 1, center = false, $fn=60);
    }
    
    // Remove the bottom face if not including bottom
    if (!include_bottom) {
      translate([0, 0, -0.1])
        cylinder(h = wall_thickness + 0.2, d = bottom_diameter - wall_thickness*2, center = false, $fn=60);
    }
    
    // Add bulb holder opening if including bottom
    if (include_bottom) {
      translate([0, 0, -0.1])
        cylinder(h = wall_thickness + 0.2, d = bulb_holder_diameter, center = false, $fn=30);
    }
  }
}

// Module to create the complete lampshade with patterns
module tapered_lampshade() {
  difference() {
    // Base lampshade
    tapered_lampshade_base();
    
    // Calculate spacing
    vertical_step = (lamp_height - (has_top_ring ? ring_height : 0) - (has_bottom_ring ? ring_height : 0)) / vertical_count;
    horizontal_step = 360 / horizontal_count;
    
    // Pattern area
    pattern_start_height = has_bottom_ring ? ring_height : 0;
    pattern_end_height = lamp_height - (has_top_ring ? ring_height : 0);
    
    // Create the grid pattern
    for (v = [0 : vertical_count - 1]) {
      v_pos = pattern_start_height + vertical_step/2 + v * vertical_step;
      
      // Calculate the local diameter at this height
      local_diameter = bottom_diameter - (v_pos / lamp_height) * (bottom_diameter - top_diameter);
      
      // Calculate pattern size based on local diameter
      local_pattern_size = local_diameter * pattern_size_factor;
      
      // Calculate horizontal offset for this row
      offset = (vertical_offset && v % 2 == 1) ? horizontal_step / 2 : 0;
      
      for (h = [0 : horizontal_count - 1]) {
        h_angle = offset + h * horizontal_step;
        
        // Position for the pattern on tapered cylinder
        translate([
          (local_diameter/2) * cos(h_angle),
          (local_diameter/2) * sin(h_angle),
          v_pos
        ])
        rotate([90, 0, h_angle]) 
        translate([0, 0, -pattern_depth/2]) {
          // Choose the shape based on parameter
          if (shape_type == "polygon") {
            hollow_polygon(num_sides, local_pattern_size, pattern_thickness, pattern_depth);
          } else if (shape_type == "star") {
            hollow_star(num_points, local_pattern_size, pattern_thickness, pattern_depth);
          }
        }
      }
    }
  }
}

// Render the lampshade
tapered_lampshade();
