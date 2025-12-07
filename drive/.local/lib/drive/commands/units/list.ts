import { Command } from "commander";

export function unitsListCommand(program: Command): void {
    program
        .command("list")
        .description("")
}