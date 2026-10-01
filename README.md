# Pixel Pets

A Tamagotchi-style family of up to four pixel-art pets that live on your macOS desktop as a live wallpaper. Swift runs the pets; one Metal fragment shader draws the whole scene. It is a menu-bar-only app for macOS 13 and later.

## Build

1. If you don't have Xcode, install the Command Line Tools: `xcode-select --install`
2. In this folder, run: `chmod +x build.sh && ./build.sh`
3. Move `build/PixelPets.app` to `/Applications` and open it.
4. A paw appears in the menu bar. Turn on **Launch at Login** there.

Your first egg is in the middle of the ground. It hatches in about 20 minutes.

## Playing

The pets live under your desktop icons. To interact with them, press **⌥⌘P** to turn on play mode (or choose **Play Mode** in the menu). The landscape dims and every pet's bars show. Play mode turns itself off after 2 minutes without mouse input, or when you press Esc.

| Action | How |
|---|---|
| Pet | Click a pet. Hearts pop out. |
| Rub | Hold the button and wiggle side to side over a pet. Counts as three pets. |
| Pet an egg | Click it. Takes a minute off the hatch time, up to five. |
| Feed | Hold **F** (or ⌥) and click the ground. A hungry pet walks over. |
| Pick up | Press on a pet and drag up or away. Brave pets like it; Timid ones don't. |
| Throw into a fight | Drop a pet onto a monster. Its first hit does double damage. |
| Hit a monster | Click it. |
| Loot | Click a loot bag or the daily chest. |

Bars above each pet: red is health, orange is hunger, pink is happiness. Outside play mode they only show when something is low.

Time only passes while the app is running and the screen is awake. A pet needs feeding a couple of times a day and dies after about two to three days of total neglect.

## Pets and genes

Every pet hatches with a genome:

- **Body:** blob, bird, cat, bunny, frog, bear, ghost, fox, dragon
- **Colours:** 22 colourways, from common oranges and blues to gold and prism
- **Pattern:** plain, spots, stripes, patch, socks, tips, two-tone, checker, speckle, heart, stars, rainbow
- **Accessory:** none, leaf, bow, antenna, horns, crest, flower, sprout, top hat, cap, mushroom, unicorn horn, crown, halo, flame
- **Eyes:** dot, wide, sleepy, happy, sparkly, angry, cyclops, hearts, starry
- **Traits:** one of each pair: Greedy/Picky, Cuddly/Aloof, Energetic/Lazy, Brave/Timid, Social/Loner

Each variant has a rarity: ★ Common, ★★ Uncommon, ★★★ Rare, ★★★★ Epic, ★★★★★ Legendary. A pet's rarity is its rarest feature. Sprites are composed from the genes when the pet hatches, so every combination looks different.

A happy adult lays an egg. The chick inherits its parent's genes with a few mutations: colours drift a little every generation, and now and then the body, pattern, accessory, eyes or a trait changes. The menu shows each pet's generation, parent and mutations.

## Items

Win fights and open the daily chest to fill your **Bag** (in the menu).

- **Weapons** (equip on a pet): Stick, Wooden Sword, Slingshot, Iron Sword, Magic Wand, Dragon Fang. They add attack, and some hit faster.
- **Relics** (equip on a pet): Feather Charm, Cozy Scarf, Snack Pouch, Moon Pillow, Guardian Shell, Heart Locket, Lucky Clover, Phoenix Feather. Each gives a passive perk; the Phoenix Feather brings a pet back from death once.
- **Potions** (used up): Snack, Tonic, Joy Juice, Espresso, Antidote, Strength Potion, Courage Potion, Elixir, plus Hatch Elixir and Mutagen for eggs.

A **daily chest** appears on the ground once per calendar day the app runs. Beaten monsters drop a **loot bag**: slimes mostly drop potions, bats drop a bit of everything, and ogres always drop a rare weapon or relic. Loot bags collect themselves after 90 seconds. When a pet dies, its equipment goes back in the bag.

## Monsters

About two to four times a day (never at night), a slime, bat or ogre wanders in. Brave pets charge, Timid pets flee unless cornered, and a pet below 25 health retreats. You can click the monster to help, or throw pets in. If nobody hits it for 90 seconds it eats some of everyone's food and leaves.

## Menu

Play Mode, the daily chest and loot, each pet (looks, rarity, lineage, traits, needs, equipment, and **Give from Bag**), eggs (and egg potions), the Bag, the Graveyard, Pause, Frame Rate, Notifications, Launch at Login, Quit.

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
