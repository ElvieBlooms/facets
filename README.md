<img width="910" height="568" alt="facets-gem-labelled-logo" src="https://github.com/user-attachments/assets/ff8c5589-1c21-4dc4-95e4-0cfa1d08c593" />

# Facets

NPC overworld sprites for the Gen 3 games in gen1recomp: FireRed, LeafGreen, Ruby, Sapphire and Emerald. Townsfolk, trainers, nurses, gym leaders and villains can each get new art, one sheet at a time. Anything without a sheet stays the game's own.

Facets can also swap Pokémon pictures: Game Boy Color sprites for all 386, or the DS-style 64x64 resource (below).

Facets is the companion to [Emerald Lens](https://github.com/ElvieBlooms/emerald_lens): Emerald Lens does the player and the rival, Facets does everyone else. They never touch the same sprites, so they work together in either load order.

**Status: 0.2.0.** Works in all five games. It ships with four sprite sets, all free to use with credit:

- **DIEGO:** DiegoWT's Black/White-style trainers and townsfolk.
- **TAIGA:** Taiga's ORAS-style trainers.
- **ZAFFRE:** PurpleZaffre's named characters (Hoenn's gym leaders, Wallace, Archie and Maxie; Agatha, Lorelei, Mr. Fuji and Giovanni).
- **COMMUNITY:** custom sprites by KyleDove, Jext and Hyo (with some by DiegoWT and Aqua) for everyone else: Kanto's gym leaders, Bruno and Lance, Team Rocket, Oak, Bill and Daisy, Hoenn's Elite Four, Aqua and Magma, Birch, Wally, Steven, the Frontier Brains, Pokémon Center staff and townsfolk.

Together they give **every person in all five games** new art, with no converting needed: 74 NPCs in FireRed/LeafGreen, 104 in Emerald and 98 in Ruby/Sapphire. That's every trainer, townsperson, staff member and story character; checked against the games' sprite tables and pret's maps. Objects keep the game's art, and Pokémon have their own option. HGSS art (Nintendo's) isn't included; its recipe is still there if you'd like HGSS's look for the NPCs it has. A numbered TEST FRAMES set is included for checking frame order; it's only used when picked.

There are also two Game Boy looks, **GBC** and **GBC 2X** (below): Gen 1/2 overworld sprites read from your own imported Crystal, Gold, Silver, Yellow, Red or Blue, with Catwithnojob's Gen 2-style sprites for everyone the Game Boy games never had. With a Gen 1/2 game imported, they cover every person in all five games too.

## Options

Under the mod's options there's a heading per game family (FR/LG, R/S/E) with **SET**: each sprite set you have, or OFF for the game's own NPCs. Changes apply straight away.

If the selected set doesn't have a sheet for someone, the other sets are tried in menu order, then the game's own sprite.

Below those, **POKEMON** has its own **SET** for Pokémon pictures (battle, summary, Pokédex, PC, evolution, trades and the rest). It's OFF by default, so Facets only changes Pokémon when you ask it to. One choice covers all five games.

**FR/LG ANIMS** gives FireRed and LeafGreen Emerald's front animations: the hop, shake or spin each Pokémon does when it appears or cries, in battle, on hatching, after evolving and in the PC. FR/LG never had them, so Facets reads them from your own imported Emerald (nothing is included), and the option does nothing without one. Emerald's animations flip to a second picture drawn on Emerald's art, and FR/LG redrew most of Kanto (188 Pokémon), so with this on those Pokémon's front pictures are Emerald's, standing on FR/LG's ground line, and they animate in full. Their backs stay FR/LG's, and so does everything that looks the same in both games. It's OFF by default.

### The FACETS screen
The same choices for the game you're playing are on a screen of their own, laid out like Emerald Lens's LENS screen: **FACETS** on the START menu (above MODS, or EXIT), and **FACETS** on the OPTION menu, which shows the NPC set. With Emerald Lens installed too, the two share one item instead: **PRISM**, on both menus, opens a short list (EMERALD LENS, with your character, and FACETS, with your NPC set), and picking one opens its screen; B there comes back to the list. Each mod has its own gem in the list (emerald for Emerald Lens, amethyst for Facets); the header takes the picked one's colour, and a faceted corner in the same colour shows what it's doing right now: your character, or a Pokémon and an NPC from your sets. Each mod still works on its own, and either can be installed without the other. Up and down pick a row, left and right (or A) change it, and B closes it. Changes apply straight away and are saved to the same settings as the mod options.

* **NPCS** (this game's SET), **POKéMON** (the Pokémon SET), in FireRed and LeafGreen **ANIMS** (FR/LG ANIMS), then **CREDITS**.
* A preview of what you've picked: a starter from each region in turn, drawn the way the game draws it and playing its front animation when the game has one (so GBC Pokémon flip through Crystal's frames), and everyday NPCs (a nurse, a Youngster, a Lass and others) walking through all four facings with your set's sprites and fallbacks. The NPCs show once a game is loaded.
* Under the rows: the selected set's credit, or what OFF keeps.
* **CREDITS** (press A) opens a page with every set's credit in full, then Facets' own. Up and down scroll, left and right turn a page, B goes back.

The mod options still have every row for both families.

## Pokémon pictures

Every Pokémon picture in the Gen 3 games goes through two engine functions, `Pokemon.frontPic` and `Pokemon.backPic`, and Facets wraps both, so a set reaches every screen at once. Emerald's two-frame front animations are covered too, so a replaced Pokémon never flickers back to the game's own.

**GBC** reads Crystal's battle sprites from your own install (then Gold's, then Silver's) and colours them with Crystal's own palette for each species, so shinies are Crystal's shinies. That's all 251 Kanto and Johto Pokémon, Unown A to Z and the egg, none of it included. Hoenn's 135, Castform's weather forms, every Deoxys form and Unown ! and ? come from E-SY's GBC-style sprite compilation, which is included (`assets/mons/gbc/front` and `back`). The sheet has no shinies, so their shiny colours were worked out from the games' own Gen 3 shiny pictures (`tools/make_gbc_shinies.py`), matching what each shiny looks like in game. Spinda's front stays the game's own so it keeps its spots. Party icons (party, PC, summary and everywhere else Gen 3 shows them) change too, at the Game Boy's 16x16, standing at the bottom of Gen 3's icon space: Kanto and Johto from the Minidex 001-251 (by Chamber, Soloo993, Blue Emerald, Lake, Neslug and Pikachu25), a different icon for every Pokémon, and Hoenn from eeveeee1999's GBC-style icons, both included (`assets/mons/gbc/icons`). They bob between their two frames wherever the game animates its own icons (the party, the PC). The egg uses Crystal's own icon from your install, in Crystal's party-menu colours, as does any Pokémon a set has no icon for. Kanto and Johto Pokémon also play Crystal's own front animations (the frames each one flips through when it appears), read from your install with the rest, in place of Emerald's second frame; Emerald's movement still plays alongside them wherever the game animates. Each picture stands where the game's own would: centred, with its feet on the row the Gen 3 picture ends on. Without Crystal imported, only the Hoenn side changes.

**DS** is the DS-style 64x64 Pokémon Sprite Resource by Chaos Rush and many others: Gen 4-style fronts, backs and shinies for all 386 Pokémon, plus Castform's weather forms and each game's Deoxys (Attack in FireRed, Defense in LeafGreen, Speed in Emerald). It's included, used with credit. The resource has no Unown, so Unown stays the game's own; so does Spinda's front, since the game draws each Spinda's own spots.

A set is a folder under `assets/mons/` with a `meta.json` (`label`, `credit`) and 64x64 PNGs named by national number:

```
assets/mons/<set>/front/006.png
assets/mons/<set>/back/006.png
assets/mons/<set>/front_shiny/006.png     (optional; without one, shinies stay the game's own)
assets/mons/<set>/back_shiny/006.png
```

Unown's letters are `201.png` (A), `201_b.png` to `201_z.png`, `201_emark.png` and `201_qmark.png`; the egg is `egg.png`. Forms are `351_sunny`, `351_rainy`, `351_snowy` (Castform) and `386_attack`, `386_defense`, `386_speed` (Deoxys). Facets stands every picture on the game's own ground line for that Pokémon, so where the art sits in its frame doesn't matter. A set with `"source": "gb"` uses Crystal's sprites for anything it has no file for.

The GBC set's Hoenn sprites were cut from E-SY's sheet with:

```
python3 tools/make_gbc_hoenn.py tools/recipes/gbc_hoenn.json "<E-SY's GBC sprite sheet>.png" .
```

and its party icons from the Minidex GIF and eeveeee1999's Hoenn sheet with:

```
python3 tools/make_gbc_icons.py tools/recipes/gbc_icons_minidex.json "<Minidex 001-251>.gif" .
python3 tools/make_gbc_icons.py tools/recipes/gbc_icons.json "<eeveeee1999's icon sheet>.png" .
```

A set can have its own party icons too: `assets/mons/<set>/icons/NNN.png` (and `egg.png`), two frames stacked, each 16x16 (drawn at that size, at the bottom of the icon space) or 32x32.

and their shiny colours with:

```
python3 tools/make_gbc_shinies.py gen3 "<your gen1recomp install folder>" .
```

(`ds "<resource folder>"` instead of `gen3` takes the colours from a DS-style resource's normal and shiny frames instead.)

`tools/mon_convert.py` builds a set from a sprite resource of 256-wide sheets (front, shiny front, back, shiny back, on a solid background). The DS set was made with:

```
python3 tools/mon_convert.py tools/recipes/ds_mons.json "<The DS-style 64x64 Pokémon Sprite Resource folder>" .
```

The Pokémon side is `mons.lua`, `mon_names.lua` and `assets/mons/`, listed once in `main.lua`; an NPC-only build drops those.

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

`tools/npc_convert.py` turns Pokémon Essentials charsets (4x4: rows down, left, right, up) into Facets sheets. Upscaled packs are shrunk back only when that loses nothing, and the feet are lined up for you. A 2x sheet drawn a pixel off the even grid is found and shrunk too. If a walking frame reaches lower than the standing one, the feet go as close to that row as fits, so no frame loses pixels. A sheet with an empty frame stops with a message instead of converting.

Three options cover sprites in special poses, on the command line or in a recipe entry:

- `--lie-down` / `"lie_down": true`: the standing frame turned on its side, for a sprite lying on the ground.
- `--sit-down [ROWS]` / `"sit_down": ROWS`: the standing frames with ROWS of legs taken off, for a sprite sitting on the floor (default 2).
- `--down-only` / `"down_only": true`: for a sheet with only its facing-down row drawn; every facing uses it. One with a few touched-up pixels stops with a message saying how many; `--lossy` (or `"lossy": true` in a recipe) shrinks it anyway, each 2x2 block taking its most common colour. Run it on your own copy of a pack; the art doesn't go in this repo.

```
python3 tools/npc_convert.py one 123.png . --set hgss --family frlg --name NURSE
python3 tools/npc_convert.py one 123.png . --set hgss --family frlg --name NURSE --extra bow.png
python3 tools/npc_convert.py recipe tools/recipes/example.json <pack folder> .
```

A recipe lists which pack file is which NPC per family, plus the set's label and credits. See `tools/recipes/example.json`. Needs Python 3 and Pillow.

### HGSS (Neo-Spriteman's Resource Pack)

`tools/recipes/hgss.json` maps NPCs to the pack's `HGSS OVERWORLDS/Humans` sheets:

- **FireRed/LeafGreen (54):** the gym leaders, Elite Four, Rocket grunts, Oak, Bill, Daisy, Mom, nurses, clerks and most trainer classes.
- **Ruby/Sapphire/Emerald (43 in Emerald, 41 in Ruby and Sapphire):** the trainer classes HGSS shares with Hoenn, nurses, clerks, the TV crew, cycling triathletes and Steven. Hoenn's own characters (leaders, Elite Four, Aqua and Magma, Birch, Wally) have no HGSS version; the shipped sets cover them. The pack's file numbers are HGSS's own overworld model numbers (`MMODEL_*` in pret's pokeheartgold), which is how each one is identified.

```
python3 tools/npc_convert.py recipe tools/recipes/hgss.json "<pack>/HGSS OVERWORLDS/Humans" .
```

This writes `assets/npcs/hgss/`, which shows up as **HGSS** under SET. The art stays on your machine: `.gitignore` keeps everything in `assets/npcs/` out of the repo except the sets that ship (DIEGO, TAIGA, ZAFFRE, COMMUNITY and the test set).

### Taiga Collection

`tools/recipes/taiga.json` uses Taiga's ORAS-style trainers (plus a few Sword/Shield ones), which are free to use with credit. It's a second set, **TAIGA**, that fills gaps HGSS can't:

- **FR/LG (14):** tubers, the Crush Girl, a chef stand-in and the Mystery Gift courier.
- **R/S/E (20):** Ninja Boys, Rich Boys, Poké Fans, tubers, Battle Girls, Aroma Ladies, Guitarists, Cooltrainers.

It also gives Hoenn's trainer classes a Hoenn look. Several Emerald trainer classes share one townsperson sprite (`GIRL_3` is every Battle Girl, `MAN_5` every Guitarist, Bird Keeper and Kindler), which is why some rows name a townsperson. That list comes from pret's pokeemerald and pokefirered maps.

```
python3 tools/npc_convert.py recipe tools/recipes/taiga.json "<Taiga pack>/Collection" .
```

**TAIGA ships with Facets.** The recipe rebuilds it from the pack if needed.

### DiegoWT's OW PACK v2

`tools/recipes/diego.json` uses DiegoWT's Black/White-style trainers and townsfolk, which are free to use with credit. It's a third set, **DIEGO**:

- **FR/LG (22):** the main trainer classes, plus policeman, biker, captain, clerk, chef and Juggler, and a couple of townsfolk.
- **R/S/E (34):** fills Twins, Psychics, School Kids, the male cycling triathlete, the Artist, Breeders, the rooftop sale woman and several townsfolk that no other set has.

```
python3 tools/npc_convert.py recipe tools/recipes/diego.json "<pack>/OW PACK" .
```

The pack's player-character folders aren't used (players are Emerald Lens's job). **DIEGO ships with Facets.** The recipe rebuilds it from the pack if needed.

### COMMUNITY (KyleDove, Jext, Hyo, DiegoWT, Aqua)

`tools/recipes/community.json` covers every person the other free sets didn't, from two folders kept side by side: `Facets Missing` (trainers) and `Townsfolk` (townsfolk, staff, story characters, Frontier Brains).

- **FR/LG (44):** Kanto's gym leaders, Bruno, Lance, Team Rocket, trainer classes, swimmers, tubers, Oak, Bill, Daisy, Mom, Celio, the Teachy TV host, the Gym and Trainer Tower guides, Pokémon Center staff and townsfolk.
- **R/S/E (52):** the Elite Four, Aqua and Magma, Birch, Wally, Steven, Mom, Scott, the Frontier Brains, trainer classes, staff and townsfolk.
- **Three special cases**, made from ordinary sheets:
  - FR/LG's old man lying in Viridian's road is his standing frame turned on its side (`lie_down`).
  - The sitting boy is his standing frames with the legs taken off, set on the ground (`sit_down`).
  - Six Frontier Brains (Anabel, Brandon, Greta, Noland, Spenser, Tucker) only have a facing-down row, so they face the camera whichever way they turn (`down_only`) until full sheets turn up.

The art was gathered for Facets from KyleDove, Jext and Hyo, with some by DiegoWT and Aqua, all free to use with credit. **COMMUNITY ships with Facets.**

```
python3 tools/npc_convert.py recipe tools/recipes/community.json "<folder holding Facets Missing and Townsfolk>" .
```

### GBC (from your own install)

**GBC** gives Kanto and Hoenn a pseudo-demake look: the Gen 1/2 overworld sprites at their original 1x size, coloured with Crystal's daytime NPC palettes. It ships no art. `assets/npcs/gbc/gb.json` only says which Game Boy sprite and palette stands in for each NPC, and Facets reads the sprites from your gen1recomp install when the game starts. It looks in your imported Crystal first, then Gold, Silver, Yellow, Red and Blue, so Gen 1-only characters like Agatha, Lorelei and Mr. Fuji come from Yellow or Red.

- **FR/LG (60):** all eight gym leaders, the Elite Four, Giovanni, Team Rocket, Oak, Bill, Daisy, Mom, Mr. Fuji, Pokémon Center and Mart staff, and most trainer classes and townsfolk.
- **R/S/E (35):** the trainer classes, staff and townsfolk Gen 2 shares with Hoenn.

Everyone no Game Boy game has (14 in FR/LG, 69 in R/S/E: the Hoenn gym leaders, Elite Four, Frontier Brains, Aqua and Magma, Birch, Steven, Wally, tubers, triathletes and the rest) comes from Catwithnojob's Gen 2 Additional NPCs Pack, made in the Gen 2 style from TCG, Monster Race and Robopon characters. These are shipped as strips in `assets/npcs/gbc/strips/`, in the same layout as a Game Boy sprite and in their own colours; GBC 2X borrows them with the map. They're lookalikes, not the characters themselves, so swap any you'd pick differently.

The Pokémon standing around on the overworld (Snorlax, Lapras, the legendaries, Kecleon, Sudowoodo, Zigzagoon, the Pokémon in people's houses: 42 in FR/LG, 26 in R/S/E) are drawn the way Crystal draws its own: Crystal's overworld Pokémon where it has one (Entei, Raikou, Suicune, Sudowoodo, Slowpoke, the big Snorlax doll, and the generic bird, monster and fairy), Yellow's walking Pikachu, Seel, Chansey and Jigglypuff, and otherwise the party icon Crystal shows that Pokémon with on its maps (`{"icon": "fox", ...}` in `gb.json`). Rayquaza and the Regis stay the game's own. The Game Boy sets only fill gaps for each other, so picking another set never brings in Game Boy Pokémon.

If you haven't imported a game a sprite needs, that NPC comes from the next set instead, like any missing sheet. The sprites stay 16x16, so everyone is Game Boy-sized; standing-only Game Boy NPCs (like Crystal's nurse) walk on their standing frames.

**GBC 2X** is the same set drawn at double size, each Game Boy pixel a 2x2 block in a 32x32 frame. Chunky, a bit bigger than everyone else, and still no art: its meta.json borrows GBC's `gb.json` with `"map": "gbc"` and sets `"scale": 2`.

To change a pick, edit `gb.json`: each entry is a sprite name from `<game>/assets/generated/sprites/` in your install (or `"icon"`, a party icon from Crystal's `assets/generated/icons/gen2/`; `"big": true` draws a big doll like Snorlax's, its left half mirrored) and a palette (`PAL_OW_RED`, `PAL_OW_BLUE`, `PAL_OW_GREEN`, `PAL_OW_BROWN` or `PAL_OW_PINK`). A set with `"source": "gb"` in its meta.json is read this way; `"scale": 2` doubles it and `"map": "<set>"` uses another set's `gb.json` and `strips/`. An entry of `{"strip": "NAME"}` uses `strips/NAME.png` instead: 16 wide, 16x16 frames stacked (stand down, up, left, then walk down, up, left, or just the first three), alpha for see-through.

The strips are built from the pack by `tools/make_gbc_strips.py`, from `tools/recipes/gbc_strips.json`. Each strip names a pack sheet and its colour variant (`A` red, `B` blue, `C` green, `D` brown, the same as Crystal's palettes, or `-` for the sheet without a letter), and can be repainted in a Crystal palette (`"recolor": "PAL_OW_RED"`, used for Team Magma) or sat down (`"sit": 2`). It writes the strips and points `gb.json` at them; a sprite from your games always wins over a strip.

```
python3 tools/make_gbc_strips.py tools/recipes/gbc_strips.json "<pack>/Gen 2 Additional NPCs Pack" .
```

### PurpleZaffre's overworlds

`tools/recipes/zaffre.json` uses PurpleZaffre's own sheets (the `NPC_Z` files in the Ultimate Gen 4 Overworlds Pack). It's a fourth set, **ZAFFRE**, for the named characters no other pack has:

- **Hoenn (14):** all eight gym leaders (Tate and Liza separately), Wallace, Archie, Maxie, and Bird Keepers and male Breeders.
- **Kanto (4):** Agatha, Lorelei, Mr. Fuji and Giovanni.

```
python3 tools/npc_convert.py recipe tools/recipes/zaffre.json "<pack>/Zaffre's Overworlds" .
```

**ZAFFRE ships with Facets, ready to use, no converting needed.** PurpleZaffre's sprites are free to use with credit, though the pack itself isn't to be redistributed. So only the converted sheets Facets uses are included, and the recipe can rebuild them.

Pick a set under SET: the one picked wins where several have a sheet, and the others fill in the rest, in menu order. The shipped sets already cover every person in all five games, so HGSS only changes the look of the NPCs it has, when picked.

The recipe's `confidence` notes which matches are exact (named characters, trainer classes) and which are best guesses (generic townsfolk with no exact HGSS twin). In FR/LG the pack has no art for Agatha, Lorelei, Mr. Fuji, Celio, the Teachy TV host or the Trainer Tower and Gym guides; the shipped sets cover them. HGSS sheets have 9 frames, so the VS Seeker hand raise shows the standing frame. The nurse's sheet has her bow drawn in, and the recipe's `cells` list moves it to frame 9 so she still bows.

## Testing

`tools/make_test_set.py .` rebuilds the TEST FRAMES set. Each frame shows its number, and an arrow on the head shows which way it faces. Its meta.json has `"test": true`, so it's listed last under SET, is never the default, and only shows when picked.

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

DIEGO, TAIGA, ZAFFRE and COMMUNITY are included, used with credit. HGSS is Nintendo's art, so it's for you to convert yourself and isn't in this repo:

- **HGSS:** overworld sprites by Nintendo / Game Freak, from Neo-Spriteman's Resource Pack.
- **TAIGA (included):** overworld sprites by Taiga (Taiga Collection), free to use with credit. Taiga's sprites use assets, colours or inspiration from DiegoWT, Neo-Spriteman, Vanilla Sunshine, AtomicReactor, PurpleZaffre, izzyvivious and Tebited.
- **DIEGO (included):** overworld sprites by DiegoWT (OW PACK v2), free to use with credit.
- **ZAFFRE (included):** overworld sprites by PurpleZaffre (Zaffre's Overworlds, from the Ultimate Gen 4 Overworlds Pack), used with credit. Get the full pack from PurpleZaffre's own release, not from this repo.
- **COMMUNITY (included):** overworld sprites by KyleDove, Jext and Hyo, with some by DiegoWT and Aqua, all free to use with credit.
- **GBC and GBC 2X:** Gen 1/2 overworld sprites by Nintendo / Game Freak, read from your own imported games; none of it is included. The strips for everyone else (included) are by Catwithnojob (Gen 2 Additional NPCs Pack), free to use with credit.
- **DS (included):** the DS-style 64x64 Pokémon Sprite Resource by Chaos Rush, with sprites by Wizznats, jhajjar, Vapper3, atif, redriders180, cmbeke, Tailes, SneakerTheOtter, karatekid522, dreamengine, Rizon, Spark, MrDollSteak, PJBottomz, Archeops, dragonflye and Anvils Alive; free to use with credit.
- **GBC Pokémon:** Gen 2 battle sprites and palettes by Nintendo / Game Freak, read from your own imported Crystal, Gold or Silver; none of it is included. Hoenn, form and Unown ! and ? sprites (included) from E-SY's GBC-style sprite compilation, by Unknown, Neslug, Pokekoks, Matdemo159, RED, bloodless, Blue Emerald, LostImpact, Rangi, Piacarrot and Techmath; free to use with credit.
- **Sprite data:** which sprite each trainer class uses, and the HGSS overworld model names, come from pret's pokeemerald, pokefirered and pokeheartgold decompilations.
