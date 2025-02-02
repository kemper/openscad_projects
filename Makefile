# Using a make command called build, loop over all scad files in the src directory and generate stl files in the dist directory but using the same filename
build:
	@for file in src/*.scad; do \
		echo "Building $$file"; \
		openscad -o dist/$$(basename $$file .scad).stl $$file; \
	done

