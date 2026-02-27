#!/usr/bin/env python3
"""Combine multiple STL files into a single multi-color 3MF.

Each STL becomes a separate object with an assigned color, which slicers
like Bambu Studio map to filament slots.

Usage:
    stls_to_3mf.py -o output.3mf body.stl:#808080 accent.stl:#4169e1

    Each argument is a path:color pair. Colors are hex RGB (e.g. #ff0000).
"""

import argparse
import ctypes
import struct
import sys
from pathlib import Path


def parse_stl_binary(path):
    """Parse a binary STL file, returning (vertices, triangles)."""
    data = Path(path).read_bytes()

    # Check if ASCII STL (starts with "solid")
    if data[:5] == b"solid" and b"\x00" not in data[:80]:
        return parse_stl_ascii(path)

    # Binary STL: 80-byte header, 4-byte triangle count, then triangles
    num_triangles = struct.unpack_from("<I", data, 80)[0]
    offset = 84

    vertices = []
    triangles = []
    vertex_map = {}

    for _ in range(num_triangles):
        # Skip normal (12 bytes), read 3 vertices (36 bytes), skip attr (2 bytes)
        nx, ny, nz = struct.unpack_from("<fff", data, offset)
        offset += 12

        tri_indices = []
        for _ in range(3):
            x, y, z = struct.unpack_from("<fff", data, offset)
            offset += 12
            key = (x, y, z)
            if key not in vertex_map:
                vertex_map[key] = len(vertices)
                vertices.append(key)
            tri_indices.append(vertex_map[key])

        triangles.append(tuple(tri_indices))
        offset += 2  # attribute byte count

    return vertices, triangles


def parse_stl_ascii(path):
    """Parse an ASCII STL file, returning (vertices, triangles)."""
    text = Path(path).read_text()
    vertices = []
    triangles = []
    vertex_map = {}
    current_tri = []

    for line in text.splitlines():
        parts = line.strip().split()
        if len(parts) == 4 and parts[0] == "vertex":
            x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
            key = (x, y, z)
            if key not in vertex_map:
                vertex_map[key] = len(vertices)
                vertices.append(key)
            current_tri.append(vertex_map[key])
        elif parts and parts[0] == "endfacet" and len(current_tri) == 3:
            triangles.append(tuple(current_tri))
            current_tri = []

    return vertices, triangles


def hex_to_rgba(hex_color):
    """Convert '#rrggbb' to (r, g, b, a) tuple."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return r, g, b, 255


def build_3mf(parts, output_path):
    """Build a multi-color 3MF from a list of (stl_path, hex_color) tuples."""
    import lib3mf

    wrapper = lib3mf.Wrapper()
    model = wrapper.CreateModel()
    model.SetUnit(lib3mf.ModelUnit.MilliMeter)

    # Create a base material group with one material per part
    mat_group = model.AddBaseMaterialGroup()
    material_ids = []
    for _, hex_color in parts:
        rgba = hex_to_rgba(hex_color)
        color = wrapper.RGBAToColor(*rgba)
        name = Path(_).stem
        mat_id = mat_group.AddMaterial(name, color)
        material_ids.append(mat_id)

    # Add each STL as a mesh object
    for i, (stl_path, hex_color) in enumerate(parts):
        vertices, triangles = parse_stl_binary(stl_path)

        mesh = model.AddMeshObject()
        mesh.SetName(Path(stl_path).stem)

        # Build position/triangle arrays for SetGeometry
        positions = [lib3mf.Position(v) for v in vertices]
        tri_structs = [lib3mf.Triangle(t) for t in triangles]
        mesh.SetGeometry(positions, tri_structs)

        # Assign material to all triangles
        prop = lib3mf.TriangleProperties()
        prop.ResourceID = mat_group.GetResourceID()
        prop.PropertyIDs = (ctypes.c_uint32 * 3)(material_ids[i], material_ids[i], material_ids[i])
        for j in range(len(triangles)):
            mesh.SetTriangleProperties(j, prop)

        # Set default property so slicer picks up the color
        mesh.SetObjectLevelProperty(mat_group.GetResourceID(), material_ids[i])

        # Add to build
        model.AddBuildItem(mesh, wrapper.GetIdentityTransform())

    # Write 3MF
    writer = model.QueryWriter("3mf")
    writer.WriteToFile(str(output_path))
    print(f"Wrote {output_path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-o", "--output", required=True, help="Output 3MF file path")
    parser.add_argument("parts", nargs="+",
                        help="STL:color pairs (e.g. body.stl:#808080)")
    args = parser.parse_args()

    parts = []
    for part_spec in args.parts:
        if ":" not in part_spec:
            parser.error(f"Expected path:color format, got: {part_spec}")
        stl_path, color = part_spec.rsplit(":", 1)
        if not Path(stl_path).exists():
            parser.error(f"STL file not found: {stl_path}")
        if not color.startswith("#") or len(color) != 7:
            parser.error(f"Color must be #rrggbb format, got: {color}")
        parts.append((stl_path, color))

    build_3mf(parts, args.output)


if __name__ == "__main__":
    main()
