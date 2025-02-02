// Parameters for the star grid
num_points = 5;       // Number of points of the star
star_size = 10;       // Size of the outer star (distance from center to outer point)
star_thickness = 3;   // Thickness of the star wall
star_height = 3;      // Height of each star layer
num_layers = 3;       // Number of stacked layers of hollow stars
grid_width = 10;      // Number of stars in the x direction
grid_height = 10;     // Number of stars in the y direction
spacing = 25;         // Space between stars

// Function to generate the points for a star shape
function star_shape(points, size) = 
  [for (i = [0 : points * 2 - 1]) 
    let (angle = i * 180 / points, r = i % 2 ? size / 2 : size)
    [r * cos(angle), r * sin(angle)]];

// Module to create a single hollow star with given points
module hollow_star(points, size, wall, height) {
  difference() {
    linear_extrude(height = height) { // Extrude the outer star
      polygon(points = star_shape(points, size));
    }
    linear_extrude(height = height + 0.1) { // Extrude the inner star (slightly more to ensure clean difference)
      scale([1 - 2 * wall / size, 1 - 2 * wall / size, 1]) {
        polygon(points = star_shape(points, size));
      }
    }
  }
}

// Loop to create the grid of stars
for (i = [0 : grid_width - 1]) {
  for (j = [0 : grid_height - 1]) {
    x_offset = i * spacing + (j % 2) * (spacing / 2); // Offset every other row by 50% of the spacing
    y_offset = j * spacing;

    // Create the stacked layers
    for (k = [0 : num_layers - 1]) {
      translate([x_offset, y_offset, k * star_height]) {
        rotate([0, 0, 45]) { // Rotate 45 degrees to orient like diamonds
          hollow_star(num_points, star_size - k, star_thickness - k, star_height);
        }
      }
    }
  }
}