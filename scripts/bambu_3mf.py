#!/usr/bin/env python3
"""Convert a standard 3MF into a Bambu Studio compatible format.

Takes a lib3mf-generated (or any standard) 3MF and restructures it with
Bambu's model_settings.config for proper multi-color extruder assignments.

Supports two modes:
  - Painted mode (default): Merges all objects into a single mesh with
    per-triangle paint_color attributes using Bambu's TriangleSelector encoding.
  - Multi-object mode (--multi-object): Keeps separate objects, each assigned
    to an extruder via model_settings.config.

On first open, Bambu Studio shows a dismissible "not from Bambu Lab" dialog
with a "don't show again" checkbox. After that, files load silently with
all extruder/color assignments preserved and the user's default presets.

Usage:
    bambu_3mf.py -o output.3mf input.3mf
    bambu_3mf.py --multi-object -o output.3mf input.3mf
    bambu_3mf.py --no-thumbnails -o output.3mf input.3mf

Requires only the Python standard library. Optionally uses F3D for thumbnails.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass, field
from pathlib import Path


# 3MF core namespace
NS_3MF = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
NS_P = "http://schemas.microsoft.com/3dmanufacturing/production/2015/06"


@dataclass
class MeshObject:
    """A single mesh extracted from the input 3MF."""
    name: str
    obj_id: int
    vertices: list  # [(x, y, z), ...]
    triangles: list  # [(v1, v2, v3), ...]
    color: str  # hex color like "#808080"
    transform: str = ""  # build item transform


@dataclass
class ParsedModel:
    """All data extracted from an input 3MF."""
    objects: list = field(default_factory=list)  # [MeshObject, ...]
    unit: str = "millimeter"


def parse_input_3mf(path):
    """Parse a standard 3MF file into a ParsedModel."""
    model = ParsedModel()

    with zipfile.ZipFile(path, "r") as zf:
        # Find the main model file
        model_path = _find_model_path(zf)
        tree = ET.parse(zf.open(model_path))
        root = tree.getroot()

        # Extract unit
        unit = root.get("unit", "millimeter")
        model.unit = unit

        # Build color map from basematerials
        color_map = _extract_color_map(root)

        # Extract all resources (objects may reference other objects via components)
        all_objects = {}
        for obj_elem in root.iter(f"{{{NS_3MF}}}object"):
            obj_id = int(obj_elem.get("id"))
            obj_name = obj_elem.get("name", f"object_{obj_id}")

            # Determine color from object-level property
            pid = obj_elem.get("pid")
            pindex = obj_elem.get("pindex")
            obj_color = None
            if pid and pindex:
                obj_color = color_map.get((int(pid), int(pindex)))

            mesh_elem = obj_elem.find(f"{{{NS_3MF}}}mesh")
            if mesh_elem is not None:
                vertices, triangles, tri_color = _parse_mesh(mesh_elem, color_map)
                color = obj_color or tri_color or "#808080"
                all_objects[obj_id] = MeshObject(
                    name=obj_name,
                    obj_id=obj_id,
                    vertices=vertices,
                    triangles=triangles,
                    color=color,
                )
            else:
                # Component reference — resolve later
                all_objects[obj_id] = obj_elem

        # Resolve components and collect build items
        build_items = []
        for item in root.iter(f"{{{NS_3MF}}}item"):
            obj_id = int(item.get("objectid"))
            transform = item.get("transform", "")
            resolved = _resolve_object(obj_id, all_objects, zf, model_path, color_map)
            for mesh_obj in resolved:
                mesh_obj.transform = transform
                build_items.append(mesh_obj)

        model.objects = build_items

    return model


def _find_model_path(zf):
    """Find the main 3D model file in the archive."""
    names = zf.namelist()
    if "3D/3dmodel.model" in names:
        return "3D/3dmodel.model"
    for name in names:
        if name.endswith(".model"):
            return name
    raise ValueError("No .model file found in 3MF archive")


def _extract_color_map(root):
    """Build a map of (resource_id, index) -> hex color from basematerials."""
    color_map = {}
    for bm in root.iter(f"{{{NS_3MF}}}basematerials"):
        res_id = int(bm.get("id"))
        for i, base in enumerate(bm.findall(f"{{{NS_3MF}}}base")):
            display_color = base.get("displaycolor", "#808080")
            # Normalize to 7-char hex
            if len(display_color) == 9:  # #RRGGBBAA
                display_color = display_color[:7]
            color_map[(res_id, i)] = display_color
    return color_map


def _parse_mesh(mesh_elem, color_map):
    """Parse vertices and triangles from a mesh element.

    Returns (vertices, triangles, dominant_color).
    """
    vertices = []
    for v in mesh_elem.iter(f"{{{NS_3MF}}}vertex"):
        vertices.append((
            float(v.get("x")),
            float(v.get("y")),
            float(v.get("z")),
        ))

    triangles = []
    color_votes = {}
    for t in mesh_elem.iter(f"{{{NS_3MF}}}triangle"):
        v1 = int(t.get("v1"))
        v2 = int(t.get("v2"))
        v3 = int(t.get("v3"))
        triangles.append((v1, v2, v3))

        # Check per-triangle color
        pid = t.get("pid")
        p1 = t.get("p1")
        if pid and p1:
            c = color_map.get((int(pid), int(p1)))
            if c:
                color_votes[c] = color_votes.get(c, 0) + 1

    # Most common color wins
    dominant = None
    if color_votes:
        dominant = max(color_votes, key=color_votes.get)

    return vertices, triangles, dominant


def _resolve_object(obj_id, all_objects, zf, model_path, color_map):
    """Resolve an object ID to a list of MeshObjects, following component refs."""
    obj = all_objects.get(obj_id)
    if obj is None:
        return []
    if isinstance(obj, MeshObject):
        return [obj]

    # It's an ET element with components
    results = []
    components = obj.find(f"{{{NS_3MF}}}components")
    if components is not None:
        for comp in components.findall(f"{{{NS_3MF}}}component"):
            ref_id = int(comp.get("objectid"))
            p_path = comp.get(f"{{{NS_P}}}path") or comp.get("path")
            if p_path:
                sub_objects = _parse_sub_model(zf, p_path, ref_id, color_map)
                results.extend(sub_objects)
            else:
                results.extend(
                    _resolve_object(ref_id, all_objects, zf, model_path, color_map)
                )
    return results


def _parse_sub_model(zf, sub_path, ref_id, color_map):
    """Parse a sub-model file referenced by a component."""
    sub_path = sub_path.lstrip("/")
    if sub_path not in zf.namelist():
        return []

    tree = ET.parse(zf.open(sub_path))
    root = tree.getroot()

    sub_colors = _extract_color_map(root)
    merged = {**color_map, **sub_colors}

    for obj_elem in root.iter(f"{{{NS_3MF}}}object"):
        oid = int(obj_elem.get("id"))
        if oid == ref_id:
            mesh_elem = obj_elem.find(f"{{{NS_3MF}}}mesh")
            if mesh_elem is not None:
                name = obj_elem.get("name", f"object_{oid}")
                pid = obj_elem.get("pid")
                pindex = obj_elem.get("pindex")
                obj_color = None
                if pid and pindex:
                    obj_color = merged.get((int(pid), int(pindex)))
                vertices, triangles, tri_color = _parse_mesh(mesh_elem, merged)
                return [MeshObject(
                    name=name,
                    obj_id=oid,
                    vertices=vertices,
                    triangles=triangles,
                    color=obj_color or tri_color or "#808080",
                )]
    return []


def map_colors_to_extruders(objects):
    """Assign unique colors to extruder numbers (1-based).

    Returns dict: color -> extruder_number.
    """
    seen = {}
    for obj in objects:
        if obj.color not in seen:
            seen[obj.color] = len(seen) + 1
    return seen


# ---------------------------------------------------------------------------
# paint_color encoding (Bambu TriangleSelector quadtree leaf format)
# ---------------------------------------------------------------------------

def encode_paint_color(state):
    """Encode a TriangleSelector state as a Bambu paint_color attribute string.

    State 0 = default extruder (omit attribute).
    State 1..N = explicitly assign to extruder 1..N.

    The encoding is a reversed hex-nibble string representing a quadtree leaf:
      - 4 bits per nibble (LSB-first): split_sides(2), state(2)
      - For states 0-2: single nibble (0, 4, 8)
      - For states 3+: marker nibble C + extension nibble(s)
    """
    if state == 0:
        return ""
    if state <= 2:
        # Direct leaf: split_sides=0 (00), state in 2 bits
        # LSB-first nibble: bit0=split_lo, bit1=split_hi, bit2=state_lo, bit3=state_hi
        nibble = (state & 1) * 4 + ((state >> 1) & 1) * 8
        return format(nibble, "X")

    # Extended: initial nibble has state=3 marker (C), then extension nibble(s)
    # Extended value = actual_state - 3
    ext_value = state - 3
    nibbles = ["C"]
    while ext_value >= 15:
        nibbles.append("F")
        ext_value -= 15
    nibbles.append(format(ext_value, "X"))
    # Bambu reverses the nibble string (characters are prepended during serialization)
    return "".join(reversed(nibbles))


def merge_objects_painted(objects, extruder_map):
    """Merge multiple objects into a single mesh with per-triangle paint_color.

    The most common color becomes the default extruder (no paint_color needed).
    Other colors get explicit paint_color attributes encoding their extruder number.

    Returns (merged_mesh, paint_colors_list, default_extruder_num).
    """
    # Find the most common color by triangle count
    color_tri_count = {}
    for obj in objects:
        color_tri_count[obj.color] = color_tri_count.get(obj.color, 0) + len(obj.triangles)

    default_color = max(color_tri_count, key=color_tri_count.get)
    default_extruder = extruder_map[default_color]

    # Merge all vertices and triangles, tracking paint_color per triangle
    all_vertices = []
    all_triangles = []
    paint_colors = []

    for obj in objects:
        offset = len(all_vertices)
        all_vertices.extend(obj.vertices)
        ext_num = extruder_map[obj.color]

        # Default extruder triangles get no paint_color (state 0)
        # Other extruder triangles get paint_color = encode(extruder_number)
        if ext_num == default_extruder:
            pc = ""
        else:
            pc = encode_paint_color(ext_num)

        for v1, v2, v3 in obj.triangles:
            all_triangles.append((v1 + offset, v2 + offset, v3 + offset))
            paint_colors.append(pc)

    merged = MeshObject(
        name="merged",
        obj_id=1,
        vertices=all_vertices,
        triangles=all_triangles,
        color=default_color,
        transform=objects[0].transform if objects else "",
    )

    return merged, paint_colors, default_extruder


def generate_thumbnails(input_path, f3d_cmd="f3d"):
    """Generate thumbnail PNGs from the input 3MF using F3D.

    Returns dict: filename -> png_bytes.
    """
    sizes = [
        ("plate_1.png", 512, 512),
        ("plate_1_tall.png", 256, 256),
        ("plate_1_small.png", 128, 128),
    ]
    thumbnails = {}

    with tempfile.TemporaryDirectory() as tmpdir:
        for filename, w, h in sizes:
            out_path = os.path.join(tmpdir, filename)
            try:
                subprocess.run(
                    [
                        f3d_cmd, str(input_path),
                        f"--resolution={w},{h}",
                        "--no-background",
                        "--up=+Z",
                        "--filename=false",
                        "--grid=false",
                        "--axis=false",
                        "-q",
                        f"--output={out_path}",
                    ],
                    check=True,
                    capture_output=True,
                )
                thumbnails[filename] = Path(out_path).read_bytes()
            except (subprocess.CalledProcessError, FileNotFoundError):
                # F3D not available or failed — skip thumbnails
                break

    return thumbnails


# ---------------------------------------------------------------------------
# Bambu 3MF XML generation (string templates for precise namespace control)
# ---------------------------------------------------------------------------

def _build_content_types():
    """Build [Content_Types].xml."""
    return """\
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml" />
  <Default Extension="png" ContentType="image/png" />
</Types>"""


def _build_root_rels(has_thumbnails):
    """Build _rels/.rels."""
    rels = [
        '  <Relationship Target="/3D/3dmodel.model" Id="rel-1" '
        'Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel" />',
    ]
    if has_thumbnails:
        rels.append(
            '  <Relationship Target="/Metadata/plate_1.png" Id="rel-2" '
            'Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail" />'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        + "\n".join(rels) + "\n"
        '</Relationships>'
    )


def _build_model_rels(num_objects):
    """Build 3D/_rels/3dmodel.model.rels referencing sub-object files."""
    rels = []
    for i in range(1, num_objects + 1):
        rels.append(
            f'  <Relationship Target="/3D/Objects/object_{i}.model" '
            f'Id="rel-{i}" '
            f'Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel" />'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        + "\n".join(rels) + "\n"
        '</Relationships>'
    )


def _build_main_model(objects, unit="millimeter"):
    """Build the main 3D/3dmodel.model with component references to sub-objects.

    Deliberately does NOT claim to be from BambuStudio — this avoids preset
    import issues. Extruder assignments come from model_settings.config which
    is always loaded regardless of file origin.
    """
    obj_defs = []
    for i, obj in enumerate(objects, 1):
        obj_defs.append(
            f'    <object id="{i}" type="model">\n'
            f'      <components>\n'
            f'        <component p:path="/3D/Objects/object_{i}.model" objectid="1" transform="1 0 0 0 1 0 0 0 1 0 0 0" />\n'
            f'      </components>\n'
            f'    </object>'
        )

    items = []
    for i, obj in enumerate(objects, 1):
        transform = obj.transform if obj.transform else "1 0 0 0 1 0 0 0 1 0 0 0"
        items.append(
            f'    <item objectid="{i}" transform="{transform}" printable="1" />'
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<model unit="' + unit + '" xml:lang="en-US"\n'
        '  xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"\n'
        '  xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06"\n'
        '  requiredextensions="p">\n'
        '  <resources>\n'
        + "\n".join(obj_defs) + "\n"
        '  </resources>\n'
        '  <build>\n'
        + "\n".join(items) + "\n"
        '  </build>\n'
        '</model>'
    )


def _build_main_model_painted(unit="millimeter", transform=""):
    """Build the main 3D/3dmodel.model for painted mode (single object)."""
    xform = transform if transform else "1 0 0 0 1 0 0 0 1 0 0 0"
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<model unit="' + unit + '" xml:lang="en-US"\n'
        '  xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"\n'
        '  xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06"\n'
        '  requiredextensions="p">\n'
        '  <resources>\n'
        '    <object id="1" type="model">\n'
        '      <components>\n'
        '        <component p:path="/3D/Objects/object_1.model" objectid="1" transform="1 0 0 0 1 0 0 0 1 0 0 0" />\n'
        '      </components>\n'
        '    </object>\n'
        '  </resources>\n'
        '  <build>\n'
        f'    <item objectid="1" transform="{xform}" printable="1" />\n'
        '  </build>\n'
        '</model>'
    )


def _build_object_model(obj, unit="millimeter", paint_colors=None):
    """Build a per-object 3D/Objects/object_N.model with inline mesh.

    If paint_colors is provided, it should be a list parallel to obj.triangles
    with paint_color attribute strings (empty string = omit attribute).
    """
    verts = []
    for x, y, z in obj.vertices:
        verts.append(f'          <vertex x="{x}" y="{y}" z="{z}" />')

    tris = []
    for i, (v1, v2, v3) in enumerate(obj.triangles):
        pc_attr = ""
        if paint_colors and paint_colors[i]:
            pc_attr = f' paint_color="{paint_colors[i]}"'
        tris.append(f'          <triangle v1="{v1}" v2="{v2}" v3="{v3}"{pc_attr} />')

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<model unit="' + unit + '" xml:lang="en-US"\n'
        '  xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02"\n'
        '  xmlns:p="http://schemas.microsoft.com/3dmanufacturing/production/2015/06"\n'
        '  requiredextensions="p">\n'
        '  <resources>\n'
        '    <object id="1" type="model">\n'
        '      <mesh>\n'
        '        <vertices>\n'
        + "\n".join(verts) + "\n"
        '        </vertices>\n'
        '        <triangles>\n'
        + "\n".join(tris) + "\n"
        '        </triangles>\n'
        '      </mesh>\n'
        '    </object>\n'
        '  </resources>\n'
        '  <build />\n'
        '</model>'
    )


def _build_model_settings(objects, extruder_map):
    """Build Metadata/model_settings.config for Bambu Studio (multi-object mode).

    This file is always loaded by BambuStudio regardless of file origin.
    It controls per-object extruder assignments and plate layout.
    """
    obj_entries = []
    for i, obj in enumerate(objects, 1):
        ext_num = extruder_map[obj.color]
        num_tris = len(obj.triangles)
        obj_entries.append(
            f'  <object id="{i}">\n'
            f'    <metadata key="name" value="{obj.name}" />\n'
            f'    <metadata key="extruder" value="{ext_num}" />\n'
            f'    <metadata face_count="{num_tris}" />\n'
            f'    <part id="{i}" subtype="normal_part">\n'
            f'      <metadata key="name" value="{obj.name}" />\n'
            f'      <metadata key="matrix" value="1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1" />\n'
            f'      <metadata key="source_file" value="{obj.name}.stl" />\n'
            f'      <metadata key="source_object_id" value="0" />\n'
            f'      <metadata key="source_volume_id" value="0" />\n'
            f'      <metadata key="source_offset_x" value="0" />\n'
            f'      <metadata key="source_offset_y" value="0" />\n'
            f'      <metadata key="source_offset_z" value="0" />\n'
            f'      <mesh_stat edges_fixed="0" degenerate_facets="0" facets_removed="0" facets_reversed="0" backwards_edges="0" />\n'
            f'    </part>\n'
            f'  </object>'
        )

    model_instances = []
    for i in range(1, len(objects) + 1):
        model_instances.append(
            f'    <model_instance>\n'
            f'      <metadata key="object_id" value="{i}" />\n'
            f'      <metadata key="instance_id" value="0" />\n'
            f'    </model_instance>'
        )

    assemble_items = []
    for i in range(1, len(objects) + 1):
        assemble_items.append(
            f'    <assemble_item object_id="{i}" instance_id="0" '
            f'transform="1 0 0 0 1 0 0 0 1 0 0 0" offset="0 0 0" />'
        )

    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<config>\n'
        + "\n".join(obj_entries) + "\n"
        '  <plate>\n'
        '    <metadata key="plater_id" value="1" />\n'
        '    <metadata key="plater_name" value="" />\n'
        '    <metadata key="locked" value="false" />\n'
        '    <metadata key="bed_type" value="auto" />\n'
        '    <metadata key="print_sequence" value="by layer" />\n'
        + "\n".join(model_instances) + "\n"
        '  </plate>\n'
        '  <assemble>\n'
        + "\n".join(assemble_items) + "\n"
        '  </assemble>\n'
        '</config>'
    )


def _build_model_settings_painted(merged_obj, default_extruder):
    """Build Metadata/model_settings.config for painted mode (single object)."""
    num_tris = len(merged_obj.triangles)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<config>\n'
        f'  <object id="1">\n'
        f'    <metadata key="name" value="{merged_obj.name}" />\n'
        f'    <metadata key="extruder" value="{default_extruder}" />\n'
        f'    <metadata face_count="{num_tris}" />\n'
        f'    <part id="1" subtype="normal_part">\n'
        f'      <metadata key="name" value="{merged_obj.name}" />\n'
        f'      <metadata key="matrix" value="1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1" />\n'
        f'      <mesh_stat edges_fixed="0" degenerate_facets="0" facets_removed="0" facets_reversed="0" backwards_edges="0" />\n'
        f'    </part>\n'
        f'  </object>\n'
        '  <plate>\n'
        '    <metadata key="plater_id" value="1" />\n'
        '    <metadata key="plater_name" value="" />\n'
        '    <metadata key="locked" value="false" />\n'
        '    <metadata key="bed_type" value="auto" />\n'
        '    <metadata key="print_sequence" value="by layer" />\n'
        '    <model_instance>\n'
        '      <metadata key="object_id" value="1" />\n'
        '      <metadata key="instance_id" value="0" />\n'
        '    </model_instance>\n'
        '  </plate>\n'
        '  <assemble>\n'
        '    <assemble_item object_id="1" instance_id="0" '
        'transform="1 0 0 0 1 0 0 0 1 0 0 0" offset="0 0 0" />\n'
        '  </assemble>\n'
        '</config>'
    )


def write_bambu_3mf(output_path, parsed_model, extruder_map, thumbnails, painted=True):
    """Write a Bambu-compatible 3MF file.

    In painted mode (default), merges all objects into a single mesh with
    per-triangle paint_color attributes. In multi-object mode, keeps separate
    objects with per-object extruder assignments.
    """
    has_thumbnails = bool(thumbnails)
    objects = parsed_model.objects
    unit = parsed_model.unit

    if painted:
        # Painted mode: single merged mesh with paint_color on non-default triangles
        merged, paint_colors, default_extruder = merge_objects_painted(objects, extruder_map)

        with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("[Content_Types].xml", _build_content_types())
            zf.writestr("_rels/.rels", _build_root_rels(has_thumbnails))
            zf.writestr("3D/3dmodel.model", _build_main_model_painted(unit, merged.transform))
            zf.writestr("3D/_rels/3dmodel.model.rels", _build_model_rels(1))
            zf.writestr(
                "3D/Objects/object_1.model",
                _build_object_model(merged, unit, paint_colors),
            )
            zf.writestr(
                "Metadata/model_settings.config",
                _build_model_settings_painted(merged, default_extruder),
            )

            if thumbnails:
                if "plate_1.png" in thumbnails:
                    zf.writestr("Metadata/plate_1.png", thumbnails["plate_1.png"])
                for filename, png_data in thumbnails.items():
                    zf.writestr(f"Auxiliaries/.thumbnails/{filename}", png_data)

        painted_count = sum(1 for pc in paint_colors if pc)
        print(
            f"Wrote {output_path} (painted mode: 1 object, "
            f"{painted_count}/{len(paint_colors)} painted triangles, "
            f"default extruder {default_extruder}, {len(thumbnails)} thumbnails)"
        )
    else:
        # Multi-object mode (original behavior)
        with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("[Content_Types].xml", _build_content_types())
            zf.writestr("_rels/.rels", _build_root_rels(has_thumbnails))
            zf.writestr("3D/3dmodel.model", _build_main_model(objects, unit))
            zf.writestr("3D/_rels/3dmodel.model.rels", _build_model_rels(len(objects)))

            for i, obj in enumerate(objects, 1):
                zf.writestr(
                    f"3D/Objects/object_{i}.model",
                    _build_object_model(obj, unit),
                )

            zf.writestr(
                "Metadata/model_settings.config",
                _build_model_settings(objects, extruder_map),
            )

            if thumbnails:
                if "plate_1.png" in thumbnails:
                    zf.writestr("Metadata/plate_1.png", thumbnails["plate_1.png"])
                for filename, png_data in thumbnails.items():
                    zf.writestr(f"Auxiliaries/.thumbnails/{filename}", png_data)

        print(f"Wrote {output_path} ({len(objects)} objects, {len(thumbnails)} thumbnails)")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", help="Input 3MF file")
    parser.add_argument("-o", "--output", required=True, help="Output Bambu-compatible 3MF file")
    parser.add_argument(
        "--no-thumbnails",
        action="store_true",
        help="Skip thumbnail generation (faster, no F3D needed)",
    )
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--painted",
        action="store_true",
        default=True,
        help="Painted mode: single mesh with per-triangle paint_color (default)",
    )
    mode_group.add_argument(
        "--multi-object",
        action="store_true",
        help="Multi-object mode: separate objects with per-object extruder assignment",
    )
    args = parser.parse_args()

    painted = not args.multi_object

    input_path = Path(args.input)
    if not input_path.exists():
        parser.error(f"Input file not found: {input_path}")

    # Parse input 3MF
    parsed = parse_input_3mf(input_path)
    if not parsed.objects:
        print("Error: No mesh objects found in input 3MF", file=sys.stderr)
        sys.exit(1)

    print(f"Parsed {len(parsed.objects)} objects from {input_path}")
    for obj in parsed.objects:
        print(f"  {obj.name}: {len(obj.vertices)} vertices, {len(obj.triangles)} triangles, color={obj.color}")

    # Map colors to extruders
    extruder_map = map_colors_to_extruders(parsed.objects)
    for color, ext in sorted(extruder_map.items(), key=lambda x: x[1]):
        print(f"  Extruder {ext}: {color}")

    mode_label = "painted" if painted else "multi-object"
    print(f"Mode: {mode_label}")

    # Generate thumbnails
    thumbnails = {}
    if not args.no_thumbnails:
        f3d = shutil.which("f3d")
        if f3d:
            print("Generating thumbnails...")
            thumbnails = generate_thumbnails(input_path, f3d)
            if thumbnails:
                print(f"  Generated {len(thumbnails)} thumbnails")
            else:
                print("  Warning: F3D thumbnail generation failed, continuing without")
        else:
            print("  Note: F3D not found, skipping thumbnails")

    # Write output
    write_bambu_3mf(args.output, parsed, extruder_map, thumbnails, painted=painted)


if __name__ == "__main__":
    main()
