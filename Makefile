help:
	@echo "build - generate stl files from scad files in the src directory"
	@echo "build_one - generate a stl file from a single scad file"
	@echo "preview - generate a png preview of a scad file (usage: make preview file=src/shelf.scad)"

STL_FILES := $(patsubst src/%.scad,dist/%.stl,$(wildcard src/*.scad))

build: $(STL_FILES)

dist/%.stl: src/%.scad
	@echo "Building $<"
	@openscad -o $@ $<

# take a path to a scad file and generate a stl file in the dist directory
# example use: make build_one file=src/box.scad
build_one:
	@echo "Building $(file)"
	@openscad -o dist/$$(basename $(file) .scad).stl $(file)

# generate a png preview for visual verification
# example use: make preview file=src/shelf.scad
preview:
	@echo "Rendering preview of $(file)"
	@openscad -o tmp/preview.png --imgsize=1024,768 --viewall --autocenter --projection=p $(file)
