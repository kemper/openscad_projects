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
	@echo "3mf             - build a multi-color 3MF (usage: see Makefile for examples)"
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

# --- Multi-color 3MF ---
# Builds a multi-color 3MF from a .scad file that supports part="..." selection.
# The scad file must define parts that can be rendered individually via -D 'part="name"'.
# Usage: make 3mf file=src/shelf/shelf_two_color.scad parts="body:#808080 accent:#4169e1"
3mf:
	@echo "Building multi-color 3MF from $(file)"
	@mkdir -p dist/$(dir $(patsubst src/%.scad,%,$(file)))
	@for spec in $(parts); do \
		name=$${spec%%:*}; \
		color=$${spec#*:}; \
		echo "  Rendering part: $$name ($$color)"; \
		$(OPENSCAD) -D "part=\"$$name\"" -o tmp/part_$$name.stl $(file); \
	done
	@$(PYTHON) scripts/stls_to_3mf.py -o tmp/intermediate.3mf \
		$(foreach spec,$(parts),tmp/part_$(firstword $(subst :, ,$(spec))).stl:$(lastword $(subst :, ,$(spec))))
	@$(PYTHON) scripts/bambu_3mf.py -o dist/$(patsubst src/%.scad,%.3mf,$(file)) tmp/intermediate.3mf
	@rm -f tmp/intermediate.3mf $(foreach spec,$(parts),tmp/part_$(firstword $(subst :, ,$(spec))).stl)
	@echo "Created dist/$(patsubst src/%.scad,%.3mf,$(file))"
