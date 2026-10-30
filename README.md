<img width="910" height="568" alt="facets-gem-labelled-logo" src="https://github.com/user-attachments/assets/ff8c5589-1c21-4dc4-95e4-0cfa1d08c593" />

# Facets

NPC overworld sprites for the Gen 3 games in gen1recomp: FireRed, LeafGreen, Ruby, Sapphire and Emerald. Townsfolk, trainers, nurses, gym leaders and villains can each get new art, one sheet at a time. Anything without a sheet stays the game's own.

Facets can also swap Pokémon pictures, party icons and animations (Crystal's sprites with a Game Boy Hoenn made from your own Emerald, animations and all, every Pokémon made Game Boy from your Emerald, Crystal's sprites with Nuuk's animated Hoenn, or the DS-style 64x64 resource), show your own Pokémon by their front, and give the whole screen a Game Boy filter (below).

Facets is the companion to [Emerald Lens](https://github.com/ElvieBlooms/emerald_lens): Emerald Lens does the player and the rival, Facets does everyone else. They never touch the same sprites, so they work together in either load order.

**Status: 0.6.1.** Works in all five games. It ships with four sprite sets, all free to use with credit:

- **DIEGO:** DiegoWT's Black/White-style trainers and townsfolk.
- **TAIGA:** Taiga's ORAS-style trainers.
- **ZAFFRE:** PurpleZaffre's named characters (Hoenn's gym leaders, Wallace, Archie and Maxie; Agatha, Lorelei, Mr. Fuji and Giovanni).
- **COMMUNITY:** custom sprites by KyleDove, Jext and Hyo (with some by DiegoWT and Aqua) for everyone else: Kanto's gym leaders, Bruno and Lance, Team Rocket, Oak, Bill and Daisy, Hoenn's Elite Four, Aqua and Magma, Birch, Wally, Steven, the Frontier Brains, Pokémon Center staff and townsfolk.

Together they give **every person in all five games** new art, with no converting needed: 74 NPCs in FireRed/LeafGreen, 104 in Emerald and 98 in Ruby/Sapphire. That's every trainer, townsperson, staff member and story character; checked against the games' sprite tables and pret's maps. Objects keep the game's art, and Pokémon have their own option. HGSS art (Nintendo's) isn't included; its recipe is still there if you'd like HGSS's look for the NPCs it has. A numbered TEST FRAMES set is included for checking frame order; it's only used when picked.

There are also two Game Boy looks, **GBC** and **GBC 2X** (below): Gen 1/2 overworld sprites read from your own imported Crystal, Gold, Silver, Yellow, Red or Blue, with Catwithnojob's Gen 2-style sprites for everyone the Game Boy games never had. With a Gen 1/2 game imported, they cover every person in all five games too.

The trainers you battle get new pictures too: **DS** (Gen 4+ style, every trainer picture in all five games), **GBC-ISH** (Crystal's and Yellow's trainers from your install, plus hand-made Gen 2-style art for Hoenn) and **GAME BOY**. See [Trainer battle pictures](#trainer-battle-pictures).

## Options

Under the mod's options there's a heading per game family (FR/LG, R/S/E) with **SET**: each sprite set you have, or OFF for the game's own NPCs. Changes apply straight away.

If the selected set doesn't have a sheet for someone, the other sets are tried in menu order, then the game's own sprite.

**TRAINERS** has its own **SET** for the pictures of the trainers you battle (also in the Hall of Fame, the PokéNav and the Battle Dome). It's OFF by default; see [Trainer battle pictures](#trainer-battle-pictures).

Below those, **POKEMON** has its own **SET** for Pokémon pictures (battle, summary, Pokédex, PC, evolution, trades and the rest). It's OFF by default, so Facets only changes Pokémon when you ask it to. One choice covers all five games.

**FR/LG ANIMS** gives FireRed and LeafGreen Emerald's front animations: the hop, shake or spin each Pokémon does when it appears or cries, in battle, on hatching, after evolving and in the PC. FR/LG never had them, so Facets reads them from your own imported Emerald (nothing is included), and the option does nothing without one. Emerald's animations flip to a second picture drawn on Emerald's art, and FR/LG redrew most of Kanto (188 Pokémon), so with this on those Pokémon's front pictures are Emerald's, standing on FR/LG's ground line, and they animate in full. Their backs stay FR/LG's, and so does everything that looks the same in both games. It's OFF by default.

**YOUR SIDE** shows your own Pokémon by their front picture instead of their back: in battle, in contests, and anywhere else the game uses a back picture. It's BACK by default. FRONT lifts the front picture until its feet stand just above the text box (with a pixel spare for the bob while you pick a move), so you see the whole Pokémon rather than a back cut off by the box (anything already higher, like a floating Pokémon, stays where its back would be). A Pokémon too tall to clear the box keeps its whole top and lets its feet dip a few pixels behind the box instead. It works with any SET or with the game's own pictures. In battle, your Pokémon then play their front animation (the same one the foe's side plays, frames and all, wherever the game or FR/LG ANIMS has one) in place of the back one, without a second cry. **MIRROR FRONTS** flips those front pictures, and their animations' moves, so your Pokémon face the foe. It's ON by default and does nothing while YOUR SIDE is BACK.

**SPEED** has **PREBUILD**, for small boards, handhelds and anything else where a hitch shows. Facets makes many of its pictures itself, the first time they're needed: GB EMERALD and GBC-ISH Pokémon from your Emerald, Crystal's sprites in their colours, Emerald's art for FR/LG ANIMS, YOUR SIDE's turned-around pictures and the GBC NPCs. On a fast machine that's a few milliseconds each; on a small one, a stutter when a battle starts or a new NPC walks on. With PREBUILD ON:

* Everything your settings need is built in the background from the title screen on, a few milliseconds a frame (Pokémon straight away, NPCs once a map is loaded), so it's ready before it's needed. Shiny pictures are left to when one turns up.
* What's built is kept on your install, in the engine's per-install mod cache (the place it keeps for data made from your own games, never inside your saves), so the next start reads it back instead of building it again. Pictures built as they're needed are kept too, at the end of a battle, on a map change and when you save. Changing a setting builds what the new one needs.
* It's all made again only when something it was made from changes: a new Facets, a new gen1recomp (or ROM cache generation), or a game imported again. The old copies are deleted then.
* It costs memory: every picture for your sets stays loaded (roughly 50 MB for a Game Boy set with YOUR SIDE: FRONT), and a few MB on disk.

It's OFF by default. It doesn't change the GB filter, which is drawn fresh every frame either way.

PREBUILD is also on its own **PERFORMANCE** screen, a second entry in PRISM (the FACETS screen has no room for more rows). It has three rows:

* **PREBUILD**: OFF or ON, the same option.
* **BUILD NOW**: builds everything at once (turning PREBUILD on if it's off), spending much more of each frame on it, with a progress bar; B leaves it carrying on in the background. DONE once everything's built.
* **KEPT**: CLEAR deletes the kept pictures, so they're built and kept fresh next start, in case anything ever looks wrong.

Under the rows, the progress: BUILDING with a count, ALL READY, or ALL READY, KEPT once it's written to your install. PRISM's own list shows PREBUILD (ON, OFF, or how far it's got) beside PERFORMANCE, and its corner shows the bar.

### The FACETS screen
The same choices for the game you're playing are on a screen of their own, laid out like Emerald Lens's LENS screen. It's reached through **PRISM**, on the START menu (above MODS, or EXIT) and the OPTION menu: a short list of FACETS (with your NPC set), PERFORMANCE (PREBUILD) and SCREEN (the filter), plus EMERALD LENS (with your character) when Emerald Lens is installed too, since the two share the one item. Picking one opens its screen; B there comes back to the list. Each has its own gem in the list (emerald for Emerald Lens, amethyst for Facets, topaz for PERFORMANCE, sapphire for SCREEN); the header takes the picked one's colour, and a faceted corner in the same colour shows what it's doing right now: your character, or a Pokémon and an NPC from your sets. Each mod still works on its own, and either can be installed without the other. Up and down pick a row, left and right (or A) change it, and B closes it. Changes apply straight away and are saved to the same settings as the mod options.

* **NPCS** (this game's SET), **TRAINERS** (the trainer SET; its preview shows trainers from the game taking turns), **POKéMON** (the Pokémon SET), in FireRed and LeafGreen **ANIMS** (FR/LG ANIMS), **YOUR SIDE** (BACK, MIRRORED or FRONT: both options in one row; MIRRORED is FRONT with MIRROR FRONTS on), then **CREDITS**. On YOUR SIDE the preview shows your side's picture.
* A preview of what you've picked: a starter from each region in turn, drawn the way the game draws it and playing its front animation when the game has one (so GBC Pokémon flip through Crystal's frames), and everyday NPCs (a nurse, a Youngster, a Lass and others) walking through all four facings with your set's sprites and fallbacks. The NPCs show once a game is loaded.
* Under the rows: the selected set's credit, or what OFF keeps.
* **CREDITS** (press A) opens a page with every set's credit in full, then Facets' own. Up and down scroll, left and right turn a page, B goes back.

The mod options still have every row for both families.

## The GB filter

Under **SCREEN**, four options give the game a Game Boy look (and three more give its windows and battle boxes Gen 2's, [below](#gbc-windows-and-hp-boxes)). They're also on their own **SCREEN** page in PRISM (as FILTER, SHADES, WHERE and DOTS; SHADES shows with the shade palettes), whose corner shows the picked look's shades.

* **FILTER**: **GRAY** turns everything into the Game Boy Pocket's four greys, **GREEN** the original Game Boy's four greens, and **RUBY**, **SAPPHIRE** and **EMERALD** four shades of each gem, for the games themselves (EMERALD is bluer and deeper than GREEN). **GBC** keeps colour but cuts each channel down to four levels, for the flat, bright look of a Game Boy Color game. **OFF** (the default) leaves the game's own colours.
* **SHADES**: how many shades GRAY, GREEN, RUBY, SAPPHIRE and EMERALD use: **4** (the default, like a Game Boy), **8** or **16** for smoother shading and more of the scene's detail. The extra shades are blended between the four palette colours.
* **FILTER ON**: **SCREEN** (the default) filters everything: the map, sprites, menus and battles. **MAP** filters only the map and everyone on it, so menus, text boxes and battles keep their colours.
* **DOTS**: a dot-matrix grid between the game's pixels, like an old handheld's screen. It works with any filter or none, over the whole screen.

They go well with the GBC NPCs and the GBC-ISH Pokémon, for a Gen 3 game that looks like it came out in 1998. All three change straight away.

How it works: the whole-screen filter and DOTS are a render pipeline, the engine's own way for a mod to post-process the finished frame, and the engine saves it with the game's options. MAP uses the render.compose hook instead, which sees the map before the menus are drawn over it. Neither needs anything from the games. For GRAY and GREEN, each pixel's brightness picks one of the four shades. Gen 3 is much brighter than a Game Boy game (half a typical scene is brighter than 85%), so the cut-offs between shades sit high. The cut-offs, GBC's levels and saturation, and how dark the dot grid is are all at the top of `filter.lua` if you'd like to tune them.

### GBC windows and battle UI

Three more options under **SCREEN** (and on the SCREEN page) give the game's windows and battle boxes Gen 2's look, drawn from Crystal's own art in your imported Crystal (then Gold, then Silver), so nothing is included. Each keeps Gen 3's layout: only the frames, bars and background change.

* **WINDOWS**: **GBC 1** to **GBC 8** are Crystal's eight window frames (its TYPE option), on white, for every text box, sign, menu and yes/no box, the FACETS screens included, and for the battle text box, which splits into Crystal-framed boxes the way the game splits its own (message, FIGHT/BAG/POKéMON/RUN, moves and PP). Battle text that Gen 3 writes white on its dark box is written dark on the white one. After those come the window sets' styles (below). **GAME** (the default) keeps the game's own.
* **BATTLE UI**: **GBC** draws the healthboxes the way Gen 2 does: no box, Crystal's HP bar ("HP:" and six cells, green, yellow or red by Gen 2's own maths) with the bracket under it, and Crystal's EXP bar filling from the right on your side. Names, levels and HP numbers stay where the game puts them. In double battles the boxes go and the bars change, without brackets. After GBC come the battle box sets (below).
* **BATTLE BG**: **WHITE** swaps the scenery and platforms for Crystal's plain white. **SCENERY** (included) swaps them for the Battle Backgrounds Patch FR's twenty scenes, by **LibertyTwins, princess-phoenix, carchagui, aveontrainer, WesleyFG, kWharever, worldslayer608 and knizz**, used with credit: each of the games' backgrounds is mapped to one (grass to Grass, tall grass to Forest, sand to Beach, ponds to Lake, buildings to Lab, routes' trainers to Route, gyms, leaders and the Elite Four to Gym, the Champion to Space, and in Emerald Groudon and Team Magma to Volcano, Kyogre and Team Aqua to Sea, Rayquaza to Space, the Frontier to Neutral). It's separate from the other two, so it works with either, or with the game's own boxes. A battle background set is a folder in `assets/battlebg/` with 240x112 scenes and a meta.json mapping the games' background names to them, built with `python3 tools/make_battle_bg_set.py tools/recipes/battlebg_scenery.json . "<the patch's Resources folder>"`.

On the SCREEN page, the WINDOWS, BATTLE UI and BATTLE BG rows show a sample square in the window's corner, drawn with what's picked: the text box for WINDOWS, your healthbox over the message box for BATTLE UI, and the foe's side of the scene for BATTLE BG.

Without a Gen 1/2 game imported, WINDOWS' GBC frames and BATTLE UI' GBC draw the game's own and the SCREEN page says so; the window sets and BATTLE BG need nothing.

#### Battle box sets

A battle box set replaces the battle healthboxes, HP and EXP bars and battle text box with ones from a FireRed patch, in all five games. Ruby and Sapphire keep their own status icons and the tiles under the name (their HP sheet differs from FireRed's there), in the set's colours. Included, all used with credit:

* **XY**: XY-style healthboxes, bars and text box by **Verloren 5** (XY-Styled Battle Boxes).
* **GAIA**: healthboxes and bars by **YoY-X and Spherical Ice** (Gaia HP Boxes).
* **DP, PLATINUM, HGSS, BW, B2W2 BLACK and B2W2 WHITE**: Gen 4 and 5-style healthboxes and bars from DPPtHGSSBWB2W2 Styled Battle Boxes and HP Bars: DP by **Dinisk, Prof. Leon Dias, Neon Skylar and Verloren 5**; PLATINUM by **Omega Zero and Verloren 5**; HGSS by **YoY-X, Neon Skylar, Jaizu and Verloren 5**; BW by **Vytron and Verloren 5**; B2W2 BLACK and WHITE by **Verloren 5**.
* **B2W2**: Black 2 and White 2-style healthboxes, HP and EXP bars by **Verloren 5** (B2W2 HP Bars, from LibertyTwins' BW Patch Collection FR, whose terms are to credit the creators of any patches used).
* **TEX BOX**: a battle text box by **Cesar Alarcon** (Battle Tex Box).
* **PLAIN**: a plain grey battle text box by **Neon Skylar** (Plain Battle Box).
* **ZEKE BLUE, DARK BLUE, DARK GREEN, GREEN, ORANGE, RED and VIOLET**: recoloured healthboxes by **Zeke** (HP Bar Recolours).

A piece a patch redrew is its picture; a piece it only recoloured is the game's own picture in its colours, made while you play. Names, levels and HP numbers on the boxes take the set's colours too. A set that redraws the party bar (the line of Poké Balls when a trainer sends out their team) changes that too. The menus in the text box (FIGHT/BAG, the moves) stay the game's, as they do with the patch, since the game draws those in your window frame.

A battle box set is a folder in `assets/battleui/` with the pictures (laid out the way the engine lays out FireRed's) and a meta.json holding the patch's palettes, built from a patch that `ips_extract.py` has pulled apart: `python3 tools/make_battle_ui_set.py extracted/<patch> . <set> "<LABEL>" "<credit>"`. The text box needs FireRed's text box map, which the tool fetches from pret's pokefirered the first time.

#### Window sets

A window set is a folder in `assets/windows/` with Gen 3-format window art: menu frames (24x24, 3x3 tiles), a dialogue box (18 tiles) and a signpost box (19 tiles), plus a meta.json naming its styles. Each style shows in WINDOWS as the set's label and the style's name. Its frame replaces menus, yes/no boxes and the FACETS screens' windows, and its dialogue box the text box and signs, drawn exactly the way Gen 3 draws its own; anything a style doesn't have stays the game's. Battle boxes stay the game's own with a set.

* **TITO** (included): ten dialogue boxes by **Tito Seich / Sage** (Checkered, Cool Red, Emerald, Hoenn, Orange, Red, Silver, Sky Blue, Square Red and Woody), used with credit. Menus keep the game's own frames.

Sets are built from a pack's own images with:

```
python3 tools/make_window_set.py tools/recipes/windows_tito.json . "<The Textbox of Tito Seich folder>"
```

`tools/recipes/windows_libertytwins.json` builds **LIBERTY** from LibertyTwins' Custom Text Boxes FR the same way: ten frames with their dialogue and sign boxes. It doesn't ship until it's confirmed the frames are LibertyTwins' own drawings, so it stays on your machine (`.gitignore`).

##### From IPS patches

Most text box patches, and most other FireRed patches, only come as `.ips` files. `tools/ips_extract.py` reads them with your own FireRed 1.0 ROM, without patching anything on disk (each patch is applied to a copy in memory), and pulls out everything they change, sorted by kind:

```
python3 tools/ips_extract.py "<FireRed 1.0 ROM>" . "<a patch, a folder of patches, or a .zip>"
```

* A folder or zip is searched for every `.ips` inside, zips in zips too, so a whole pack can go in at once.
* Every changed piece of the ROM is named with pret's FireRed symbols (`pokefirered.sym`, fetched from GitHub the first time and kept beside the tool, or given with `--sym`), and sorted into **audio**, **tilesets**, **battle_backgrounds**, **battle_anims**, **battle_scripts**, **battle_ui**, **pokemon** (pictures and data), **trainers**, **overworld**, **windows_fonts**, **items**, **menus**, **text**, **maps_scripts** (scripts, map data and wild encounters), **sprite_tables**, **graphics** (any other picture or palette), **code**, **other** and **new_data** (bytes nothing points at, often injected code). A piece the patch moved elsewhere in the ROM is found by following the pointers to it.
* Each lands in `extracted/<patch>/<kind>/` as its bytes (unpacked if LZ77-compressed), with a PNG for graphics (coloured by the palette of the same name when there is one, grey otherwise), a glyph sheet for fonts, a swatch PNG for palettes, and a WAV for sound samples. Two patches with the same name from different packs get separate folders. Songs stay as their raw sequence data. `report.md` in each patch's folder lists every piece, whether it was edited in place or moved, where and how big; `extracted/index.md` sums up every patch. `--out` puts them somewhere else.
* When a patch changes the option-menu frames, the dialogue box or the signpost box, those also become a window set (`assets/windows/x_<patch>/`) with the credits from any `#CREDITS.txt` or README beside the patch, ready for WINDOWS.

It only accepts FireRed 1.0 (BPRE), which the patches are made for. The art and sound are the patch authors', and many DS-style patches carry the DS games' own, so all of it stays on your machine: `.gitignore` keeps `extracted/` and `assets/windows/` out, except the sets that ship.

## Trainer battle pictures

The trainer you battle is drawn from one engine function, `TrainerPic.front`, and Facets wraps it, so a TRAINERS set reaches every screen that shows a trainer's battle picture. Three sets ship:

* **DS**: Gen 4+ style trainers by **KyleDove** (from his XY, ORAS, USUM, SWSH and Ga-Olé trainer class sets), **Mr. Gela** (theo#7722), and more by **KyleDove**, **Jext** and **figyberries**, all used with credit and included. They cover every trainer picture in all five games (all but the player's own, which Emerald Lens keeps; Ruby and Sapphire's own names for Emerald's pictures find them too): the everyday classes, every gym leader, Elite Four and champion in both regions, the FR/LG rival, Teams Aqua, Magma and Rocket, Wally, Steven, Professor Oak and the Frontier Brains. Tate and Liza and the Old Couple are each drawn as two people, stood side by side in one picture. A few are stand-ins: a Roughneck as the Cue Ball, Mr. Gela's second Guitarist as the Rocker, his Double Team as the Cool Couple, and KyleDove's Worker as the Engineer. Most of the art is about 80 pixels tall, the DS games' size, so each is shrunk to fit Gen 3's 64x64 trainer frame.

* **GBC-ISH**: 53 Gen 3 trainers have a Gen 1/2 counterpart, and those are drawn as that trainer: Crystal's battle picture (then Gold's or Silver's) in Crystal's own two colours for it, read from your imported game. Kanto's gym leaders, Bruno and Lance, the Youngster, Lass, Hiker, Rocket Grunts, swimmers and the rest are Crystal's; the Gen 1-only ones (Giovanni, Lorelei, Agatha, the Gamer and Blue as your rival) are Yellow's (then Red's or Blue's), in the Crystal colours of a similar trainer. Hoenn's leaders and villains have Gen 2-style pictures of their own, included and used with credit: the gym leaders (but Juan), the Elite Four, Wallace and Steven by **jphyper**, the Battle Frontier Brains by **sirwhibbles**, and Archie, Maxie and the male Aqua and Magma grunts by **eli76**. Most of Gen 3's new trainer classes are **SkidMarc25**'s Gen 2-style sprites (the Battle Girl, Bug Maniac, Collector, triathletes on foot and on bikes, Experts, Interviewer, Lady, Painter, Breeders, Rangers, Psychic, Rich Boy, Ruin Maniac, School Kid and Tubers), as are the Channeler, Cue Ball, Engineer, Rocker and Tamer in place of Yellow's, all included and used with credit. Every other trainer (Juan, Wally, the admins, the female grunts, the pairs and couples, the swimming triathletes, the Aroma and Parasol Ladies, the Dragon Tamer, Hex Maniac and Ninja Boy) is the game's own picture made Game Boy while you play, in 4 flat shades. The map is `assets/trainers/gbcish/gb.json`.
* **GAME BOY**: every trainer is the game's own picture made Game Boy in 4 shades, so it needs no other game.

Each picture stands where the game's own does: centred, its feet on the row the game's picture ends on. The Game Boy pictures' white background is cut away from the top and sides (not the bottom, where the trainer is cut off and white clothes can reach the edge).

The player's own pictures are never touched, and any picture another mod has already swapped stays as it is, so with Emerald Lens your character and your rival keep Lens's art. Without a Gen 1/2 game imported, GBC-ISH's preview says so and those trainers are made from the game's own pictures instead. With PREBUILD on, every trainer picture is built ahead and kept.

A set can also have its own pictures: `assets/trainers/<set>/<NAME>.png`, up to 64x64 (GBC-ISH's are Gen 2's 56x56), drawn in their own colours, named by the game's picture name without `TRAINER_PIC_` (`YOUNGSTER.png`, `LEADER_BROCK.png`; FR/LG's `RS_` versions use the same name). DS is one of those, built with:

```
python3 tools/make_trainer_set.py tools/recipes/ds_trainers.json . kyle_xy="<XY folder>" kyle_oras="<ORAS folder>" kyle_usum="<USUM folder>" kyle_swsh="<SWSH folder>" kyle_gaole="<Ga-Ole folder>" gela="<Mr. Gela's Characters folder>" more="<DS_Trainers folder>"
```

The recipe lists, for each Gen 3 trainer, which artist's file to use, first one found wins; the tool halves doubled art, shrinks anything bigger than 64x64 to fit, and stands it at the bottom of the frame. Add a trainer to the recipe and run it again to fill a gap.

## Pokémon pictures

Every Pokémon picture in the Gen 3 games goes through two engine functions, `Pokemon.frontPic` and `Pokemon.backPic`, and Facets wraps both, so a set reaches every screen at once. Emerald's two-frame front animations are covered too, so a replaced Pokémon never flickers back to the game's own.

**GBC-ISH** is the Game Boy Color look for all 386. Kanto, Johto, Unown and the egg are Crystal's battle sprites, read from your own install (Crystal, then Gold, then Silver), coloured with Crystal's own palette for each species, so shinies are Crystal's shinies, and they play Crystal's own front animations. Hoenn, which Crystal never had, is made while you play from your own imported Emerald's pictures, so nothing is included: each picture's pixels are sorted into 8 shades by brightness (black, white and six between), and each shade takes the colour it covers most, snapped to the Game Boy Color's colours. Hoenn's fronts are made from both frames of Emerald's front animation, so they keep their animations, and its shinies come from Emerald's shiny pictures on the same shading. Backs are Crystal's for Kanto and Johto and made from Emerald's for Hoenn; Castform's weather forms, which Emerald doesn't animate, come from their still pictures. In FireRed and LeafGreen it turns on Emerald's animations by itself, as FR/LG ANIMS does, and stands each Hoenn picture on FR/LG's ground line. Without Crystal imported, Kanto and Johto are made from Emerald's pictures too; without Emerald, from the running game's own. Spinda's front stays the game's own so it keeps its spots. Party icons (party, PC, summary and everywhere else Gen 3 shows them) change too, at the Game Boy's 16x16, standing at the bottom of Gen 3's icon space: Kanto and Johto from the Minidex 001-251 (by Chamber, Soloo993, Blue Emerald, Lake, Neslug and Pikachu25), a different icon for every Pokémon, and Hoenn from eeveeee1999's GBC-style icons, both included (`assets/mons/gbcish/icons`). They bob between their two frames wherever the game animates its own icons (the party, the PC). The egg uses Crystal's own icon from your install, in Crystal's party-menu colours.

**GB EMERALD** is GBC-ISH's Hoenn treatment for everyone: all 386 are made from your own Emerald's pictures, Kanto and Johto too, in the same 8 Game Boy Color shades, with Emerald's two animation frames and shinies. It reads nothing from Crystal (`"crystal": false` in its meta.json), and its party icons are the game's own.

**GBC ANIM** is GBC-ISH with Nuuk's hand-drawn Hoenn. Kanto, Johto, Unown and the egg are the same as GBC-ISH (Crystal's own, from your install, with Crystal's animations). 92 of Hoenn's Pokémon (Treecko to Crawdaunt, plus Snorunt and Glalie) are Nuuk's Crystal-style sprites, which are included (`assets/mons/gbc_anim`): fronts, backs, shiny colours and each one's own Crystal animation, played the same way as Crystal's. Nuuk's sprites are free to use with credit, not for profit. Everything else (Baltoy to Deoxys, apart from Snorunt and Glalie, plus Castform's and Deoxys's forms and Unown ! and ?) and the party icons come from GBC-ISH, through `"fallback": "gbcish"` in its meta.json, so those are made from your Emerald with Emerald's animation frames. Emerald's movement plays alongside Crystal's frames wherever the game animates. Each picture stands where the game's own would: centred, with its feet on the row the Gen 3 picture ends on. Spinda stays the game's own so it keeps its spots.

**DS** is the DS-style 64x64 Pokémon Sprite Resource by Chaos Rush and many others: Gen 4-style fronts, backs and shinies for all 386 Pokémon, plus Castform's weather forms and each game's Deoxys (Attack in FireRed, Defense in LeafGreen, Speed in Emerald). It's included, used with credit. The resource has no Unown, so Unown stays the game's own; so does Spinda's front, since the game draws each Spinda's own spots, and Anorith's front, since the resource's is Gen 3's own outline re-shaded.

A set is a folder under `assets/mons/` with a `meta.json` (`label`, `credit`) and 64x64 PNGs named by national number:

```
assets/mons/<set>/front/006.png
assets/mons/<set>/back/006.png
assets/mons/<set>/front_shiny/006.png     (optional; without one, shinies stay the game's own)
assets/mons/<set>/back_shiny/006.png
```

Unown's letters are `201.png` (A), `201_b.png` to `201_z.png`, `201_emark.png` and `201_qmark.png`; the egg is `egg.png`. Forms are `351_sunny`, `351_rainy`, `351_snowy` (Castform) and `386_attack`, `386_defense`, `386_speed` (Deoxys). Facets stands every picture on the game's own ground line for that Pokémon, so where the art sits in its frame doesn't matter.

A set with `"source": "gb"` is a Game Boy set. It reads Crystal's sprites from your install for anything it has no file for, then makes the rest from the game's own pictures in Game Boy shades; with `"builtFrom": "emerald"` (GBC-ISH) it makes them from Emerald's pictures, with Emerald's animation frames. `"builtShades"` sets how many shades those made pictures use: 4 (as flat as a Game Boy sprite), 8 or 16. A set with `"fallback": "<set>"` in its meta.json takes anything it doesn't have from that set.

A set can animate its own fronts the same way Crystal does: `anim/NNN.png` (every picture of the animation stacked, base first, at the sprite's own size), `anim_shiny/NNN.png`, and `anim/NNN.json` with Crystal's script as numbers: `{"tiles": 5, "play": [[frame, ticks], ...], "idle": [...]}`, where `[254, n]` is setrepeat and `[253, i]` dorepeat. GBC ANIM's Hoenn Pokémon were built from Nuuk's pack with:

```
python3 tools/make_gbc_anim.py tools/recipes/gbc_anim.json "<Crystal_GFX_files>.zip" .
```

A set can have its own party icons too: `assets/mons/<set>/icons/NNN.png` (and `egg.png`), two frames stacked, each 16x16 (drawn at that size, at the bottom of the icon space) or 32x32. GBC-ISH's were made from the Minidex GIF and eeveeee1999's Hoenn sheet with:

```
python3 tools/make_gbc_icons.py tools/recipes/gbc_icons_minidex.json "<Minidex 001-251>.gif" .
python3 tools/make_gbc_icons.py tools/recipes/gbc_icons.json "<eeveeee1999's icon sheet>.png" .
```

`tools/mon_convert.py` builds a set from a sprite resource of 256-wide sheets (front, shiny front, back, shiny back, on a solid background). The DS set was made with:

```
python3 tools/mon_convert.py tools/recipes/ds_mons.json "<The DS-style 64x64 Pokémon Sprite Resource folder>" .
```

The Pokémon side is `mons.lua`, `mon_names.lua` and `assets/mons/`, listed once in `main.lua`; an NPC-only build drops those.

### With SPRITE SWAPPER (and other sprite pack mods)

[SPRITE SWAPPER](https://github.com/artyrambles/ST_SPRITESWAPPER) by artyrambles swaps Pokémon pictures for sprite packs through the engine's `pokemon.sprite` and `pokemon.icon` hooks. Facets steps aside for it: when the pack you've picked there (or any mod using those hooks) has a picture for a Pokémon, that picture shows, front, back and icon, whatever Facets' SET or FR/LG ANIMS say. Facets fills in only what the pack doesn't have, so with a pack picked and a SET on, a Pokémon the pack leaves out still gets the set's picture. A pack's Pokémon keep the pack's picture through their whole animation instead of flashing Facets' or Emerald's art mid-move. YOUR SIDE: FRONT still works, using the pack's front. When the FACETS screen's preview has a pack's Pokémon in it, the POKéMON row says so. With no pack picked, nothing changes.

Facets' own art can go the other way too: `tools/make_sprite_swapper_pack.py` turns a set into a SPRITE SWAPPER sprite pack (Gen 3 only, and it needs SPRITE SWAPPER). Each picture is stood where the game's own would stand, using FireRed and LeafGreen's height offsets from gen1recomp's source, so in FR/LG a pack picture lands exactly where Facets puts it; in Ruby, Sapphire and Emerald a few redrawn Kanto Pokémon stand a pixel or two off. Two recipes are included:

```
python3 tools/make_sprite_swapper_pack.py tools/recipes/sprite_swapper_ds.json . "<gen1recomp folder>" "<out folder>"
python3 tools/make_sprite_swapper_pack.py tools/recipes/sprite_swapper_nuuk.json . "<gen1recomp folder>" "<out folder>"
```

- **FACETS DS**: the DS set (fronts, backs, shinies and Castform's weather backs). Deoxys is left out, since SPRITE SWAPPER has one picture for every game and each game shows its own form.
- **NUUK HOENN**: Nuuk's 92 Hoenn Pokémon from GBC ANIM, with eeveeee1999's icons for those 92. Still pictures only; the animations stay in Facets.

Only a set's own files can go in a pack. GBC-ISH, GB EMERALD and the Crystal parts are made from your own games while you play, so they stay Facets-only.

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

Everyone no Game Boy game has (14 in FR/LG, 69 in R/S/E: the Hoenn gym leaders, Elite Four, Frontier Brains, Aqua and Magma, Birch, Steven, Wally, tubers, triathletes and the rest) comes from Catwithnojob's Gen 2 Additional NPCs Pack, made in the Gen 2 style from TCG, Monster Race and Robopon characters. These are shipped as strips in `assets/npcs/gbc/strips/`, in the same layout as a Game Boy sprite and in their own colours; GBC 2X borrows them with the map. They're lookalikes, not the characters themselves, so swap any you'd pick differently. The seven Frontier Brains are the exception: they're **sirwhibbles**' own Gen 2-style overworld sprites of them (the same artist as their GBC-ISH battle pictures), included and used with credit.

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
- **GBC-ISH:** Gen 2 battle sprites, palettes and animations by Nintendo / Game Freak, read from your own imported Crystal, Gold or Silver; Hoenn made from your own imported Emerald's pictures; none of it is included. Party icons (included): Kanto and Johto from the Minidex 001-251, by Chamber, Soloo993, Blue Emerald, Lake, Neslug and Pikachu25; Hoenn by eeveeee1999.
- **GB EMERALD:** made from your own imported Emerald's pictures (Nintendo / Game Freak); none of it is included.
- **TRAINERS: DS (included):** trainer sprites by KyleDove (XY, ORAS, USUM, SWSH and Ga-Olé trainer classes), by Mr. Gela/theo#7722, and by KyleDove, Jext and figyberries (leaders, Elite Four, Aqua and Magma, the Frontier and more), used with credit.
- **TRAINERS: GBC-ISH and GAME BOY:** Gen 1/2 trainer pictures and Crystal's colours by Nintendo / Game Freak, read from your own imported games, and the game's own trainer pictures made Game Boy while you play; none of it is included.
- **WINDOWS: TITO (included):** text boxes by Tito Seich / Sage, used with credit.
- **BATTLE BG: SCENERY (included):** battle backgrounds by LibertyTwins, princess-phoenix, carchagui, aveontrainer, WesleyFG, kWharever, worldslayer608 and knizz (Battle Backgrounds Patch FR), used with credit.
- **BATTLE UI (included):** XY and B2W2 by Verloren 5; DP by Dinisk, Prof. Leon Dias, Neon Skylar and Verloren 5; PLATINUM by Omega Zero and Verloren 5; HGSS by YoY-X, Neon Skylar, Jaizu and Verloren 5; BW by Vytron and Verloren 5; B2W2 BLACK and WHITE by Verloren 5; GAIA by YoY-X and Spherical Ice; TEX BOX by Cesar Alarcon; PLAIN by Neon Skylar; the ZEKE recolours by Zeke; all used with credit.
- **WINDOWS and BATTLE UI: GBC:** Crystal's window frames, HP and EXP bars, HUD brackets and bar colours by Nintendo / Game Freak, read from your own imported Crystal, Gold or Silver; none of it is included.
- **GBC NPCs, Frontier Brains (included):** overworld sprites by sirwhibbles, used with credit.
- **TRAINERS: GBC-ISH (included):** Gen 2-style Hoenn gym leaders, Elite Four, Wallace and Steven by jphyper; Battle Frontier Brains by sirwhibbles; Archie, Maxie and the Aqua and Magma grunts by eli76; trainer classes by SkidMarc25; all used with credit.
- **GBC ANIM:** Gen 2 battle sprites and palettes by Nintendo / Game Freak, read from your own imported Crystal, Gold or Silver; none of it is included. Hoenn sprites and animations (included) by Nuuk (Crystal-style sprites), free to use with credit, not for profit; the rest from GBC-ISH.
- **SPRITE SWAPPER** is artyrambles' mod; Facets works alongside it and can make packs for it, but includes none of its code.
- **Sprite data:** which sprite each trainer class uses, and the HGSS overworld model names, come from pret's pokeemerald, pokefirered and pokeheartgold decompilations.
