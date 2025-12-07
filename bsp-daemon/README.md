# BSP Daemon - Proactive bspwm Management System

A comprehensive suite of tools for proactive bspwm window management following Linux standards and your dotfiles structure.

## 🏗️ Directory Structure

```
.dotfiles/bsp-daemon/
├── .config/                    # Configuration files (XDG spec)
│   ├── bsp-daemon/            # Example configuration
│   │   ├── rules.conf         # Process assignment rules
│   │   ├── layouts/           # Saved layouts
│   │   └── *.log              # Log files
│   └── zsh/.zlogin.d/         # Shell integration
│       └── 50-bsp-daemon      # Auto-start script
├── .local/                     # User-local files (XDG spec)
│   ├── bin/                   # Executables
│   │   ├── bspc-service       # Proactive daemon
│   │   ├── bspc-request       # Client tool
│   │   └── bspc-manager       # Legacy manual tool
│   └── share/                 # Shared resources
│       ├── doc/               # Documentation & examples
│       │   ├── README.md      # Detailed usage guide
│       │   ├── ARCHITECTURE.md # Technical architecture
│       │   ├── bspc-dev-setup # Example workspace setup
│       │   ├── bspc-keybinds  # Keybinding helper
│       │   └── sxhkdrc-bspc-manager # sxhkd configuration
│       └── systemd/user/      # User systemd services
│           └── bspc-service.service
├── install-bspc-tools         # Installation script
└── README.md                  # This file
```

## 🎯 Architecture Benefits

### XDG Base Directory Compliance
- **`.config/`** - User configuration files
- **`.local/bin/`** - User executables  
- **`.local/share/`** - User data files
- **`.local/share/systemd/user/`** - User systemd services
- **`.local/share/doc/`** - Documentation and examples

### Follows Your Dotfiles Pattern
- **Modular structure** like your other `bsp-*` tools
- **Self-contained** with all dependencies included
- **Integration ready** via `.config/zsh/.zlogin.d/`

### Linux Standards Compliant
- **FHS compliance** for file placement
- **Systemd user services** for daemon management
- **XDG configuration** directory usage
- **Standard documentation** locations

## 🚀 Quick Start

### Installation
```bash
cd ~/.dotfiles/bsp-daemon
./install-bspc-tools
```

### Direct Usage (No Installation)
```bash
# Start service
~/.dotfiles/bsp-daemon/.local/bin/bspc-service start

# Use client
~/.dotfiles/bsp-daemon/.local/bin/bspc-request auto-config developer
```

### Systemd Integration
```bash
# Link service file
ln -sf ~/.dotfiles/bsp-daemon/.local/share/systemd/user/bspc-service.service \
       ~/.config/systemd/user/

# Enable and start
systemctl --user enable bspc-service
systemctl --user start bspc-service
```

## 🔧 Tools Overview

### bspc-service (Proactive Daemon)
- **Event monitoring**: Real-time bspwm event processing  
- **Auto-assignment**: Rules-based window placement
- **Smart layouts**: Context-aware layout management
- **Persistent state**: Configuration survives restarts

### bspc-request (Client Interface)
- **Enhanced operations**: Window management with service integration
- **Workspace creation**: Complete setups with one command
- **Auto-configuration**: Pre-built patterns (dev, media, communication)  
- **Service control**: Start/stop/status management

### bspc-manager (Legacy Tool)
- **Manual operations**: Direct bspwm control
- **Layout templates**: Pre-defined patterns
- **Rule management**: Window assignment rules

## 📁 Configuration

### Main Config Directory
`~/.config/bsp-daemon/` (follows XDG specification)

### Key Files
- `rules.conf` - Process assignment rules
- `layouts/` - Saved layout definitions  
- `*.log` - Service activity logs
- `service.{sock,pid,state}` - Runtime files

### Auto-Start Integration
The `.config/zsh/.zlogin.d/50-bsp-daemon` file provides automatic service startup when bspwm is detected.

## 🔗 Integration Examples

### bspwmrc Integration
```bash
# Service auto-starts via zsh integration, or manual start:
pgrep -x bspc-service > /dev/null || ~/.dotfiles/bsp-daemon/.local/bin/bspc-service start &
```

### sxhkdrc Integration  
```bash
# Smart layouts
super + shift + {1,2,3}
    ~/.dotfiles/bsp-daemon/.local/bin/bspc-request layout {auto-balance,triple-column,master-stack}

# Workspace creation
super + shift + w
    ~/.dotfiles/bsp-daemon/.local/bin/bspc-request workspace dev code vim terminal
```

## 💡 Advantages of This Structure

### Maintainability
- **Standard locations** - Easy to find and manage files
- **Separation of concerns** - Config, executables, docs, services properly separated
- **Version control friendly** - Clean structure for git management

### Integration
- **Dotfiles compatible** - Matches your existing `.config/` and `.local/` structure
- **Systemd ready** - Services in standard location
- **Shell integration** - Auto-start via zsh login hooks

### Portability  
- **Self-contained** - All files within the bsp-daemon directory
- **XDG compliant** - Works with any XDG-compliant system
- **Standard paths** - Follows Linux filesystem hierarchy

## 🛠️ Development

### Adding New Features
1. **Executables** → `.local/bin/`
2. **Config files** → `.config/bsp-daemon/`  
3. **Documentation** → `.local/share/doc/`
4. **Services** → `.local/share/systemd/user/`

### Testing
```bash
# Test tools directly from dotfiles
~/.dotfiles/bsp-daemon/.local/bin/bspc-request service status
~/.dotfiles/bsp-daemon/.local/share/doc/bspc-dev-setup
```

---

This structure provides a clean, maintainable, and standards-compliant organization that integrates seamlessly with your existing dotfiles architecture.