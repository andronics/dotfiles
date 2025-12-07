# bspc-service Architecture

## Overview

The bspc-service system provides proactive bspwm window management through a service/client architecture:

- **bspc-service**: Background daemon that monitors bspwm events and automatically manages layouts
- **bspc-request**: Client tool for requesting actions and communicating with the service
- **bspc-manager**: Original manual tool (legacy, still functional)

## Architecture Components

```
┌─────────────────┐    IPC     ┌──────────────────┐
│   bspc-request  │◄──────────►│   bspc-service   │
│    (client)     │   socket   │    (daemon)      │
└─────────────────┘            └──────────────────┘
         │                              │
         │                              │
         ▼                              ▼
┌─────────────────┐            ┌──────────────────┐
│      bspc       │            │  bspc subscribe  │
│   (direct)      │            │   (monitoring)   │
└─────────────────┘            └──────────────────┘
         │                              │
         └──────────────┬───────────────┘
                        ▼
                ┌──────────────────┐
                │      bspwm       │
                │ (window manager) │
                └──────────────────┘
```

## Core Features

### Proactive Management (bspc-service)

1. **Event Monitoring**: Subscribes to all bspwm events in real-time
2. **Automatic Process Assignment**: Assigns windows to desktops based on class/rules
3. **Smart Layout Management**: Automatically applies layouts based on window count and type
4. **Persistent Configuration**: Maintains state and rules across restarts

### Client Interface (bspc-request)

1. **Direct Window Management**: Traditional window operations with service notification
2. **Smart Layout Requests**: Request specific layout types for desktops
3. **Workspace Management**: Create complete workspaces with app assignments
4. **Auto-Configuration**: Pre-built configurations for common usage patterns

## Event Processing Flow

```
1. bspwm generates event (node_add, desktop_focus, etc.)
       ↓
2. bspc-service receives event via 'bspc subscribe'
       ↓
3. Service processes event based on type:
   - node_add: Check for auto-assignment rules
   - desktop changes: Apply smart layouts
   - node_remove: Rebalance layouts
       ↓
4. Service takes appropriate action:
   - Move windows to correct desktops
   - Apply layout templates
   - Update internal state
       ↓
5. Service logs action and saves state
```

## Configuration Files

### Service Configuration
- `~/.config/bspc-manager/rules.conf` - Process assignment rules
- `~/.config/bspc-manager/service.state` - Persistent service state
- `~/.config/bspc-manager/service.log` - Service activity log

### IPC Communication
- `~/.config/bspc-manager/service.sock` - Unix socket for client-service communication
- `~/.config/bspc-manager/service.pid` - Service process ID

## Smart Layout System

### Layout Types

1. **dev-triple**: Three-column layout for development
   - Applied to desktops named "dev", "code", "work"
   - Triggers when 3 windows are present

2. **master-stack**: Master window + stack
   - Applied to "web", "browser" desktops
   - 60% master area, stacked secondaries

3. **balanced**: Auto-balanced layout
   - Applied to "chat", "comm" desktops
   - Equal spacing for all windows

### Automatic Triggers

- **Window Count**: Layouts applied based on number of windows
- **Desktop Type**: Layout selection based on desktop name patterns
- **Application Class**: Special handling for certain application types

## Rule System

### Rule Format
```
<class> <options>
```

### Supported Options
- `desktop=<name>` - Assign to specific desktop
- `state=<state>` - Set window state (floating, tiled, etc.)
- `monitor=<name>` - Assign to specific monitor
- `node=<selector>` - Assign to specific node

### Example Rules
```
firefox desktop=web
code desktop=dev state=tiled
discord desktop=chat state=floating
terminal monitor=focused desktop=dev
```

## Inter-Process Communication

### Socket-based IPC
- **Location**: `~/.config/bspc-manager/service.sock`
- **Type**: Named pipe (FIFO)
- **Protocol**: Simple text-based commands

### IPC Commands
- `status` - Get service status
- `reload` - Reload configuration
- `stats` - Get service statistics
- `enable_auto_layout <desktop> <type>` - Enable auto-layout for desktop
- `disable_auto_layout <desktop>` - Disable auto-layout

## Service Lifecycle

### Startup
1. Check for existing service instance
2. Create PID file and socket
3. Load configuration and rules
4. Start event monitoring loop
5. Start IPC server

### Runtime
1. Process bspwm events continuously
2. Handle client requests via IPC
3. Periodically save state
4. Log all activities

### Shutdown
1. Clean up socket and PID file
2. Save current state
3. Terminate monitoring loops

## Error Handling

### Service Resilience
- **Event Processing**: Continue on individual event errors
- **Rule Application**: Log failures but continue operation
- **IPC Handling**: Handle client disconnections gracefully

### Client Behavior
- **Service Check**: Auto-start service if not running
- **Timeout Handling**: Request timeouts with fallback to direct bspc
- **Fallback Mode**: Direct bspc operations if service unavailable

## Performance Considerations

### Event Processing
- Lightweight event handlers
- Batch operations where possible
- Async IPC handling

### Resource Usage
- Minimal memory footprint
- Efficient rule matching
- Periodic state cleanup

## Security Model

### User-level Service
- Runs as user process, not system daemon
- Limited to user's bspwm session
- No elevated privileges required

### File Permissions
- Configuration files readable by user only
- Socket accessible only to user
- Log files protected from other users

## Integration Points

### bspwmrc Integration
```bash
# Start service on bspwm startup
pgrep -x bspc-service > /dev/null || bspc-service start &
```

### sxhkdrc Integration
```bash
# Smart layout hotkeys
super + shift + {1,2,3}
    bspc-request layout {auto-balance,triple-column,master-stack}
```

### Systemd Integration
- User service for automatic startup
- Proper dependency management
- Service restart on failure

## Extensibility

### Adding Layout Types
1. Implement layout function in `bspc-service`
2. Add to `apply_auto_layout()` switch statement
3. Update client help and documentation

### Custom Event Handlers
1. Add event case to `process_event()`
2. Implement handler function
3. Update service state management

### New IPC Commands
1. Add command case to `handle_ipc_request()`
2. Implement command handler
3. Update client with new command support