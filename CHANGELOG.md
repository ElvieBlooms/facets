# Changelog

## Unreleased

- Red, Blue, Yellow, Gold, Silver and Crystal with **Kanto Reforged**: with **YOUR SIDE** on FRONT or MIRRORED, your Pokémon with Kanto Reforged art now shows its front (mirrored with MIRRORED) instead of Kanto Reforged's back, and plays Kanto Reforged's idle animation when it's sent out, as the foe's does. Before, only the foe's moved.
- Red, Blue and Yellow: Crystal's animation on the foe (CRYSTAL and the EMERALD look) now plays once it has slid in; in the wide layout it used to play, unseen, during the slide.
- Gold, Silver and Crystal: the start menu's help box ("Party PKMN status") now wears your TEXT BOX instead of a plain white patch, its words a letter in from the edge.
- Red, Blue and Yellow without full colour: full-colour sets (FIRERED, EMERALD, DS, DPPT, HGSS, B2W2) are turned into the four greys by their own brightness, so each colour area comes out one shade instead of speckled by its red alone.
- PERFORMANCE: with PREBUILD on, BW ANIM and the DS choices no longer read every Pokémon's animation at the start, which kept the game busy for minutes; each is read when that Pokémon turns up.
- Gold, Silver and Crystal: the wide battle's sides and boxes are no longer covered by the window's scenery, and its scene now reaches both ends of the field.
- Yellow: your partner Pikachu gets its own **PIKACHU** row under POKEMON for battle (MATCH, GAME, any POKEMON set, or a look), and **HGSS** on the map row walks it as HeartGold and SoulSilver's Pikachu, from your own dump, bobbing a pixel on each step as it does there.
- Red, Blue, Yellow, Gold, Silver and Crystal: **POKEMON: DPPT, HGSS and B2W2**, from your own DS dumps through Prism Importer, animated in battle on both sides as on Gen 3, with the DS set for anything missing.
- Red, Blue, Yellow, Gold and Silver: **Pokémon animations.** With your Crystal imported, **POKEMON: CRYSTAL** (now on Gold and Silver too), **FIRERED** and **EMERALD** play Crystal's animation when the foe's Pokémon comes out, as Crystal does. 
- FireRed, LeafGreen, Ruby, Sapphire and Emerald: **BATTLE BG: SCENERY** reaches the window's edges too. The borders round the GBA screen show the scene zoomed in, blurred and a little darker, instead of the engine's flat pale surround.
- Red, Blue, Yellow, Gold, Silver and Crystal: **BATTLE BG: SCENERY** now reaches the window's edges. When the window is wider or taller than the game screen, the borders round it show the same scene zoomed in, blurred and a little darker, instead of plain white or black; and the scene carries on behind the text box. Oak's Lab in Red, Blue and Yellow now gets the Lab scene (it's on the Dojo's tileset there, so it got Indoors before). New **SCENE COLOURS: GBC** raises the scenes' saturation and rounds them to the Game Boy Color's colours.
- **POKEMON: BW ANIM**: Black/White's animated Pokémon. With DarkHeros' BW Animated Sprites installed, Facets steps aside for it; without it, Facets loops each Pokémon's Black/White idle itself, fitted to 64x64, from the engine's Black/White import or Prism Importer's Black 2/White 2.
- **POKEMON: DPPT, HGSS and B2W2** (FireRed, LeafGreen, Ruby, Sapphire, Emerald): Pokémon from your own Diamond/Pearl/Platinum, HeartGold/SoulSilver and Black 2/White 2, through Prism Importer. A choice appears for each dump picked there; until it's imported, and for anything it lacks, the DS set stands in. Big fronts shrink to fit Gen 3's 64x64 and backs keep their top 64 rows. Fronts and backs both animate the whole time they're on screen: Black 2/White 2's full idles, and Gen 4's two frames on a steady beat.

## 1.1.1

- Red, Blue and Yellow: fixed a crash when a text box opened with **WINDOWS** on a set or a FireRed frame and **TEXT BOX** on GAME. The text box now uses the game's own, as it should.

## 1.1.0

- Crystal: with **YOUR SIDE** on FRONT or MIRRORED, your Pokémon now plays its front animation when it's sent out, as the foe's does, mirrored with MIRRORED. Before, only the foe's moved. Crystal animates only the foe's front picture, so Facets now runs the same animation for your side.
- **WINDOWS** and **TEXT BOX** are now two choices, in every game: WINDOWS for menu frames, TEXT BOX for the text box (and in Gen 3 signs and the battle text box), so LIBERTY's frames can go with TITO's WOODY, or Crystal's frames with the game's text box. TEXT BOX's **MATCH**, the default, follows WINDOWS, so your look stays as it was. On the Game Boy games LIBERTY's own frames now go round the menus (they were FireRed's frame 1 before, which needed FireRed imported).
- **WINDOWS: LIBERTY** now ships: LibertyTwins' ten DS-inspired window frames from Custom Text Boxes FR, with their text and sign boxes. Their thread confirms the frames are their own drawings.
- Red, Blue, Yellow, Gold, Silver and Crystal: a text box whose border sits on the inside of its edge tiles (LIBERTY's) moves out to the screen's edge so it no longer runs under the first and last letters; TITO's and FireRed's boxes stay where they were. The text box's inside colour now stops at its border, so the map shows round its corners as in Gen 3, instead of a white margin. Menu frames do the same: only the inside of a frame's border is filled, so rounded corners (LIBERTY's) show the map instead of white.
- **PERFORMANCE** shows [Prism Importer](https://github.com/ElvieBlooms/prism_importer)'s DS dumps when it's installed: DPPT, HGSS and B2W2, each IMPORTED, NOT YET, QUEUED, FAILED, MISSING or how far along it is. Without Prism Importer, PERFORMANCE is as it was.
- Tools: `ips_extract.py` reads `.ups` patches as well as `.ips`. New `tileset_package.py` turns an extracted tileset patch into tile sheets, palettes, block atlases, map layouts and previews, leaving out FireRed's own tiles, and `patch_layouts.py` follows the patched game's own map headers, so maps a patch resizes or moves to other tilesets come out as the patch has them.

## 1.0.2

- Red, Blue, Yellow, Gold, Silver and Crystal: PRISM's text shows with a translation pack's font. The pack's TTF prints in the current colour, and PRISM left it white, so the list was white on white. Its text is now drawn in black, as the game's own screens do, the same fix as Emerald Lens's and Crystal Lens's.

## 1.0.1

- Red, Blue and Yellow: tall grass no longer gets drawn across a set's taller people when someone in the grass stands right behind them (Oak walking you out of Pallet Town's grass).

## 1.0.0

Facets now covers all eleven of gen1recomp's games: Red, Blue, Yellow, Gold, Silver and Crystal join FireRed, LeafGreen, Ruby, Sapphire and Emerald. Facets, Emerald Lens and Crystal Lens all move to 1.0.0 together. Needs gen1recomp 0.3.98 or newer.

### The Game Boy games

- **A FACETS page** on the START and OPTION menus, shared with Emerald Lens and Crystal Lens through **PRISM**. Settings are saved with the game's options, and the last row, **CREDITS**, names everyone whose art Facets shows.
- **NPCS:** COMMUNITY, DIEGO, TAIGA and ZAFFRE on the Game Boy games, walking on both of Gen 3's steps, with changes showing straight away.
- **Fill-in sets** so every person has art: **JOHTO DS** (Jext, KyleDove and figyberries) for Johto's leaders, Elite Four and story people and Kanto's workers and staff, **DIONYUS1** for Yellow's Jessie, James and Officer Jenny, and the Gen 3-style **HEART & SOUL** and **KALARIE** for the GBA look. A person's own name is looked for in every set before any stand-in, so Mom in Crystal is Johto's and a Lass is a Lass.
- **PIKACHU** (Yellow): seven looks by vitorluiscolnago and piphybuilder88, with leParagon's battle pictures, worn by your partner Pikachu on the map, in battle, on its summary and in the Hall of Fame.
- **TRAINERS: DS** gives every trainer class a picture, Johto's included, with Young-Dante's Teacher and L-mon's Jessie and James.
- **POKEMON: DS** and **YOUR SIDE**, plus **CRYSTAL** (Crystal's own sprites) on Red, Blue and Yellow.
- **ICONS:** **MINIDEX**, a different icon for every Pokémon, and **CRYSTAL** on Red, Blue and Yellow.
- **The GBA look:** FIRERED and EMERALD under NPCS, TRAINERS and POKEMON, read from your own imported games, with Heart & Soul's and kalarie's Gen 3-style people for anyone neither game has, small walkers (the Little Boy and Little Girl) included. Emerald's Pokémon animate on Gold, Silver and Crystal.
- **SIZE** for Pokémon and for trainers, each on its own: FIT, FULL, SMALL or TINY.
- **BATTLE BG: SCENERY** behind the battle, picked from where you are (in wide battles on Red, Blue and Yellow), and **BATTLE UI** sets in wide battles.
- **WINDOWS:** FireRed's ten frames and its text box, or a TITO style, for every box in the game; the FACETS page shows the style on its own row.
- **COLORS** keeps the game in its full-colour mode while anything in Facets is on, and gives your own choice back when it's off.
- **The GB filter**, shared with the Gen 3 games, with three new colours: **YELLOW**, **GOLD** and **CRYSTAL** (in every game).
- **Achievements** count on the Game Boy games, with six of their own: **Advanced Class**, **Crystal Clear**, **Pika Pika!**, **Window Shopping**, **The Big Picture** and **Roll the Credits**. Each achievement only shows in the games it can be earned in.

### The Gen 3 games

- The Mt. Chimney cable car no longer errors on sets' Campers and Picnickers: a sheet with more than the scene's 15 colours is cut down to 15 there.
- The battle box sets that shipped in 0.7.0 (DP, PLATINUM, HGSS, BW and the B2W2 sets) are in the repo.
- Fixes from Emerald Lens (thanks Shane McGovern): meta.json files with a UTF-8 BOM or `\u` escapes read correctly; red info lines on the FACETS screen take the room first; long words in CREDITS are cut to the window; a game imported mid-session shows up without a restart; Scenic Route and Gem Collector progress reloads with a save.

### Tools

- `tools/import_rpgmaker.py` turns an RPG Maker sheet or a Gen 3 strip into a Game Boy overworld sheet.
- `tools/import_hns.py` copies Pokémon Heart & Soul's Johto people.
- `tools/make_pikachu.py` builds Yellow's Pikachu looks.
- `tools/make_gba_ids.py` writes the FireRed and Emerald sprite ids the GBA look reads.
