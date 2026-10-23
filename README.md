# Facets

NPC overworld sprites for the Gen 3 games in gen1recomp: FireRed, LeafGreen, Ruby, Sapphire and Emerald. Townsfolk, trainers, nurses, gym leaders and villains can each get new art, one sheet at a time. Anything without a sheet stays the game's own.

Facets is the companion to [Emerald Lens](https://github.com/ElvieBlooms/emerald_lens): Emerald Lens does the player and the rival, Facets does everyone else. They never touch the same sprites, so they work together in either load order.

**Status: 0.1.0, phase 1.** The engine side is done for all five games. It ships with a numbered TEST FRAMES set for checking things in game; real art comes from the converter.

## Options

Under the mod's options there's a heading per game family (FR/LG, R/S/E) with **SET**: each sprite set you have, or OFF for the game's own NPCs. Changes apply straight away.

If the selected set doesn't have a sheet for someone, the other sets are tried in menu order, then the game's own sprite.

## Sprite sets

A set is a folder in `assets/npcs/`:

```
assets/npcs/<set>/meta.json           {"label": "HGSS", "credit": ["..."]}
assets/npcs/<set>/gen3/frlg/NURSE.png FireRed and LeafGreen
assets/npcs/<set>/gen3/rse/NURSE.png  Ruby, Sapphire and Emerald
```

Each sheet is named after the game's own name for that sprite (the `OBJ_EVENT_GFX_` name without the prefix): `NURSE.png`, `YOUNGSTER.png`, `BROCK.png`, `ROCKET_F.png`. Case doesn't matter. The lists are in the engine's `src/core/game3/constants/<firered|ruby|emerald>/event_objects.lua`.

In `rse/`, Ruby and Sapphire's names for people Emerald renamed also find the Emerald file, so `RICH_BOY.png` covers Ruby's `BOY_4` too (list in `names.lua`).

**Never replaced:** the player, the rival (Blue in FR/LG), and the link and Union Room stand-ins. Those are Emerald Lens's, or other players'.

### Sheet format

Frames stacked top to bottom in one column, in the games' own order:

| Frame | Pose |
| --- | --- |
| 0, 1, 2 | stand facing down, up, left |
| 3, 4 | walk down |
| 5, 6 | walk up |
| 7, 8 | walk left |
| 9 (optional) | nurse's bow, or an FR/LG trainer's VS Seeker hand raise |

Facing right is the left frames mirrored. Feet go on the second-to-last row of the frame, where the games' own NPCs stand.

| The game's sprite | Frame size | Frames |
| --- | --- | --- |
| 16x32 person | 16x32, or 32x32 for DS-style art | 9, or 10 if the game's has 10 |
| 16x16 child | 16x16, or 32x32 | 9, or 10 if the game's has 10 |
| 32x32 (bikers, cycling triathletes) | 32x32 | 9, or 10 if the game's has 10 |

With 9 frames, the bow or hand raise shows the standing frame instead. Objects (item balls, boulders, signs) and anything bigger than 32x32 aren't replaced yet.

A sheet that doesn't fit is skipped, with one line in the log saying why.

## Converting a sprite pack

`tools/npc_convert.py` turns Pokémon Essentials charsets (4x4: rows down, left, right, up) into Facets sheets. Upscaled packs are shrunk back only when that loses nothing, and the feet are lined up for you. Run it on your own copy of a pack; the art doesn't go in this repo.

```
python3 tools/npc_convert.py one 123.png . --set hgss --family frlg --name NURSE
python3 tools/npc_convert.py one 123.png . --set hgss --family frlg --name NURSE --extra bow.png
python3 tools/npc_convert.py recipe tools/recipes/example.json <pack folder> .
```

A recipe lists which pack file is which NPC per family, plus the set's label and credits. See `tools/recipes/example.json`. Needs Python 3 and Pillow.

### HGSS (Neo-Spriteman's Resource Pack)

`tools/recipes/hgss.json` maps 54 FireRed/LeafGreen NPCs to the pack's `HGSS OVERWORLDS/Humans` sheets. That covers the gym leaders, Elite Four, Rocket grunts, Oak, Bill, Daisy, Mom, nurses, clerks and most trainer classes. The pack's file numbers are HGSS's own overworld model numbers (`MMODEL_*` in pret's pokeheartgold), which is how each one is identified.

```
python3 tools/npc_convert.py recipe tools/recipes/hgss.json "<pack>/HGSS OVERWORLDS/Humans" .
```

This writes `assets/npcs/hgss/`, which shows up as **HGSS** under SET. The art stays on your machine: `.gitignore` keeps everything in `assets/npcs/` out of the repo except the test set.

The recipe's `confidence` notes which matches are exact (named characters, trainer classes) and which are best guesses (generic townsfolk with no exact HGSS twin). The pack has no art for Agatha, Lorelei, Mr. Fuji, Celio, the Teachy TV host or the Trainer Tower and Gym guides, so those keep the game's own. HGSS sheets have 9 frames, so the VS Seeker hand raise shows the standing frame. The nurse's sheet has her bow drawn in, and the recipe's `cells` list moves it to frame 9 so she still bows.

## Testing

`tools/make_test_set.py .` rebuilds the TEST FRAMES set. Each frame shows its number, and an arrow on the head shows which way it faces.

| File | What it checks |
| --- | --- |
| NURSE | 32x32 with the bow (frame 9 shows a B) |
| YOUNGSTER | 32x32 with 9 frames: the VS Seeker hand raise falls back to standing |
| LITTLE_BOY | 32x32 over the game's 16x16 |
| BROCK, ROXANNE | the game's own 16x32 size |
| BUG_CATCHER | 16x32 with the hand raise (FR/LG) |
| RICH_BOY | R/S/E: Ruby's BOY_4 finds it through the alias |

Headless tests run against an unzipped gen1recomp `.love` and an install folder with the ROM caches:

```
GEN1RECOMP_SRC=<unzipped .love> GEN1RECOMP_DATA=<install folder> texlua tests/run.lua
```

(`texlua` comes with TeX Live and has `lfs` built in; plain Lua 5.1–5.4 or LuaJIT with luafilesystem works too.)

## Credits

Code by Elvie, MIT licensed. Built on the approach of Emerald Lens and Crystal Lens (dburton95).
