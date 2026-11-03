#!/usr/bin/env python3
"""Pokémon Heart & Soul's Johto people, for the Game Boy games.

Copies the HnS sprites Facets uses from a pokehns-expansion checkout:
trainer pictures into the DS set's gb_hns/ folder under Gen 2's class names, and overworld
sheets into the HEART & SOUL fill-in set (assets/npcs/hns), laid out as
Facets' Gen 3 sheets (nine 32x32 frames, top to bottom). The GBA palette's
colour 0 becomes see-through. -Elvie

Credit: Pokémon Heart & Soul (pokemonHnS-expansion 2.0, based on RHH's
pokeemerald-expansion), sprites by its artists (see the sets' meta.json).

    python3 tools/import_hns.py <pokehns-expansion folder> [facets folder]
"""
import os
import sys

from PIL import Image

# Gen 2 trainer class -> HnS front pic. Classes Gen 1 shares (KOGA, BRUNO)
# keep the DS set's own, so Red's leaders don't change. Not CHAMPION:
# HnS's Lance is FireRed's own picture, and the GBA look reads that from
# the player's FireRed anyway -Elvie
TRAINERS = {
    "FALKNER": "leader_falkner_hns", "BUGSY": "leader_bugsy_hns", "WHITNEY": "leader_whitney_hns",
    "MORTY": "leader_morty_hns", "CHUCK": "leader_chuck_hns", "JASMINE": "leader_jasmine_hns",
    "PRYCE": "leader_pryce_hns", "CLAIR": "leader_clair_hns", "JANINE": "leader_janine_hns",
    "WILL": "elite_four_will_hns", "KAREN": "elite_four_karen_hns",
    "RED": "red_hns", "BLUE": "leader_blue_hns", "MYSTICALMAN": "eusine_hns",
    "KIMONO_GIRL": "kimono_girl_hns", "OFFICER": "officer_hns", "SAGE": "sage_hns",
    "SKIER": "skier_f_hns", "BOARDER": "skier_m_hns", "FIREBREATHER": "firebreather_hns",
    "EXECUTIVEM": "proton_hns", "EXECUTIVEF": "ariana_hns",
}

# Gen 2 overworld sprite (SPRITE_ without the prefix) -> HnS sheet -Elvie
PEOPLE = {
    "FALKNER": "gym_leaders/falkner_hns", "BUGSY": "gym_leaders/bugsy_hns",
    "WHITNEY": "gym_leaders/whitney_hns", "MORTY": "gym_leaders/morty_hns",
    "CHUCK": "gym_leaders/chuck_hns", "JASMINE": "gym_leaders/jasmine_hns",
    "PRYCE": "gym_leaders/pryce_hns", "CLAIR": "gym_leaders/clair_hns",
    "JANINE": "gym_leaders/janine_hns", "WILL": "elite_four/will_hns", "KAREN": "elite_four/karen_hns",
    "ELM": "special/elm_hns", "KURT": "special/kurt_hns", "KURT_OUTSIDE": "special/kurt_hns",
    "KIMONO_GIRL": "special/kimono_hns", "ELDER": "sage_elder_hns", "SAGE": "sage_hns",
    "OFFICER": "officer_hns",
}


def clear(path):
    """An indexed GBA sprite as RGBA, colour 0 see-through."""
    im = Image.open(path)
    if im.mode != "P":
        raise SystemExit(f"{path}: expected an indexed PNG")
    src = im.load()
    out = im.convert("RGBA")
    px = out.load()
    for y in range(im.height):
        for x in range(im.width):
            if src[x, y] == 0:
                px[x, y] = (0, 0, 0, 0)
    return out


def sheet(path):
    """Nine 16x32 frames side by side -> nine 32x32 frames stacked,
    each centred, feet on the bottom row."""
    im = clear(path)
    if im.height != 32 or im.width < 144:
        raise SystemExit(f"{path}: expected 16x32 frames in a row, got {im.size}")
    out = Image.new("RGBA", (32, 32 * 9), (0, 0, 0, 0))
    for i in range(9):
        out.paste(im.crop((i * 16, 0, i * 16 + 16, 32)), (8, i * 32))
    return out


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    hns = sys.argv[1]
    facets = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..")
    gfx = os.path.join(hns, "graphics")
    # gb_hns/: only the Game Boy games look there, so Gen 3's RED and BLUE
    # (FR/LG's own player pictures) aren't touched -Elvie
    trainers = os.path.join(facets, "assets", "trainers", "ds", "gb_hns")
    os.makedirs(trainers, exist_ok=True)
    for name, stem in TRAINERS.items():
        clear(os.path.join(gfx, "trainers", "front_pics", stem + ".png")).save(
            os.path.join(trainers, name + ".png"), optimize=True)
    people = os.path.join(facets, "assets", "npcs", "hns", "gen3", "johto")
    os.makedirs(people, exist_ok=True)
    for name, stem in PEOPLE.items():
        sheet(os.path.join(gfx, "object_events", "pics", "people", stem + ".png")).save(
            os.path.join(people, name + ".png"), optimize=True)
    print(f"{len(TRAINERS)} trainer pictures, {len(PEOPLE)} overworld sheets")


if __name__ == "__main__":
    main()
