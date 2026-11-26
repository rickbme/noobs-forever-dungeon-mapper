# In-game checklist

A step-by-step pass for the person testing the addon in the game (you don't need to know any code).
Tick things off as you go. Anything that looks wrong: take a screenshot, note what you did just before,
and copy any red error text. That's all we need.

## 0. Get it ready

- [ ] Delete any older `NoobsForeverDungeonMapper` or `ForeverDungeons` folder from
      `World of Warcraft\_forever_\Interface\AddOns\`.
- [ ] Copy the new `NoobsForeverDungeonMapper` folder in (from the addon zip, see the README).
- [ ] **Fully restart the game** (not just `/reload`): the map pictures are new files.
- [ ] Type `/console scriptErrors 1` so any error shows on screen.
- [ ] On the character select screen, click *AddOns* and make sure *Noobs Forever Dungeon Mapper* is ticked.

## 1. Anywhere in the world

- [ ] A welcome window appears the first time. Its buttons work (*Pick a dungeon*, *Options*, *Got it*).
- [ ] A map icon sits on the edge of your minimap. Left-click shows or hides the dungeon map window;
      right-click shows a menu with the dungeon list, *World map*, *Options* and *Welcome tips*.
- [ ] Drag the minimap icon around the minimap. It follows and stays where you drop it.
- [ ] **Options** (from the window's *Options* button): clicking each box turns it on and off, the *-* and *+*
      buttons change the window size, and Escape closes it.
- [ ] *Esc > Options > AddOns* has a *Noobs Forever Dungeon Mapper* page with all our options in two columns
      (the same as the window from the map's *Options* button). Everything fits on the page, and clicking
      a box there changes it right away.
- [ ] **Map opacity**: lowering it (the *-* button) makes both the dungeon map window and the world map
      window see-through, so you can see the game behind them. It stops at 30%.
- [ ] The world map no longer highlights the dungeon you last clicked.
- [ ] **Fade while moving** (on by default): with a map open, walk. The map fades to see-through within about
      a quarter of a second so you can see where you are going, and returns when you stop. Point the mouse at
      the map while walking: it stays solid. Does the 35% level feel right? (*Opacity while I move* changes it.)
      Check that it also fades when you ride a mount or a flight path, and does *not* fade when you stand still.
- [ ] *Esc > Options > Keybindings > AddOns* lists the show/hide map, world map and options bindings.

## 2. The world map

- [ ] Stand outside, anywhere in the open world, and click the minimap button. The world map opens on the
      continent you are on, with a **green marker** where you stand. Does the marker match your real spot?
      (If it opens on the wrong continent or there is no marker, tell us your zone.)
- [ ] Click the minimap button again: it hides. In *Options*, "Outside dungeons, open the world map where I
      am" turns this off (the button then opens the last dungeon's map instead).
- [ ] Open it from a dungeon (*World map* button, the minimap right-click menu, or its key). Azeroth shows with red dots.
- [ ] On the Azeroth map, scroll the mouse wheel **up** over a continent: it zooms in on that continent.
      Scroll **down** to zoom back out. Clicking a continent also zooms in, and the *Zoom out* button (bottom left)
      zooms out. Does the wheel feel natural? Does it pick the continent you pointed at?
- [ ] Dungeon entrances are small blue swirl icons (the game's own dungeon icon if it has one, otherwise our
      swirl); raids are purple. Tell us which style you see.
- [ ] The icons sit on the right places: for example Deadmines in Westfall, Stockade in Stormwind,
      Ragefire Chasm by Orgrimmar, Wailing Caverns in the Barrens. **Note any dot that is clearly wrong.**
- [ ] Hovering a dot shows the dungeon's name and levels. Clicking it opens that dungeon's map.

## 3. Inside a dungeon

Go into any dungeon (The Hall of Thanes is best, then Ragefire Chasm or Deadmines).

- [ ] The map opens by itself on a sensible floor. It closes when you leave.
- [ ] Boss pins are **skull icons** (like the skulls on the game's own dungeon maps) with a small number in the
      corner. The next boss's skull is gold and pulses, a defeated boss's skull is grey with a tick. Is the skull
      easy to see on the parchment, and the number easy to read?
- [ ] Boss numbers on the map match the list. Clicking a boss in the list pulses its pin.
- [ ] After you kill a boss, it goes grey with a tick and the next boss pulses gold.
- [ ] If the dungeon has more than one floor, the < and > buttons change floor.
      Only the bosses of the floor you are looking at have red markers; the old floor's markers disappear.
- [ ] The whole map picture looks even. **If some square blocks of the map are bright and others dark, or odd
      colours:** open that map and type `/fd probe`. It prints your game language and build and says whether
      all the map tiles were found. Screenshot the chat lines, plus the map itself, and tell us which dungeon and
      floor, and whether you use other map or UI addons.
- [ ] **Even picture:** open several dungeons (Gnomeregan, Deadmines, Scarlet Monastery...), several times each, and
      on every floor. The whole map picture should look the same brightness: no square block darker than the rest.
      If one still shows, screenshot it and tell us the dungeon and floor.
- [ ] For a new dungeon: the map is Santiago Reyes' drawing, with **"Map by Santiago Reyes"** at the bottom
      right and his watermark still visible.
- [ ] In **The Hall of Thanes**: walking into a new area moves a blue ring on the map ("you are here").
      Does the ring match where you really are? Note the area names shown under the map.
- [ ] Turn on *Live view* in Options: the minimap gets bigger inside a dungeon and goes back to normal outside.

- [ ] Dungeon levels in the *Dungeons* menu and the window's title line are coloured for your level
      (red too hard, yellow about right, grey trivial). Do the colours look right to you?
- [ ] Gold lines join the bosses in order on each floor, and turn grey once you pass a boss.
- [ ] **Boss kills during a run:** kill a boss, then open the map. It should show as defeated (grey with a
      tick). Leave and come back in: it should still be. After a dungeon reset it should start fresh.
      If a kill doesn't show, note which boss, and send the saved-variables file (see section 4): it
      keeps a log of the boss fights as the game reported them.

- [ ] **Quests:** with a dungeon quest in your log (for example one that says to kill a boss there), open that
      dungeon's map and press **Quests**. The quest should be listed with its goals, and the boss it names should
      have a gold **!** on its pin and in the boss list. If a quest you have is missing (or one that doesn't
      belong is shown), note its exact title and what the quest log files it under. Turn on `/fd probe log`
      first: the saved-variables file then keeps what your quest log looked like (`questScan`).

## 4. The position check (very useful, 2 minutes)

Stand inside a dungeon, then type:

```
/fd probe
```

- [ ] Take a screenshot of the chat lines it prints (it lists what the game does and doesn't tell addons,
      including "Boss progress from the game" for the dungeon you are in).

Then turn on recording, walk through as much of the dungeon as you can, and log out from the character
select screen (this saves the file):

```
/fd probe log
```

- [ ] Send the file `World of Warcraft\_forever_\WTF\Account\<your account>\SavedVariables\NoobsForeverDungeonMapper.lua`.
      It holds the area names you walked through, so we can fill in more "you are here" areas.

## 5. Placing boss pins (helps everyone)

- [ ] **The ask cards:** entering a dungeon where some bosses have no pin (for example the Stockade) shows a small card at the
      top of the screen, "Help map the bosses?", with *Yes, I'll help*, *Not now* and a *Don't ask me again* box. It
      appears a few seconds after you arrive, not during combat, and only once per dungeon until you restart the game.
      Does it ever get in the way? Does *Don't ask me again* stop it (and does the Options switch bring it back)?
- [ ] **After a kill:** defeat a boss that has no pin. When the fight is over, a card says "You defeated X, and it has no
      pin on the map yet" and *Yes* goes straight to "click the map where you fought it".

Many bosses have no pin yet. In Options, tick *Help map the bosses*. A dark bar appears across the top of the
map with **Undo**, **Remove pin** and **Done** buttons.

- [ ] Open a dungeon's map. Bosses without a pin say "(no pin yet)" in the list.
- [ ] Click a boss in the list (or click one of your pins), then click the spot on the map where it is. A pin
      appears at the spot you clicked (**check it really is where you clicked**). Your own pins have a blue ring.
- [ ] **Move a pin:** drag it to a new spot, or pick the boss again and click the map.
- [ ] **Made a mistake?** *Undo* takes back the last change (place, move or remove) and can be pressed several times.
      *Remove pin* (with the boss picked) or a **right-click on your own pin** removes it. Right-click the map
      cancels picking a boss. While placing pins, clicking never marks a boss as killed.
- [ ] *Done* ends mapmaker mode (so right-click marks kills again).
- [ ] In Options, *Import guild pins* opens a box: paste the guild's block of `NFDM|...` lines, press *Import*, and the
      bosses it covers get pins (purple ring, "From the guild's shared pins" in the tooltip). Your own pins always win.
- [ ] In Options, *Share my boss pins* shows your pins as text. Click inside it, press Ctrl+A, then Ctrl+C,
      and paste it to us (for example in the Noobs Forever Discord).

## 6. If something goes wrong

- A red error box: screenshot it, or copy the text. Tell us what you clicked just before.
- A map picture that is a solid green square, or missing: tell us the dungeon, and your game language.
- Anything that looks too big, too small or overlapping: a screenshot and your UI scale setting.

Thank you for testing!
