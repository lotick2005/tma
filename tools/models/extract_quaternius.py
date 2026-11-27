#!/usr/bin/env python3
"""Достать одну анимацию из tools/models/src/quaternius/UAL1_Standard.glb в отдельный animations/<имя>.glb.

Без Blender: читает glTF как есть, оставляет узлы скелета (Armature/root/pelvis/…), skin и выбранную анимацию,
а меш манекена заменяет одним треугольником в 1 мм (anim_skin, как в остальных animations/*.glb — без skin
Godot не соберёт Skeleton3D). Ретаргет в Godot — models/quaternius_bone_map.tres (в .import файла).

Запуск: python3 tools/models/extract_quaternius.py <имя анимации в UAL1> animations/<имя>.glb
Пример: python3 tools/models/extract_quaternius.py Fixing_Kneeling animations/kneel_fix.glb
"""
import json
import struct
import sys

SRC = "tools/models/src/quaternius/UAL1_Standard.glb"


def read_glb(path):
    data = open(path, "rb").read()
    jlen = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + jlen])
    off = 20 + jlen
    blen = struct.unpack("<I", data[off:off + 4])[0]
    return j, data[off + 8:off + 8 + blen]


def main():
    anim_name, out_path = sys.argv[1], sys.argv[2]
    j, binb = read_glb(SRC)
    anim = next(a for a in j["animations"] if a["name"] == anim_name)
    out = bytearray()
    views, accs = [], []

    def add_bytes(b, target=None):
        while len(out) % 4:
            out.append(0)
        v = {"buffer": 0, "byteOffset": len(out), "byteLength": len(b)}
        if target:
            v["target"] = target
        out.extend(b)
        views.append(v)
        return len(views) - 1

    def copy_acc(i):
        a = dict(j["accessors"][i])
        bv = j["bufferViews"][a["bufferView"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        comp = {5126: 4, 5123: 2, 5121: 1, 5125: 4}[a["componentType"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        stride = bv.get("byteStride", comp * n)
        chunk = bytearray()
        for k in range(a["count"]):
            s = start + k * stride
            chunk.extend(binb[s:s + comp * n])
        a["bufferView"] = add_bytes(bytes(chunk))
        a.pop("byteOffset", None)
        accs.append(a)
        return len(accs) - 1

    skin = dict(j["skins"][0])
    skin["inverseBindMatrices"] = copy_acc(skin["inverseBindMatrices"])
    samplers = []
    for s in anim["samplers"]:
        samplers.append({"input": copy_acc(s["input"]), "output": copy_acc(s["output"]),
                         "interpolation": s.get("interpolation", "LINEAR")})
    new_anim = {"name": anim_name, "samplers": samplers, "channels": anim["channels"]}
    # Треугольник 1 мм, весь на первой кости скелета
    pos = struct.pack("<9f", 0, 0, 0, 0.001, 0, 0, 0, 0.001, 0)
    joints = struct.pack("<12H", *([0, 0, 0, 0] * 3))
    weights = struct.pack("<12f", *([1, 0, 0, 0] * 3))
    pv = add_bytes(pos, 34962)
    accs.append({"bufferView": pv, "componentType": 5126, "count": 3, "type": "VEC3",
                 "min": [0, 0, 0], "max": [0.001, 0.001, 0]})
    jv = add_bytes(joints, 34962)
    accs.append({"bufferView": jv, "componentType": 5123, "count": 3, "type": "VEC4"})
    wv = add_bytes(weights, 34962)
    accs.append({"bufferView": wv, "componentType": 5126, "count": 3, "type": "VEC4"})
    n = len(accs)
    mesh = {"name": "anim_skin", "primitives": [{"attributes": {"POSITION": n - 3, "JOINTS_0": n - 2, "WEIGHTS_0": n - 1}}]}
    nodes = []
    for nd in j["nodes"]:
        nd = dict(nd)
        if "mesh" in nd:
            nd["mesh"] = 0
            nd["name"] = "anim_skin"
        nodes.append(nd)
    while len(out) % 4:
        out.append(0)
    g = {"asset": {"version": "2.0", "generator": "tma extract_quaternius.py (Quaternius UAL1, CC0)"},
         "scene": 0, "scenes": j["scenes"], "nodes": nodes, "meshes": [mesh], "skins": [skin],
         "animations": [new_anim], "accessors": accs, "bufferViews": views,
         "buffers": [{"byteLength": len(out)}]}
    js = json.dumps(g, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(out)
    with open(out_path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(out), 0x004E4942) + bytes(out))
    print(out_path, len(out), "байт данных,", len(samplers), "дорожек")


if __name__ == "__main__":
    main()
