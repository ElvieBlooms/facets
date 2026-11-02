#!/usr/bin/env python3
"""Writes gba_ids.lua: FireRed's and Emerald's overworld graphics ids and
trainer picture ids by name, from gen1recomp's constant tables (made from
pret's pokefirered and pokeemerald headers). The Gen 1/2 GBA look uses
them to find pictures in the player's own imported games, since a Gen 2
game can't load the engine's Gen 3 modules -Elvie

    python3 tools/make_gba_ids.py <gen1recomp folder> [out.lua]
"""
import os
import re
import sys

GAMES = ("firered", "emerald")


def table(path, prefix):
    text = open(path, encoding="utf-8").read()
    start = text.find(prefix + " = {")
    if start < 0:
        sys.exit(f"{prefix} wasn't found in {path}")
    end = text.find("}", start)
    out = {}
    for num, name in re.findall(r'\[(\d+)\] = "(\w+)"', text[start:end]):
        out[name[len(prefix):]] = int(num)
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    engine = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else "gba_ids.lua"
    base = os.path.join(engine, "src", "core", "game3", "constants")
    lines = ["-- FireRed's and Emerald's overworld graphics ids and trainer picture",
             "-- ids, by name. Made by tools/make_gba_ids.py from gen1recomp's",
             "-- constant tables (pret's pokefirered and pokeemerald headers). -Elvie",
             "return {"]
    for game in GAMES:
        ow = table(os.path.join(base, game, "event_objects.lua"), "OBJ_EVENT_GFX_")
        pics = table(os.path.join(base, game, "trainer_classes.lua"), "TRAINER_PIC_")
        lines.append(f"  {game} = {{")
        for key, rows in (("ow", ow), ("pics", pics)):
            lines.append(f"    {key} = {{")
            for name, num in sorted(rows.items(), key=lambda r: r[1]):
                lines.append(f"      {name} = {num},")
            lines.append("    },")
        lines.append("  },")
    lines.append("}")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
