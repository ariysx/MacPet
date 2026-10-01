# Pixel Pets

A Tamagotchi-style family of up to ten pixel-art pets that live on your macOS desktop as a live wallpaper. Swift runs the pets; one Metal fragment shader draws the whole scene. It is a menu-bar-only app for macOS 13 and later.

## Build

1. If you don't have Xcode, install the Command Line Tools: `xcode-select --install`
2. In this folder, run: `chmod +x build.sh && ./build.sh`
3. Move `build/PixelPets.app` to `/Applications` and open it.
4. A paw appears in the menu bar. Turn on **Launch at Login** there.

Your first egg is in the middle of the ground. It hatches in about 20 minutes.

## Playing

The pets live under your desktop icons. To interact with them, press **⌥⌘P** to turn on play mode (or choose **Play Mode** in the menu). The landscape dims and every pet's bars show. Other apps' windows and the Dock hide while you play, and come back exactly as they were when you leave (turn this off with **Hide Other Apps in Play Mode**). Play mode turns itself off after 2 minutes without mouse input, or when you press Esc.

| Action | How |
|---|---|
| Pet | Click a pet. Hearts pop out. |
| Rub | Hold the button and wiggle side to side over a pet. Counts as three pets. |
| Pet an egg | Click it. Takes a minute off the hatch time, up to five. |
| Feed | Hold **F** and click the ground. A hungry pet walks over. |
| Pick up | Press on a pet and drag up or away. Brave pets like it; Timid ones don't. |
| Throw into a fight | Drop a pet onto a monster. Its first hit does double damage. |
| Hit a monster | Click it. |
| Loot | Click a loot bag, the daily chest or a Petdex chest. |
| Place an egg / blow the War Horn | Drag it from the bag onto the ground. |

In play mode the screen shows the game's interface:

- **Bag bar** at the bottom: every item with its rarity frame and count. Hover an item to see what it does. **Drag it onto a pet** to equip a weapon or relic, or to drink a potion; drag Hatch Elixir or Mutagen onto an egg.
- **Chests and loot bags** pop open with a reveal of each item and its rarity, then go into the bag.
- **Right-click a pet** (or Control-click) for its card: portrait, rarity, generation, traits, health, food, joy and energy, and its weapon and relic slots. Click a slot to put the item back in the bag.
- **Pictogram hints** along the top (mouse buttons, a hand for dragging, the F and Esc keys), and a **badge by the pointer** that shows what a click or drag does there: an open hand over a pet, a fist while holding one, a sword over a monster, a pointing hand over loot, an hourglass and minutes left over an egg, an apple while F is held.
- **Petdex** button next to the bag, with the streak counter on the other side.
- Name tags with the pet's level when you hover a pet, and floating text for hatches, fights, loot and equipment.

Bars above each pet: red is health, orange is hunger, pink is happiness. Outside play mode they only show when something is low.

Time only passes while the app is running and the screen is awake. A pet needs feeding a couple of times a day and dies after about two to three days of total neglect.

## Pets and genes

Pets are drawn procedurally at 64 x 64, with animated status icons (a beating heart, rising Zs, falling rain): each species is a rig of shaded parts (body, head, legs, ears, tail, wings) lit from the top left in four tones with coloured outlines, posed frame by frame (idle 4, walk 8, hop 6, attack 6, eat 4, sleep 4, sick 4, held 4, hurt 2). Pets live on one line: they walk left and right, and when they stop they may turn to face you or look away into the landscape. Each pet has side, front and back views.

Every pet hatches with a genome:

- **Body (50):** the rarer, the more mythical.
  - Common: blob, bird, cat, mouse, pig, duck, hamster, puppy, chick, sheep, snail
  - Uncommon: bunny, frog, bear, deer, hedgehog, penguin, turtle, koala, panda, squirrel, otter, goat
  - Rare: ghost, fox, owl, raccoon, axolotl, seal, red panda, lion, chameleon, pangolin, fruit bat, peacock
  - Epic: dragon, kitsune, griffin, pegasus, jackalope, qilin, mothkin, wyvern
  - Legendary: unicorn, phoenix, spirit stag, sky whale, thunderbird, sphinx, cerberus
- **Colours:** 22 colourways, from common oranges and blues to gold and prism
- **Pattern:** plain, spots, stripes, patch, socks, tips, two-tone, checker, speckle, heart, stars, rainbow
- **Accessory:** none, leaf, bow, antenna, horns, crest, flower, sprout, top hat, cap, mushroom, unicorn horn, crown, halo, flame
- **Eyes:** dot, wide, sleepy, happy, sparkly, angry, cyclops, hearts, starry
- **Traits:** one of each pair: Greedy/Picky, Cuddly/Aloof, Energetic/Lazy, Brave/Timid, Social/Loner

Each variant has a rarity: ★ Common, ★★ Uncommon, ★★★ Rare, ★★★★ Epic, ★★★★★ Legendary. A pet's rarity is its rarest feature. Sprites are composed from the genes when the pet hatches, so every combination looks different.

## Getting more eggs

- A happy adult lays an egg every 3 hours it stays content (hunger, happiness and energy above 70).
- **Mystery Eggs** drop from monsters (bigger monsters drop them more often: ogres 40%, golems 50%) and from about a third of daily chests. **Shiny Eggs** hatch with a rare mutation: golems and ogres sometimes drop them, and every 7th day of a daily streak guarantees one. Eggs wait in the bag until you place them, so a full family never loses one.
- Every 8 new **Petdex** entries drops a Petdex chest with a Mystery Egg inside.
- A grave turns into a new egg after a minute, and an empty world always gets one.

## Progress

- **Levels:** pets that land a hit in a won fight gain experience (bigger monsters give more). Each level adds attack, and a level-up heals a little. Levels go to 20.
- **Petdex:** every animal, colour, pattern, hat and eye style you hatch is recorded. Open it from the **DEX** button next to the bag.
- **Daily streak:** a daily chest on consecutive days grows: more items from day 2, a guaranteed rare from day 3, and a Shiny Egg every 7th day.
- **Crits:** a pet's blow sometimes lands critical for 1.8x damage (more often with a Lucky Clover). Crits, heavy blows and the finishing blow freeze time for an instant, flash the target white and shake the screen.

A happy adult lays an egg. The chick inherits its parent's genes with a few mutations: colours drift a little every generation, and now and then the body, pattern, accessory, eyes or a trait changes. The menu shows each pet's generation, parent and mutations.

## Backgrounds

The landscape is drawn by the shader: clouds, distant mountains, pine-covered hills, a big oak and a meadow, lit for the time of day. Wind gusts roll through the grass and flowers, leaves fall from the oak, cloud shadows drift past, birds cross by day, and fireflies, stars, a moon and sometimes an aurora come out at night. A couple of times a day it rains: a light drizzle, steady rain, or a thunderstorm with a grey sky and lightning. Drops splash on the meadow.

To use your own picture instead, choose **Background → Open Backgrounds Folder…**, drop PNG or JPG images into `~/Library/Application Support/PixelPets/Backgrounds/`, then pick one from the **Background** menu. It is cropped to fill the screen and tinted for dawn, dusk and night. Pets walk on a line a quarter of the way up the screen.

## Items

Win fights and open the daily chest to fill your **Bag** (in the menu).

- **Weapons** (equip on a pet): Stick, Wooden Sword, Slingshot, Iron Sword, Magic Wand, Dragon Fang. They add attack, and some hit faster. Weapons wear out: each hit uses one point of durability (a Stick lasts 40 hits, a Dragon Fang 400) and a weapon at zero breaks. A half-used weapon put back in the bag keeps its wear.
- **Relics** (equip on a pet): Feather Charm, Cozy Scarf, Snack Pouch, Moon Pillow, Guardian Shell, Heart Locket, Lucky Clover, Phoenix Feather. Each gives a passive perk and never wears out; the Phoenix Feather brings a pet back from death once. The very rare **Timeless Amber** freezes a pet's age, so it never grows old or dies of old age.
- **Potions** (used up): Snack, Tonic, Joy Juice, Espresso, Antidote, Strength Potion, Courage Potion, Elixir, plus Hatch Elixir and Mutagen for eggs.
- **Specials** (drop on the ground): Mystery Egg, Shiny Egg, and the **War Horn**, which calls a monster to fight right now.

A **daily chest** appears on the ground once per calendar day the app runs. Beaten monsters drop a **loot bag**: slimes mostly drop potions, bats drop a bit of everything, and ogres always drop a rare weapon or relic. Loot bags collect themselves after 90 seconds. When a pet dies, its equipment goes back in the bag.

## Monsters

Every ten minutes of daytime there is a one-in-five chance a monster wanders in (or blow a War Horn): slimes, shroomlings, bats, wolves, wisps, ogres and golems. Brave pets charge, Timid pets flee unless cornered, and a pet below 25 health retreats. You can click the monster to help, or throw pets in. If nobody hits it for 90 seconds it eats some of everyone's food and leaves.

## Menu

Play Mode, chests and loot, each pet (looks, rarity, lineage, traits, needs, equipment, and **Give from Bag**), eggs (and egg potions), the Bag, the Graveyard, Time of Day, Weather (Live, Clear, Light Rain, Rain, Thunderstorm), Background, Pause, Frame Rate, Notifications, Hide Other Apps in Play Mode, Launch at Login, Quit.

## Files

The world is saved to `~/Library/Application Support/PixelPets/world.json` every 30 seconds, on quit and when the screen sleeps. If the file is unreadable, it is renamed to `world.corrupt-<date>.json` and a new egg appears.

## Development

```
Sources/PetsCore/    simulation: world, pets, genes, items, monsters, saving (no AppKit or Metal)
Sources/PixelPets/   app: menu, windows, Metal view, input, sprites, scene, Shaders.metal
Tests/PetsCoreTests/ unit tests for PetsCore
```

Run the simulation tests with `swift test`. They also run on Linux, for example in the `swift:6.0` Docker image.

To watch a whole life cycle quickly, run the app from Terminal with a speed-up:

```
PIXELPETS_SPEED=600 build/PixelPets.app/Contents/MacOS/PixelPets
```

The design spec is in [`docs/design.md`](docs/design.md).
