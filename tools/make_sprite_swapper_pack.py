#!/usr/bin/env python3
"""Turns a Facets Pokémon set into a sprite pack for artyrambles'
SPRITE SWAPPER (ST_SPRITESWAPPER), so people who use that mod can pick
Facets' art there instead.

  python3 make_sprite_swapper_pack.py <recipe.json> <facets folder> <gen1recomp folder> <out folder>

Writes <out>/<id>/ and <out>/<id>.zip (files at the zip's root, as the
launcher wants). The pack needs SPRITE SWAPPER installed, and is Gen 3
only, like Facets.

The recipe (recipes/sprite_swapper_*.json) names the Facets sets to take
pictures from, first set first, and whose party icons to add for the
Pokémon the pack covers. Only a set's own files go in: anything Facets
makes from the player's own games (GBC-ISH, GB EMERALD, Crystal's
sprites) can't be a pack.

SPRITE SWAPPER draws a 64x64 file where the game draws its own picture,
the game's own height offset included, so each picture is stood where
the game's own would stand, as Facets does when it draws it. The offsets
are read from gen1recomp's own source (FireRed and LeafGreen's table;
Ruby, Sapphire and Emerald's differ by a pixel or two for a few redrawn
Kanto Pokémon). Needs Pillow. -Elvie
"""
import json, os, re, shutil, sys, zipfile
from PIL import Image

SIZE = 64

# The in-game names SPRITE SWAPPER looks for (the engine's species key
# names), by national number. -Elvie
NAMES = '''
BULBASAUR IVYSAUR VENUSAUR CHARMANDER CHARMELEON CHARIZARD SQUIRTLE WARTORTLE BLASTOISE CATERPIE
METAPOD BUTTERFREE WEEDLE KAKUNA BEEDRILL PIDGEY PIDGEOTTO PIDGEOT RATTATA RATICATE SPEAROW FEAROW
EKANS ARBOK PIKACHU RAICHU SANDSHREW SANDSLASH NIDORAN_F NIDORINA NIDOQUEEN NIDORAN_M NIDORINO
NIDOKING CLEFAIRY CLEFABLE VULPIX NINETALES JIGGLYPUFF WIGGLYTUFF ZUBAT GOLBAT ODDISH GLOOM
VILEPLUME PARAS PARASECT VENONAT VENOMOTH DIGLETT DUGTRIO MEOWTH PERSIAN PSYDUCK GOLDUCK MANKEY
PRIMEAPE GROWLITHE ARCANINE POLIWAG POLIWHIRL POLIWRATH ABRA KADABRA ALAKAZAM MACHOP MACHOKE MACHAMP
BELLSPROUT WEEPINBELL VICTREEBEL TENTACOOL TENTACRUEL GEODUDE GRAVELER GOLEM PONYTA RAPIDASH
SLOWPOKE SLOWBRO MAGNEMITE MAGNETON FARFETCHD DODUO DODRIO SEEL DEWGONG GRIMER MUK SHELLDER CLOYSTER
GASTLY HAUNTER GENGAR ONIX DROWZEE HYPNO KRABBY KINGLER VOLTORB ELECTRODE EXEGGCUTE EXEGGUTOR CUBONE
MAROWAK HITMONLEE HITMONCHAN LICKITUNG KOFFING WEEZING RHYHORN RHYDON CHANSEY TANGELA KANGASKHAN
HORSEA SEADRA GOLDEEN SEAKING STARYU STARMIE MR_MIME SCYTHER JYNX ELECTABUZZ MAGMAR PINSIR TAUROS
MAGIKARP GYARADOS LAPRAS DITTO EEVEE VAPOREON JOLTEON FLAREON PORYGON OMANYTE OMASTAR KABUTO
KABUTOPS AERODACTYL SNORLAX ARTICUNO ZAPDOS MOLTRES DRATINI DRAGONAIR DRAGONITE MEWTWO MEW CHIKORITA
BAYLEEF MEGANIUM CYNDAQUIL QUILAVA TYPHLOSION TOTODILE CROCONAW FERALIGATR SENTRET FURRET HOOTHOOT
NOCTOWL LEDYBA LEDIAN SPINARAK ARIADOS CROBAT CHINCHOU LANTURN PICHU CLEFFA IGGLYBUFF TOGEPI TOGETIC
NATU XATU MAREEP FLAAFFY AMPHAROS BELLOSSOM MARILL AZUMARILL SUDOWOODO POLITOED HOPPIP SKIPLOOM
JUMPLUFF AIPOM SUNKERN SUNFLORA YANMA WOOPER QUAGSIRE ESPEON UMBREON MURKROW SLOWKING MISDREAVUS
UNOWN WOBBUFFET GIRAFARIG PINECO FORRETRESS DUNSPARCE GLIGAR STEELIX SNUBBULL GRANBULL QWILFISH
SCIZOR SHUCKLE HERACROSS SNEASEL TEDDIURSA URSARING SLUGMA MAGCARGO SWINUB PILOSWINE CORSOLA
REMORAID OCTILLERY DELIBIRD MANTINE SKARMORY HOUNDOUR HOUNDOOM KINGDRA PHANPY DONPHAN PORYGON2
STANTLER SMEARGLE TYROGUE HITMONTOP SMOOCHUM ELEKID MAGBY MILTANK BLISSEY RAIKOU ENTEI SUICUNE
LARVITAR PUPITAR TYRANITAR LUGIA HO_OH CELEBI TREECKO GROVYLE SCEPTILE TORCHIC COMBUSKEN BLAZIKEN
MUDKIP MARSHTOMP SWAMPERT POOCHYENA MIGHTYENA ZIGZAGOON LINOONE WURMPLE SILCOON BEAUTIFLY CASCOON
DUSTOX LOTAD LOMBRE LUDICOLO SEEDOT NUZLEAF SHIFTRY TAILLOW SWELLOW WINGULL PELIPPER RALTS KIRLIA
GARDEVOIR SURSKIT MASQUERAIN SHROOMISH BRELOOM SLAKOTH VIGOROTH SLAKING NINCADA NINJASK SHEDINJA
WHISMUR LOUDRED EXPLOUD MAKUHITA HARIYAMA AZURILL NOSEPASS SKITTY DELCATTY SABLEYE MAWILE ARON
LAIRON AGGRON MEDITITE MEDICHAM ELECTRIKE MANECTRIC PLUSLE MINUN VOLBEAT ILLUMISE ROSELIA GULPIN
SWALOT CARVANHA SHARPEDO WAILMER WAILORD NUMEL CAMERUPT TORKOAL SPOINK GRUMPIG SPINDA TRAPINCH
VIBRAVA FLYGON CACNEA CACTURNE SWABLU ALTARIA ZANGOOSE SEVIPER LUNATONE SOLROCK BARBOACH WHISCASH
CORPHISH CRAWDAUNT BALTOY CLAYDOL LILEEP CRADILY ANORITH ARMALDO FEEBAS MILOTIC CASTFORM KECLEON
SHUPPET BANETTE DUSKULL DUSCLOPS TROPIUS CHIMECHO ABSOL WYNAUT SNORUNT GLALIE SPHEAL SEALEO WALREIN
CLAMPERL HUNTAIL GOREBYSS RELICANTH LUVDISC BAGON SHELGON SALAMENCE BELDUM METANG METAGROSS REGIROCK
REGICE REGISTEEL LATIAS LATIOS KYOGRE GROUDON RAYQUAZA JIRACHI DEOXYS
'''.split()

# Gen 3's own species numbers for Hoenn (national 252-386), which its
# offset tables use; 1-251 are the same both ways. -Elvie
HOENN_INTERNAL = [
    277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296,
    297, 298, 299, 300, 304, 305, 309, 310, 392, 393, 394, 311, 312, 306, 307, 364, 365, 366, 301, 302,
    303, 370, 371, 372, 335, 336, 350, 320, 315, 316, 322, 355, 382, 383, 384, 356, 357, 337, 338, 353,
    354, 386, 387, 363, 367, 368, 330, 331, 313, 314, 339, 340, 321, 351, 352, 308, 332, 333, 334, 344,
    345, 358, 359, 380, 379, 348, 349, 323, 324, 326, 327, 318, 319, 388, 389, 390, 391, 328, 329, 385,
    317, 377, 378, 361, 362, 369, 411, 376, 360, 346, 347, 341, 342, 343, 373, 374, 375, 381, 325, 395,
    396, 397, 398, 399, 400, 401, 402, 403, 407, 408, 404, 405, 406, 409, 410,
]
assert len(NAMES) == 386 and len(HOENN_INTERNAL) == 135

# Facets' Castform files by SPRITE SWAPPER's form names -Elvie
CASTFORM = {"_sunny": "SUN", "_rainy": "RAIN", "_snowy": "HAIL"}
UNOWN = "abcdefghijklmnopqrstuvwxyz"


def internal(nat):
    return nat if nat <= 251 else HOENN_INTERNAL[nat - 252]


def read_offsets(engine):
    """FireRed and LeafGreen's front and back height offsets, by Gen 3
    species number, from gen1recomp's pic_coords.lua -Elvie"""
    path = os.path.join(engine, "src", "core", "game3", "battle", "pic_coords.lua")
    if not os.path.isfile(path):
        sys.exit(f"gen1recomp's {path} wasn't found; point the third argument at the gen1recomp folder")
    text = open(path, encoding="utf-8").read()
    out = {}
    for kind in ("front", "back"):
        m = re.search(r"\n  " + kind + r" = \{(.*?)\n  \}", text, re.S)
        if not m:
            sys.exit(f"{path}: no {kind} table")
        out[kind] = {int(k): int(v) for k, v in re.findall(r"\[(\d+)\] = (-?\d+)", m.group(1))}
    return out


def stand(im, bottom, place=None):
    """Facets' layOut: centred across, lowest pixel on the row above
    `bottom`. place (a dict) keeps a front's spot for its shiny. -Elvie"""
    im = im.convert("RGBA")
    if im.width > SIZE or im.height > SIZE:
        return None
    box = im.getchannel("A").getbbox()
    if not box and not (place and "oy" in place):
        return None
    if place is not None and "oy" in place:
        ox, oy = place["ox"], place["oy"]
    else:
        top, low = box[1], box[3] - 1
        ox = (SIZE - im.width) // 2
        oy = bottom - 1 - low
        if oy + top < 0:
            oy = -top
        if oy + low > SIZE - 1:
            oy = SIZE - 1 - low
        if place is not None:
            place["ox"], place["oy"] = ox, oy
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(im, (ox, oy), im)
    return out


def icon32(im):
    """Two frames as 32x64: 16x16 frames sit at the bottom centre of each
    32x32 one, as Facets puts them. -Elvie"""
    im = im.convert("RGBA")
    if im.size == (32, 64):
        return im
    if im.size != (16, 32):
        return None
    out = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    for f in range(2):
        out.paste(im.crop((0, f * 16, 16, f * 16 + 16)), (8, f * 32 + 16))
    return out


def main_lua(r, shinies):
    label = json.dumps(r["label"])
    return f"""-- {r['name']}: a SPRITE SWAPPER sprite pack, made from Facets with
-- make_sprite_swapper_pack.py. Pick it in SPRITE SWAPPER's options. -Elvie
return function(mod)
  mod.exports = {{
    isSpritePack = true,
    packLabel = {label},
    trueColorSprites = true,
    trueColorShinySprites = true,
    providesShinySprites = {'true' if shinies else 'false'},
    remappedFilenames = {{}},
    modPath = mod.path,
  }}
end
"""


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    recipe_path, facets, engine, out_root = sys.argv[1:]
    r = json.load(open(recipe_path, encoding="utf-8"))
    for key in ("id", "name", "label", "description", "version", "sets", "credit"):
        if key not in r:
            sys.exit(f"{recipe_path}: no \"{key}\"")
    offsets = read_offsets(engine)
    mons = os.path.join(facets, "assets", "mons")
    sets = [os.path.join(mons, s) for s in r["sets"]]
    for s in sets:
        if not os.path.isdir(s):
            sys.exit(f"{s}: no such set")
    skip = set(r.get("skip", []))

    pack = os.path.join(out_root, r["id"])
    if os.path.isdir(pack):
        shutil.rmtree(pack)

    def find(sub):
        for s in sets:
            p = os.path.join(s, sub)
            if os.path.isfile(p):
                return p
        return None

    def save(im, kind, shiny, name):
        d = os.path.join(pack, "assets", "pokemon", kind, "shiny" if shiny else "normal")
        os.makedirs(d, exist_ok=True)
        im.save(os.path.join(d, name + ".png"))

    counts = {"front": 0, "back": 0, "shiny": 0, "icons": 0}
    covered = []
    for nat in range(1, 387):
        if nat in skip:
            continue
        sp = internal(nat)
        # Unown's letters (NNN_b.png...), Castform's weather forms -Elvie
        variants = [("", "")]
        if nat == 201:
            variants = [("", "_A")] + [("_" + c, "_" + c.upper()) for c in UNOWN[1:]] + [("_emark", "_!"), ("_qmark", "_?")]
        elif nat == 351:
            variants = [("", "")] + [(k, "_" + v) for k, v in CASTFORM.items()]
        any_art = False
        for kind in ("front", "back"):
            bottom = SIZE - offsets[kind].get(sp, 0)
            for suffix, name_suffix in variants:
                place = {}
                for shiny in (False, True):
                    src = find(f"{kind}{'_shiny' if shiny else ''}/{nat:03d}{suffix}.png")
                    if not src:
                        continue
                    pic = stand(Image.open(src), bottom, place)
                    if pic is None:
                        print(f"skipped {src}: empty or bigger than 64x64")
                        continue
                    save(pic, kind, shiny, NAMES[nat - 1] + name_suffix)
                    counts["shiny" if shiny else kind] += 1
                    any_art = True
        if any_art:
            covered.append(nat)

    # Party icons for the Pokémon the pack covers, so each one's icon
    # matches its pictures -Elvie
    icon_set = r.get("icons")
    if icon_set:
        d = os.path.join(mons, icon_set, "icons")
        for nat in covered:
            p = os.path.join(d, f"{nat:03d}.png")
            if not os.path.isfile(p):
                continue
            pic = icon32(Image.open(p))
            if pic is None:
                print(f"skipped {p}: icons need two 16x16 or 32x32 frames, stacked")
                continue
            # Gen 3's shinies share their icon; SPRITE SWAPPER looks in
            # shiny/ for a shiny one -Elvie
            for sub in ("normal", "shiny"):
                out = os.path.join(pack, "assets", "pokemon", "icons", sub)
                os.makedirs(out, exist_ok=True)
                pic.save(os.path.join(out, NAMES[nat - 1] + ".png"))
            counts["icons"] += 1

    if not covered:
        sys.exit("nothing to pack: the sets have no pictures of their own")
    manifest = {
        "id": r["id"], "name": r["name"], "description": r["description"], "version": r["version"],
        "entry": "main.lua", "api": 3, "priority": 0, "experimental": False,
        "dependencies": ["ST_SPRITESWAPPER"], "profile": "content", "category": "SPRITE SWAPPER",
        "games": ["gen3"],
    }
    with open(os.path.join(pack, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")
    with open(os.path.join(pack, "main.lua"), "w", encoding="utf-8") as f:
        f.write(main_lua(r, counts["shiny"] > 0))
    with open(os.path.join(pack, "README.md"), "w", encoding="utf-8") as f:
        f.write(f"# {r['name']}\n\n{r['description']}\n\n")
        f.write("A sprite pack for SPRITE SWAPPER (ST_SPRITESWAPPER, by artyrambles), which it needs. "
                "Install both, then pick **" + r["label"] + "** under SPRITE PACK in SPRITE SWAPPER's options. "
                "Gen 3 only. Any Pokémon it doesn't have stays the game's own.\n\n")
        for note in r.get("notes", []):
            f.write(note + "\n\n")
        f.write("## Credits\n\n")
        for line in r["credit"]:
            f.write(f"- {line}\n")
        f.write("\nMade from Facets (https://github.com/ElvieBlooms/facets) with make_sprite_swapper_pack.py.\n")

    zpath = os.path.join(out_root, r["id"] + ".zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(pack):
            for name in sorted(files):
                full = os.path.join(root, name)
                z.write(full, os.path.relpath(full, pack))
    print(f"{r['name']}: {len(covered)} Pokémon, {counts['front']} fronts, {counts['back']} backs, "
          f"{counts['shiny']} shinies, {counts['icons']} icons -> {zpath}")


if __name__ == "__main__":
    main()
