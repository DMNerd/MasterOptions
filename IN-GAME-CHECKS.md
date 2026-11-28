# In-game checks

What the sandbox tests can't confirm: how it looks, and how it behaves with the real addons and the real server.
Go through **Waiting** before a release (deploy with `pwsh scripts/deploy.ps1`, then `/reload`), tick what works,
and move it to **Confirmed** with the version. Something that doesn't work goes back to the code, not into a release.

The standing checks after any update are in [UPDATING.md](UPDATING.md), step 4.

## Waiting

Unreleased (after 2.20.0):

- [ ] **Cheap Disenchants, Quick scan** (with Auctionator): press Quick scan. Auctionator says it's starting its scan;
      the status goes through steps 1/4 to 4/4 with the thin bar filling for each; the list fills; the footer says
      "Auctionator's quick scan, just now". The game doesn't lag while it runs.
- [ ] **Cheap Disenchants, Full scan** (with Auctionator): press Full scan. Auctionator's full scan runs (it takes a
      while: it loads every item); the list fills when Auctionator says it's finished. The button counts down 15:00
      after it. Pressed again within the 15 minutes: "a full scan can run again in N min".
- [ ] **Cheap Disenchants, the auction house's own opening scan**: close and reopen the auction house, wait for
      Auctionator's scan to finish, then open the tab: the list is there without pressing anything.
- [ ] **Cheap Disenchants, the tab's top**: two rows, nothing overlapping and clear of the portrait - Quick scan,
      Full scan, List: Profitable / Cheapest and the status on the first; Blues too, Hide "needs an enchanter" on the
      left of the second, Max price and its gold / silver / copper field on its right.
- [ ] **Cheap Disenchants, Cheapest**: press Cheapest - its button lit, the list is every disenchantable item, the
      cheapest first, a loss in red; Profitable brings the finds back. Both without a new scan.
- [ ] **Cheap Disenchants, the list**: every other row a shade lighter; the profit with its share of the price
      ("+1g 20s 150%"); an item with one of your auctions among it says "you have one listed"; the empty list says
      what to do before the first scan, and that nothing was found when nothing was.
- [ ] **Cheap Disenchants, Max price**: type 50s - the list shrinks a moment later, no new scan. 0 - everything back.
- [ ] **Cheap Disenchants, Hide "needs an enchanter"**: ticking it takes those rows out at once; unticking brings
      them back.
- [ ] **Auction house tabs, More**: open the auction house - the tab row ends at the window's right edge with a
      "More »" tab; its click lists the rest (Selling, Cancelling, Auctionator ...). Pick one: its page opens, the
      More tab shows chosen with its name. Buy (or any tab in the row): More back to "More »", not chosen.
- [ ] **OpenMap's Pins list window** (the list of your map pins): Shift-click on a row starts a Shortest Path journey
      there; with a chat box open it still puts the pin in chat; a plain click still goes there; the row's tooltip
      says "Shift-click: journey there (Shortest Path)".

Released, not confirmed yet:

- [ ] **2.20.0 - Navigation arrow "Destination pin only"**: on a journey, Shortest Path's arrow is gone and its pin
      over the destination shows. Back on "Shortest Path's arrow": the arrow again, the pin gone (unless you had it on).
- [ ] **2.19.0 - One townsfolk menu**: OpenMap's Townsfolk menu lists vendors and profession trainers, not repair,
      innkeepers, bankers and the rest; those are ticked in Questie's menu and show once on the world map.
- [ ] **2.18.0 - Shift-click on an OpenMap pin** on the map (Dungeon Journal's too) starts a journey; with a chat box
      open it shares the pin; the tooltip's Shift-click line says so.

## Confirmed

- 2.18.0 - Edge snap: the minimap sits in from the screen's edge, its whole border showing.
- 2.17.0 - Minimap coordinates inside the map, top right.
