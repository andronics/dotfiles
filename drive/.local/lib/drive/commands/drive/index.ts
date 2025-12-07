
import { Command } from 'commander';

import { driveMountCommand } from './mount'
import { driveUnmountCommand } from './unmount'

export function driveCommands(program: Command): void {
    
    const drive = program
        .command("drive")
        .description("Manage Drives")

    driveMountCommand(drive)
    driveUnmountCommand(drive)
        
}