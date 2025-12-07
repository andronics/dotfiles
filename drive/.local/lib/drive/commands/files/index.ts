
import { Command } from 'commander';

import { filesUploadCommand } from './upload'

export function filesCommands(program: Command): void {
    
    const files = program
        .command("files")
        .description("Manage Files")

    filesUploadCommand(files)
        
}