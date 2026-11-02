# Changelog

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
- **PICTURE SIZE:** FIT, 0.5X, 0.75X or 1X for Pokémon and trainers.
- **BATTLE BG: SCENERY** behind the battle, picked from where you are (in wide battles on Red, Blue and Yellow), and **BATTLE UI** sets in wide battles.
- **WINDOWS:** FireRed's ten frames and its text box, or a TITO style, for every box in the game; the FACETS page shows the style on its own row.
- **COLORS** keeps the game in its full-colour mode while anything in Facets is on, and gives your own choice back when it's off.
- **The GB filter**, shared with the Gen 3 games.
- **Achievements** count on the Game Boy games, with a new one, **Advanced Class**.

### The Gen 3 games

- The Mt. Chimney cable car no longer errors on sets' Campers and Picnickers: a sheet with more than the scene's 15 colours is cut down to 15 there.
- The battle box sets that shipped in 0.7.0 (DP, PLATINUM, HGSS, BW and the B2W2 sets) are in the repo.
- Fixes from Emerald Lens (thanks Shane McGovern): meta.json files with a UTF-8 BOM or `\u` escapes read correctly; red info lines on the FACETS screen take the room first; long words in CREDITS are cut to the window; a game imported mid-session shows up without a restart; Scenic Route and Gem Collector progress reloads with a save.

### Tools

- `tools/import_rpgmaker.py` turns an RPG Maker sheet or a Gen 3 strip into a Game Boy overworld sheet.
- `tools/import_hns.py` copies Pokémon Heart & Soul's Johto people.
- `tools/make_pikachu.py` builds Yellow's Pikachu looks.
- `tools/make_gba_ids.py` writes the FireRed and Emerald sprite ids the GBA look reads.
