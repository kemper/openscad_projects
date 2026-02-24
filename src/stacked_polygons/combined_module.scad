module stacked_grid(
    shape_type = "polygon",  // "polygon" or "star"
    num_sides = 6,          // Number of sides for polygon
    num_points = 5,         // Number of points for star
    size = 10,              // Size of the shape
    thickness = 3,          // Thickness of the shape's wall
    height = 1,             // Height of each layer
    num_layers = 3,         // Number of stacked layers
    grid_width = 10,        // Number of shapes in the x direction
    grid_height = 10,       // Number of shapes in the y direction
    x_spacing = 25,         // Space between shapes horizontally
    y_spacing = 25,         // Space between shapes vertically
    offset = false,         // Whether to offset every other row
    rotation_angle = 0      // Rotation angle for the shapes
  ) {

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
      linear_extrude(height = height + 0.1) {
        scale([1 - 2 * wall / size, 1 - 2 * wall / size, 1]) {
          polygon(points = regular_polygon_points(size, sides));
        }
      }
    }
  }

  // Module to create a single hollow star with given points
  module hollow_star(points, size, wall, height) {
    difference() {
      linear_extrude(height = height) {
        polygon(points = star_shape(points, size));
      }
      linear_extrude(height = height + 0.1) {
        scale([1 - 2 * wall / size, 1 - 2 * wall / size, 1]) {
          polygon(points = star_shape(points, size));
        }
      }
    }
  }

  // Loop to create the grid of shapes
  for (i = [0 : grid_width - 1]) {
    for (j = [0 : grid_height - 1]) {
      x_offset = i * x_spacing + (offset ? (j % 2 ? x_spacing / 2 : 0) : 0);
      y_offset = j * y_spacing;

      // Create the stacked layers
      for (k = [0 : num_layers - 1]) {
        translate([x_offset, y_offset, k * height]) {
          rotate([0, 0, rotation_angle]) {
            if (shape_type == "polygon") {
              hollow_polygon(num_sides, size - k, thickness - k, height);
            } else if (shape_type == "star") {
              hollow_star(num_points, size - k, thickness - k, height);
            } else {
              echo("Error: Invalid shape_type.  Must be 'polygon' or 'star'.");
            }
          }
        }
      }
    }
  }
}

// Example usage:
// stacked_grid(shape_type = "star", num_points = 5, size = 10, thickness = 3, height = 1, num_layers = 3, grid_width = 5, grid_height = 5, x_spacing = 25, y_spacing = 30, offset = true);

stacked_grid(shape_type = "polygon", num_sides = 6, size = 10, thickness = 4, height = 1, num_layers = 4, grid_width = 15, grid_height = 15, x_spacing = 19.5, y_spacing = 17, offset = true, rotation_angle = 30);


/*
stacked_grid(shape_type = "star", num_sides = 6, size = 6, thickness = 4, height = 1, num_layers = 4, grid_width = 3, grid_height = 3, x_spacing = 15, y_spacing = 10, offset = true, rotation_angle = 90);
*/