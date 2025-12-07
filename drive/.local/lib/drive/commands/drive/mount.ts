import { Command } from "commander";

export function driveMountCommand(program: Command): void {
    program
        .command("mount <unit>")
        .description("Mount unit as a drive")
        .hook('preAction', driveMountPreAction)
        .action(driveMountAction)
        .hook('postAction', (selfCommand) => {})
}

export function driveMountPreAction(selfCommand, actionCommand) {
    if (selfCommand.opts().trace) {
        // do some loggings
        console.log(`About to call action handler for subcommand: ${actionCommand.name()}`);
        console.log('arguments: %O', actionCommand.args);
        console.log('options: %o', actionCommand.opts());
    }
}

export function driveMountAction(unit) {

}