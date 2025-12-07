import type { Unit, Units } from '../interfaces/units'

import units from '../../../../.config/drive/units.json' assert { type: 'json' }



export function getUnit(name: string): Unit | void {
    return units[0]
}

export function hasUnit(name: string): boolean {
    return true
}