// Parameters for the polygon grid

num_sides = 8;    // Number of sides of the polygon (e.g., 6 for hexagon, 4 for square, etc.)
poly_size = 10;   // Size of the outer polygon (side length)
grid_width = 10;    // Number of polygons in the x direction
grid_height = 10;   // Number of polygons in the y direction
spacing = 25;      // Space between polygons
wall_thickness = 3; // Thickness of the polygon wall
num_layers = 3;    // Number of stacked layers of hollow polygons

// Function to create a single hollow polygon with arbitrary sides
module hollow_polygon(sides, size, wall, height) { // Added height parameter
  difference() {
    linear_extrude(height = height) { // Extrude the outer polygon
      polygon(points=regular_polygon_points(size, sides));
    }
    linear_extrude(height = height + 0.1) { // Extrude the inner polygon (slightly more to ensure clean difference)
      scale([1 - 2 * wall / size, 1 - 2 * wall / size, 1]) {
        polygon(points=regular_polygon_points(size, sides));
      }
    }
  }
}

function regular_polygon_points(size, sides) = // sides is now a parameter
  [for (i = [0 : sides - 1]) [size * cos(i * 360 / sides), size * sin(i * 360 / sides)]];

// Loop to create the grid of polygons
for (i = [0 : grid_width - 1]) {
  for (j = [0 : grid_height - 1]) {
    x_offset = i * spacing;
    y_offset = j * spacing;


    rotation_angle = 180 / num_sides;
            
    // Create the stacked layers
    for (k = [0 : num_layers - 1]) {
      translate([x_offset, y_offset, k]) {
        rotate([0, 0, rotation_angle]) {
          hollow_polygon(num_sides, poly_size - k, wall_thickness - k, 1);
        }
      }
    }
  }
}
