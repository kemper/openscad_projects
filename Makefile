OPENSCAD := openscad
F3D := f3d
F3D_FLAGS := --resolution=1024,768 --no-background --up=+Z --filename=false --grid=false --axis=false -q
PYTHON := .venv/bin/python

help:
	@echo "build           - build all .scad files to .stl (mirrors src/ structure into dist/)"
	@echo "build dir=X     - build all .scad files in src/X/"
	@echo "build_one       - build a single .scad file (usage: make build_one file=src/shelf/shelf.scad)"
	@echo "previews        - generate png previews for all .scad files (mirrors src/ structure into previews/)"
	@echo "previews dir=X  - generate png previews for all .scad files in src/X/"
	@echo "preview         - generate a single png preview to tmp/ (usage: make preview file=src/shelf/shelf.scad)"
	@echo ""
	@echo "Subdirectories:"
	@ls -d src/*/ 2>/dev/null | sed 's|src/||;s|/||'

# Find all .scad files recursively under src/
SCAD_FILES := $(shell find src -name '*.scad')
STL_FILES := $(patsubst src/%.scad,dist/%.stl,$(SCAD_FILES))
PREVIEW_FILES := $(patsubst src/%.scad,previews/%.png,$(SCAD_FILES))

# Filter to a specific subdirectory if dir= is set
ifdef dir
STL_FILES := $(filter dist/$(dir)/%,$(STL_FILES))
PREVIEW_FILES := $(filter previews/$(dir)/%,$(PREVIEW_FILES))
endif

build: $(STL_FILES)

# Pattern rule: mirrors src/ directory structure into dist/
dist/%.stl: src/%.scad
	@mkdir -p $(dir $@)
	@echo "Building $<"
	@$(OPENSCAD) -o $@ $<

# Build a single file (usage: make build_one file=src/shelf/shelf.scad)
build_one:
	@mkdir -p $(dir $(patsubst src/%.scad,dist/%.stl,$(file)))
	@echo "Building $(file)"
	@$(OPENSCAD) -o $(patsubst src/%.scad,dist/%.stl,$(file)) $(file)

previews: $(PREVIEW_FILES)

# Two-stage preview: OpenSCAD renders STL, F3D produces a clean PNG
previews/%.png: src/%.scad
	@mkdir -p $(dir $@)
	@echo "Rendering preview of $<"
	@$(OPENSCAD) -o $(basename $@).stl $<
	@$(F3D) $(basename $@).stl --output=$@ $(F3D_FLAGS)
	@rm -f $(basename $@).stl

# Generate a single png preview to tmp/ for quick visual verification
# (usage: make preview file=src/shelf/shelf.scad)
preview:
	@echo "Rendering preview of $(file)"
	@$(OPENSCAD) -o tmp/preview.stl $(file)
	@$(F3D) tmp/preview.stl --output=tmp/preview.png $(F3D_FLAGS)
	@rm -f tmp/preview.stl
