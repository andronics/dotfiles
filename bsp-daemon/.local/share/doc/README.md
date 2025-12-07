# bspc-manager - Dynamic bspwm Layout Manager

A powerful shell-based tool for managing bspwm layouts and process assignments dynamically.

## Features

- **Dynamic Layout Management**: Create and manage fixed layouts with ease
- **Process Assignment**: Automatically assign applications to specific desktops/positions
- **Template System**: Pre-built layout templates (split-vertical, split-horizontal, triple-column, quad)
- **Rule Management**: Persistent rules for window placement
- **Preselection Support**: Manual window placement with preselection
- **Layout Saving**: Save and restore desktop layouts
- **CLI Interface**: Complete command-line interface for all operations

## Quick Start

1. **Initialize the tool:**
   ```bash
   ./bspc-manager init
   ```

2. **Create a layout template:**
   ```bash
   ./bspc-manager template triple-column dev
   ```

3. **Assign applications to desktops:**
   ```bash
   ./bspc-manager assign-desktop firefox web
   ./bspc-manager assign-desktop code dev
   ```

4. **Create specific positioning:**
   ```bash
   ./bspc-manager assign-position terminal primary dev west 0.3
   ```

## Example Workflows

### Development Workspace Setup
```bash
# Create desktops
./bspc-manager create-desktop dev
./bspc-manager create-desktop web

# Set up layouts
./bspc-manager template triple-column dev
./bspc-manager template split-vertical web

# Assign applications
./bspc-manager assign-desktop code dev
./bspc-manager assign-desktop firefox web

# Save the layout
./bspc-manager save-layout dev-workspace
```

### Dynamic Window Management
```bash
# Focus and move windows
./bspc-manager focus west
./bspc-manager move east
./bspc-manager resize right 50

# Change window states
./bspc-manager state floating
./bspc-manager state fullscreen
```

### Manual Window Placement
```bash
# Preselect area for next window
./bspc-manager presel east
./bspc-manager presel-ratio 0.6

# Launch application (will use preselected area)
firefox &

# Cancel preselection if needed
./bspc-manager presel-cancel
```

## Available Layout Templates

- **split-vertical**: Simple vertical split (2 columns)
- **split-horizontal**: Simple horizontal split (2 rows)  
- **triple-column**: Three equal columns
- **quad**: 2x2 grid layout

## Configuration Files

- **Config Directory**: `~/.config/bspc-manager/`
- **Rules File**: `~/.config/bspc-manager/rules.conf`
- **Layouts Directory**: `~/.config/bspc-manager/layouts/`
- **Log File**: `~/.config/bspc-manager/bspc-manager.log`

## Rules Configuration Format

Edit `~/.config/bspc-manager/rules.conf`:

```
# Format: <class> <options>
firefox desktop=web
code desktop=dev state=tiled
discord desktop=chat state=floating
terminal desktop=dev state=tiled
```

## Command Categories

### Node Management
- `focus <selector>` - Focus a window
- `move <direction>` - Move window in direction
- `resize <direction> [amount]` - Resize window
- `state <state>` - Set window state
- `info [node]` - Show window information

### Desktop Management  
- `create-desktop <name>` - Create new desktop
- `focus-desktop <name>` - Switch to desktop
- `layout <layout>` - Set desktop layout

### Process Assignment
- `assign-desktop <class> <desktop>` - Assign app to desktop
- `assign-position <class> <mon> <desk> [dir] [ratio]` - Assign to position

### Layout Management
- `template <type>` - Create layout template
- `save-layout <name>` - Save current layout
- `list-layouts` - Show available layouts

## Integration with bspwm

This tool works alongside your existing bspwm configuration. Add to your `bspwmrc`:

```bash
# Load bspc-manager rules on startup
/path/to/bspc-manager load-rules

# Optional: Run development setup
/path/to/bspc-dev-setup
```

## Keybinding Integration

Add to your sxhkd config:

```
# Quick layout switching
super + shift + {1,2,3,4}
    bspc-manager template {split-vertical,split-horizontal,triple-column,quad}

# Application assignment
super + shift + f
    bspc-manager assign-desktop {firefox,code,discord} {web,dev,chat}

# Window management
super + {h,j,k,l}
    bspc-manager focus {west,south,north,east}

super + shift + {h,j,k,l}
    bspc-manager move {west,south,north,east}
```

## Troubleshooting

- **Check logs**: `tail -f ~/.config/bspc-manager/bspc-manager.log`
- **Verify bspc**: Ensure bspwm is running and bspc is available
- **Reset config**: Remove `~/.config/bspc-manager/` and run `init`

## Advanced Usage

### Custom Rules with Multiple Options
```bash
./bspc-manager add-rule "Firefox" "desktop=web state=tiled follow=on"
```

### Complex Positioning
```bash
# Create master-stack layout manually
./bspc-manager focus-desktop dev
./bspc-manager presel east -o 0.7
./bspc-manager assign-position editor primary dev east 0.7
./bspc-manager presel south -o 0.5
./bspc-manager assign-position terminal primary dev south 0.5
```

### Batch Operations
```bash
# Set multiple rules at once
for app in firefox code discord; do
    ./bspc-manager assign-desktop $app ${app}_desktop
done
```

This tool provides a complete solution for dynamic bspwm management while maintaining the flexibility and power of the underlying window manager.