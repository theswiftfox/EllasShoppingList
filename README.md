# EllasShoppingList

Small World of Warcraft addon that acts as a shopping list.

Installation
1. Put the `EllasShoppingList` folder into your World of Warcraft `_retail_/Interface/AddOns/` directory.
2. Download [libDBIcon-1.0](https://www.wowace.com/projects/libdbicon-1-0) and put them in `_retail_/Interface/AddOns/EllasShoppingList/libs` (They cannot be included directly due to license.)
3. /reload after adding the folder.
4. Open the AddOns Key Bindings menu (Esc -> Key Bindings) and assign a key to "EllasShoppingList -> Add hovered item to shopping list".
5. Use the minimap button to open the main UI or type `/ells`.

Notes & Usage
- The "Add hovered item" hotkey uses the GameTooltip. Hover a vendor item icon (or any item tooltip) and press your hotkey to add it to the active list.
- The Search window will look through an internal cache that is populated automatically from vendor items when a merchant window opens and from your bags and equipment. If an item isn't in the cache yet, open a vendor or make sure you have encountered it so the addon can cache it. // todo: use an item db for this

Limitations
- The search uses a local cache (bags, equipment, vendors). It does not query Blizzard's entire item DB.
- GetItemInfo may sometimes delay resolving some item details; the addon stores raw links and uses whatever info is available.