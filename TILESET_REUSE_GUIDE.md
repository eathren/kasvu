# Creating a Reusable TileSet in Godot 4

## Step 1: Create Your TileSet

1. Create a new TileMapLayer node in any scene
2. In the Inspector, click on the **TileSet** dropdown (where it says "Empty")
3. Select **"New TileSet"**
4. Click on the TileSet again to open the TileSet editor at the bottom
5. Add your tileset image/atlas and configure:
   - Physics layers (collision shapes)
   - Terrain sets
   - Navigation
   - Custom data layers
   - Animations
   - Any other properties you need

## Step 2: Save the TileSet as a Resource

1. In the Inspector, click on the **TileSet** dropdown again
2. Click the **📋 menu icon** (three dots) next to the TileSet
3. Select **"Save"** (or press Ctrl+S in the TileSet editor)
4. Choose a location and name (e.g., `res://assets/tilesets/my_tileset.tres`)
5. Click Save

## Step 3: Reuse the TileSet in Other Scenes

### Method A: Load in Inspector
1. Create a new TileMapLayer in another scene
2. In the Inspector, click the **TileSet** dropdown
3. Select **"Load"** or **"Quick Load"**
4. Navigate to your saved `.tres` file
5. Click Open

### Method B: Drag and Drop
1. In the FileSystem dock, find your saved tileset (`.tres` file)
2. Drag it onto the **TileSet** property of any TileMapLayer

### Method C: Resource Path
1. Click the TileSet dropdown
2. Paste the resource path directly (e.g., `res://assets/tilesets/my_tileset.tres`)

## Important Notes

### Shared Resource (Default Behavior)
- All TileMapLayers using the same `.tres` file share the same TileSet
- Changes to the TileSet in ONE scene affect ALL scenes using it
- This is what you usually want!

### Making it Unique (Copy for One Scene)
If you need to modify the TileSet for just one scene:
1. Click the TileSet dropdown
2. Select **"Make Unique"** from the menu
3. Now changes only affect this scene

## File Organization

Recommended structure:
```
project/
├── assets/
│   └── tilesets/
│       ├── dungeon_tileset.tres
│       ├── forest_tileset.tres
│       └── cave_tileset.tres
└── scenes/
    └── levels/
        ├── level_1.tscn (uses dungeon_tileset.tres)
        └── level_2.tscn (uses dungeon_tileset.tres)
```

## Benefits

✅ Configure collision shapes once, use everywhere
✅ Set up animations once, reuse in all scenes
✅ Update tileset in one place, changes apply globally
✅ Smaller project size (one resource vs duplicates)
✅ Consistent behavior across all levels

## Quick Reference

| Action | How To |
|--------|--------|
| Create new TileSet | TileSet dropdown → "New TileSet" |
| Save TileSet | TileSet menu (📋) → "Save" |
| Load TileSet | TileSet dropdown → "Load" |
| Make unique copy | TileSet menu → "Make Unique" |
| Edit TileSet | Click TileSet to open editor |
