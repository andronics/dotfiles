
import { Command } from 'commander';

import { unitsAddCommand } from './add'
import { unitsEditCommand } from './edit'
import { unitsListCommand } from './list'
import { unitsRemoveCommand } from './remove'

export function unitsCommands(program: Command): void {
    
    const units = program
        .command("units")
        .description("Manage Units")

    unitsAddCommand(units)
    unitsEditCommand(units)
    unitsListCommand(units)
    unitsRemoveCommand(units)
        
}