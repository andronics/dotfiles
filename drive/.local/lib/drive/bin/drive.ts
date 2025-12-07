#!/usr/bin/env ts-node

import { Command } from 'commander'

import { driveCommands } from '../commands/drive'
import { filesCommands } from '../commands/files'
import { unitsCommands } from '../commands/units'

import * as pkg from '../package.json'

const program = new Command()

program
    .name(pkg.name)
    .description(pkg.description)
    .version(pkg.version)
    .option('-v, --verbose', 'Enable verbose mode')

driveCommands(program)
filesCommands(program)
unitsCommands(program)

program.parse(process.argv)