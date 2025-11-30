# Lighting Components

Reusable lighting components for your game.

## 🔦 Flashlight

Directional beam light with configurable types.

### Usage:
```gdscript
# In scene editor:
# Add node → Node → "Flashlight" (search for it)

# Or via code:
var flashlight = preload("res://components/lighting/flashlight.tscn").instantiate()
flashlight.position = Vector2(0, -15)  # Forward of entity
flashlight.flashlight_type = Flashlight.FlashlightType.MEDIUM
add_child(flashlight)
```

### Types:
- **SMALL**: Player/crew (energy: 1.2, range: ~64px)
- **MEDIUM**: Ships (energy: 1.5, range: ~90px)
- **LARGE**: Trawler (energy: 2.5, range: ~160px)
- **SPOTLIGHT**: Focused beam (energy: 2.0, range: ~112px)

### Properties:
- `flashlight_type`: Choose preset configuration
- `cast_shadows`: Enable/disable shadow casting
- `warm_color`: Warm white (true) vs cool white (false)

### Methods:
```gdscript
flashlight.set_flashlight_enabled(true)  # Toggle on/off
flashlight.set_intensity(1.5)            # Change brightness
flashlight.set_beam_width(3.0)           # Adjust width
```

## 💡 AmbientLight

Soft glow around entities (no shadows).

### Usage:
```gdscript
# Add node → Node → "AmbientLight"

# Or via code:
var glow = preload("res://components/lighting/ambient_light.tscn").instantiate()
glow.glow_radius = 1.2
glow.glow_intensity = 0.6
add_child(glow)
```

### Properties:
- `glow_radius`: Size multiplier (1.0 = ~32px, 2.0 = ~64px)
- `glow_color`: Tint color (default: soft blue-white)
- `glow_intensity`: Brightness (0.0-2.0)

## 📦 Examples:

### Player Ship:
```gdscript
# Ambient glow at center
var ambient := preload("res://components/lighting/ambient_light.tscn").instantiate()
ambient.glow_radius = 1.2
add_child(ambient)

# Flashlight forward
var flashlight := preload("res://components/lighting/flashlight.tscn").instantiate()
flashlight.position = Vector2(0, -15)
flashlight.flashlight_type = Flashlight.FlashlightType.MEDIUM
add_child(flashlight)
```

### Trawler Front:
```gdscript
var floodlight := preload("res://components/lighting/flashlight.tscn").instantiate()
floodlight.position = Vector2(0, -145)
floodlight.flashlight_type = Flashlight.FlashlightType.LARGE
add_child(floodlight)
```

### Enemy Eyes:
```gdscript
var eyes := preload("res://components/lighting/ambient_light.tscn").instantiate()
eyes.glow_radius = 0.5
eyes.glow_color = Color(1, 0, 0, 1)  # Red
eyes.glow_intensity = 0.5
add_child(eyes)
```

## 🎨 Color Presets:

```gdscript
# Warm lights
Color(1, 0.95, 0.85)   # Warm white (flashlight)
Color(1, 0.85, 0.6)    # Industrial orange
Color(1, 0.9, 0.7)     # Mining lamp

# Cool lights
Color(0.9, 0.95, 1)    # Cool white
Color(0.3, 0.6, 1)     # Blue engine glow
Color(0.2, 0.8, 1)     # Cyan tech

# Colored
Color(1, 0, 0)         # Red danger
Color(0, 1, 0.4)       # Green status
Color(1, 0.3, 0)       # Orange alert
```

