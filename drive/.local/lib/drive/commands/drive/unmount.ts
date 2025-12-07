import { Command } from "commander";

export function driveUnmountCommand(program: Command): void {
    program
        .command("unmount")
        .description("")
}