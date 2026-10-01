# Pixel Pets: design spec

A Tamagotchi-style family of up to four pixel-art pets that live on the macOS desktop as a live wallpaper. Swift runs the pets. A single Metal fragment shader draws the whole scene.

Status: built. The original spec (approved 2026-09-30) is below, with the changes made while building it listed first.

## Changes from the original spec

### Added: genes, mutations and rarity

- Each pet carries a genome (`Genes`): body shape, colourway, pattern, accessory, eye style and the five trait pairs, plus generation, parent name and the list of mutations.
- Every gene variant has a rarity tier: Common, Uncommon, Rare, Epic, Legendary, weighted 100 / 35 / 12 / 4 / 1. A pet's rarity is its rarest feature.
  - Body shapes (20): blob, bird, cat, mouse, pig, duck (C); bunny, frog, bear, deer, hedgehog, penguin, turtle (U); ghost, fox, owl, raccoon, axolotl (R); dragon (E); unicorn (L).
  - Colourways (22): 12 common pairs from the original palette, plus coral, mint, peach (U); midnight, plum, sunset (R); obsidian, frost (E); gold, prism (L).
  - Patterns (12): plain, spots, stripes, patch (C); socks, tips, two-tone (U); checker, speckle (R); heart, stars (E); rainbow (L).
  - Accessories (15): none, leaf, bow (C); antenna, horns, crest, flower, sprout (U); top hat, cap, mushroom (R); unicorn horn, crown (E); halo, flame (L).
  - Eyes (9): dot, wide, sleepy (C); happy, sparkly, angry (U); cyclops (R); hearts (E); starry (L).
- Eggs from the first launch, from gravestones and from the "never empty" rule roll a random genome. Eggs laid by a pet inherit the parent's genome with mutations: shape 8%, new colourway 10% (otherwise a small hue drift), pattern 15%, accessory 15%, eyes 10%, each trait 20%. A mutation re-rolls by rarity weight.
- Sprites are no longer fixed per body shape. `PetComposer` builds every frame from the genes (base pose, then pattern, eyes, accessory; babies are the composed adult scaled to 12 x 12) and writes them into that pet's own region of the atlas. `PetSpriteRegions` assigns a region per living pet and re-uploads the atlas when one changes.

### Added: items, loot and daily chests

- **Weapons** (6), equipped one per pet: add attack (+1 to +6) and some hit 15% faster. Drawn in the pet's hand.
- **Relics** (8), equipped one per pet: walk faster, slower happiness or hunger decay, better sleep, 40% less monster damage, double healing, extra loot, or a one-time revive (Phoenix Feather).
- **Potions** (10), used up: hunger, health, happiness, energy, cure sickness, Strength and Courage buffs (10 min), full restore, and two egg potions: Hatch Elixir (hatch now) and Mutagen (a guaranteed rare-or-better mutation).
- **Loot bags:** every monster win drops a bag at the monster's spot. Slimes drop a potion (sometimes more), bats two items, and ogres three, including a rare-or-better weapon or relic. A Lucky Clover on any winner adds an uncommon-or-better roll. Bags are collected by clicking, from the menu, or automatically after 90 s.
- **Daily chest:** one per local calendar day the app runs, with three rolls, at least one uncommon or better. Opened by clicking it in play mode or from the menu.
- A dead pet's equipment returns to the bag. The bag, loot on the ground and the last chest day are saved.

### Art: procedural rigs at 64 x 64

- ASCII sprites were replaced by a small procedural renderer (`PixelRig.swift`). A sprite is a list of shaded parts (ellipses, tapered capsules, polygons, rings). Each pixel is lit from the top left and quantized into four tones per colour ramp (light, base, cool shade, dark tinted outline). Outlines go on the silhouette and wherever a front part overlaps a part behind it, and front parts cast a one-pixel shade onto parts behind them. Furry species get short stroke texture.
- The atlas stores (ramp, tone) per pixel; the shader turns it into colour, with the body and secondary ramps taken from each pet's genes.
- `Species.swift` has a side rig per species, a generic front and back rig driven by a per-species profile, accessories, and hi-res eyes and mouths. Face details are masked to the part under them, so in profile only the near eye shows and nothing pokes through ears or paws.
- Pets are designed on a 32-unit canvas and rendered at 2x into 64 x 64 frames. Per pet: side (idle 4, walk 8, sleep 4, eat 4, hop 6, sick 4, held 4, hurt 2, attack 6), front (idle, eat, hop, held, sick, sleep) and back (idle), each for adult and baby: 144 frames.
- Monsters (`Props.swift`) use the same renderer: slime 6 + 4 attack, bat 6 + 4, ogre 8 + 6 at 128 x 128. Eggs, the gravestone, food, chest, loot bag, weapons and smoke too.
- The screen grid is 960 wide (it was 320). The simulation still uses 320-wide units, and the scene scales them by 3. Bars and icons are drawn at 2x.
- **Facing:** pets only ever move along x. `Pet.facing` is side while walking, sleeping or fighting; front when held, eating, excited or hungry; otherwise front, back or side, rolled each time it picks a new spot.
- **Ground shadows** under pets, monsters, eggs and loot.
- **Landscape** restyled: three-tone cumulus clouds, dithered sky bands, a distant ridge with snow and diagonal light, a pine treeline, bushes, a big oak, and a meadow with horizontal grass strokes. About one night in three has an aurora.
- **Background images:** pictures in `~/Library/Application Support/PixelPets/Backgrounds/` can replace the drawn landscape (Background menu), cropped to fill and tinted for the time of day.

### Throwing and the family size

- Up to **10** pets and eggs (was 4). The scene limit is 32 items; the atlas holds 10 pet regions, and new pets' frames are composed on a background thread.
- **Throw physics:** a held pet springs toward the pointer; letting go keeps that velocity. Pets fly under gravity with light air drag, rebound off the screen edges, bounce on landing (with a squash frame), and settle. A pet thrown into a monster joins the fight with a double-damage first hit. Hard landings please Brave pets and upset Timid ones. The simulation ticks at 30 Hz so flight is smooth.

### Monsters and fights

- Seven monsters (weights out of 100): slime 30, shroomling 18, bat 18, wolf 14, wisp 10, ogre 6, golem 4. The bat and wisp fly. The ogre and golem are big (128 x 128 frames). All use the pet renderer: fur, cast shade, hi-res faces; each has a move cycle and an attack animation that plays right after it hits.
- Loot scales with the monster: golems guarantee an epic-or-better weapon or relic.
- **Hit feedback:** every blow is recorded (`World.hits`). The app shows an impact burst where it lands and, in play mode, a floating damage number. A monster's hit knocks the pet back into a hop (it then charges back in); pets' hits nudge the monster.
- The daily chest falls in from the sky with a bounce and sparkles, so it doesn't look like something a pet left behind. The loot sack shows gold coins.

### Landscape, second pass

Repainted after the reference backgrounds: hue-shifted ramps (cool shadows, warm lights), a nine-band sky with dithered seams, cumulus clouds lit as a mass with cool blue undersides, a distant range with planar faces, ragged snow and forested lower slopes, hazy teal far hills with a treetop fringe, tiered pines on the mid hills, an oak built from leaf clusters with dappled yellow-green highlights and a bark-textured trunk, and a meadow with jagged-edged light patches, darker strokes and sparse flowers. The landscape is sampled at the grid's full resolution so it matches the sprites' detail.

### Other changes

- **Scene item limit is 24, not 12**, to fit weapons, loot and the chest.
- **The drawable is the grid itself** (960 x height) and the layer scales it up with nearest-neighbour filtering.
- **Hatch time** is 20 min minus 1 min per pet hatched so far (floor 5), so the floor can be reached.
- **Picky pets** eat when hunger is 50 or less, and only fetch food within 120 px unless they are below 30.
- **Night sleep** lasts until 07:00. Full energy only ends naps.
- **Pick up versus rub:** wiggling over the pet with the button held is a rub. Dragging up more than 3 px, or out of the pet's box, picks it up.
- **Feeding:** ⌥-click works as well as F-click.
- **Dragging a pet out of a fight** marks it as retreated, so it does not run straight back in.
- **Full neglect** kills in 47 to 51 h depending on traits (Greedy + Cuddly is the fastest), which is a little under the spec's "2 to 3 days" at the extreme.
- **Repository layout:** the app lives at the repository root rather than in `pixel-pets/`.

---

## Original spec

### 1. Goals and constraints

- It is the desktop background: a borderless window at desktop level on every display, under the icons and all normal windows.
- Swift owns all state and logic. The Metal shader is only the renderer. A shader cannot keep state between frames, so nothing about a pet lives in the shader.
- Gentle pacing: a pet needs feeding a couple of times a day and dies after about 3 days of neglect. Time only passes while the app is running.
- No text is drawn on screen. Bars, feeling icons, and body language carry everything. Names and traits are shown in the menu bar menu.
- It is its own app, **Pixel Pets**, built from the same desktop window code as the existing Shader Wallpaper app. The Shader Wallpaper app is left untouched.
- macOS 13 or later. It builds with `swiftc` from the Xcode Command Line Tools, with no Xcode project.

Out of scope: other textures or image files (every sprite is ASCII art in Swift, and the landscape is procedural), sound, syncing between Macs, and interaction outside play mode apart from the menu bar.

### 2. Pets

#### 2.1 Life stages

| Stage | Duration (app running time) | Notes |
|---|---|---|
| Egg | 20 min, minus 1 min per pet (floor 5 min) | Wobbles more as it nears hatching. Petting it counts. |
| Baby | first 24 h after hatching | Smaller sprite, attack halved, cannot lay eggs. |
| Adult | 24 h to 14 days | Full stats. Can lay eggs. |
| Elder | from 14 days | Moves slower. Each hour, 2% chance of dying peacefully of old age. |

#### 2.2 Needs

| Need | Decay | Raised by | Notes |
|---|---|---|---|
| Hunger (100 = full) | 8.5 per hour | Eating a pellet: +30 | 3 overfeeds (eating above 90) within 2 h make the pet sick for 1 h (health -10). |
| Happiness | 4 per hour; 8 per hour if not petted for 6 h | Petting: +6 per click, up to +20 per minute. Winning a fight: +25. | Being held changes it by trait. |
| Energy | 6 per hour awake; +20 per hour asleep | Sleep | Naps below 25. Sleeps at night (23:00 to 07:00). |

#### 2.3 Health and death

- Health drains by 1.4 per hour for each of: hunger is 0; happiness is below 10; the pet is sick. If none are true and hunger and happiness are both above 40, health heals by 3 per hour.
- Monster hits reduce health directly.
- At 0 health the pet dies, becomes a gravestone for 60 s, then an egg. The death goes into the graveyard.
- Causes: starvation, heartbreak, sickness, a monster, old age.

#### 2.4 Feelings (first match wins)

1. Scared: held while Timid, or fleeing a monster. Exclamation icon, shaking.
2. Sick: sick, or health below 30. Green face icon, wobble walk.
3. Sleepy: asleep, or energy below 25. Zz icon, sleep sprite.
4. Hungry: hunger below 30. Drumstick icon.
5. Sad: happiness below 30. Rain cloud icon, slow walk.
6. Excited: petted, fed, or won a fight in the last 20 s. Sparkle icon, hops.
7. Content: anything else. Small heart for 2 s every 30 s.

#### 2.5 Traits

| Pair | Effect |
|---|---|
| Greedy / Picky | Greedy: hunger decays 1.3x faster, walks to food from anywhere. Picky: ignores food while hunger is above 50; pellets give +40. |
| Cuddly / Aloof | Cuddly: petting 1.5x, happiness decays 1.2x faster. Aloof: petting 0.5x, happiness decays 0.7x as fast. |
| Energetic / Lazy | Energetic: walks 1.5x faster, energy decays 1.4x faster, hits every 1.15 s. Lazy: walks 0.6x, energy decays 0.7x, naps below 50 when calm. |
| Brave / Timid | Brave: +2 happiness per 10 s held, charges monsters. Timid: -3 per 10 s held and Scared, flees monsters unless cornered. |
| Social / Loner | Social: +1 happiness per hour per pet within 60 px, attack 1.2x with an ally. Loner: -1 per hour per pet within 30 px, walks away from groups. |

#### 2.6 Eggs and population

- At most 4 slots, each a pet, an egg or a gravestone.
- An adult or elder with hunger, happiness and energy all above 70 builds content time; at 6 h it lays an egg if a slot is free (the counter caps at 6 h while waiting).
- A gravestone becomes an egg. If there are ever no pets, eggs or gravestones, an egg appears. First launch starts with one egg.

### 3. Monsters

| Kind | Health | Damage | Hit interval | Speed | Weight |
|---|---|---|---|---|---|
| Slime | 30 | 4 | 2.0 s | slow | 60% |
| Bat | 25 | 6 | 1.5 s | fast, swoops | 30% |
| Ogre | 120 | 12 | 2.5 s | slow | 10% |

- Each hour, a 12% spawn chance, never at night, with a monster present, or with no hatched pets.
- Pet attack: `4 + 4 * hunger/100 + min(wins * 0.5, 6)`, halved for babies, times trait bonuses. A pet in a fight hits every 1.5 s (1.15 s Energetic).
- Brave pets charge. Timid pets flee to the far edge unless cornered. A pet below 25 health retreats and won't rejoin; one already below 25 never joins but can still be hit.
- Player: click the monster for 5 damage (0.4 s cooldown); drop a pet on it to throw it in (first hit double); drag a pet out.
- Win: monster health reaches 0. Winners get +25 happiness, Excited and +1 win.
- Loss: 90 s without anyone hitting the monster. Every pet loses 25 hunger and the monster leaves.
- Timeout: after 5 min it leaves regardless.

### 4. Rendering

- A virtual grid 320 wide, height from the screen's shape. Origin bottom left.
- Landscape in the shader: a stepped sky gradient from four time-of-day keyframes, stars and a moon at night, two layers of hills, drifting clouds, a grass line with tufts and swaying flowers, occasional rain, and a 15% dim in play mode.
- Sprites are ASCII art parsed into an `r8Uint` palette-index atlas; `b` and `s` are recoloured per item.
- Three bars above a pet (health red, hunger orange, happiness pink), shown in play mode or when one is below 30; health blinks below 25. Eggs show a hatch bar, monsters a health bar.
- Frame data: `SceneUniforms` (buffer 0) and an array of `SceneItem` (buffer 1), sorted back to front by y. Layouts must match the Metal structs; a unit test checks the strides.

### 5. Window, input and play mode

- One window per display, reused across screen changes. Desktop window level, all spaces, stationary, ignores mouse outside play mode. The main display holds the pets; others show the landscape.
- Never pauses when covered; pauses only for screen sleep, an inactive session, or the user.
- Play mode (⌥⌘P via `RegisterEventHotKey`, or the menu): the window rises to desktop-icon level + 1 and takes the mouse, the landscape dims and bars show. Auto-off after 2 minutes without mouse input.
- Gestures: click to pet, rub, click an egg, hold F and click to feed, drag to pick up, drop (onto a monster to throw in), click the monster.

### 6. Simulation

- `PetsCore` has no AppKit or Metal and is unit tested.
- `World.tick(dt:)` runs 10 times a second with `dt` capped at 1 s; nothing ticks while paused or asleep.
- All randomness goes through a seedable `RandomSource`.
- Pets walk along the ground, pick a new spot every 5 to 20 s by trait, and keep 6 px apart unless fighting.
- AI order: held, dead, fighting or fleeing, food, sleeping, wandering.

### 7. Saving

`~/Library/Application Support/PixelPets/world.json` (Codable): format version, pets, eggs, graveyard, random state. Saved every 30 s, on quit and on screen sleep, via a temp file and rename. Time spent closed does not pass. Monsters are not saved. A corrupt file is renamed to `world.corrupt-<date>.json` and a new world starts with one egg.

### 8. Menu bar

Play Mode, Pets (name, age, feeling; submenu with traits and needs; eggs with time to hatch), Graveyard, Pause/Resume, Frame Rate, Notifications, Launch at Login, Quit. A pixel paw icon with a red dot while a pet is starving, sick or in a fight.

### 9. Notifications

Starving or sick (at most once per pet every 2 h), a monster arrives, an egg hatches or is laid, a pet dies.

### 10. Testing

Unit tests cover needs and traits, health and death (including full neglect and every cause), feelings, population, fights, saving and struct layout. Manual checks on a Mac cover window levels, displays, Mission Control, play mode, gestures, day and night, sleep, relaunch, and a full life cycle with `PIXELPETS_SPEED=600`.
