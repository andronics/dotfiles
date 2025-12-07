export interface Unit {
    credentials: string
    drive_id: string
    mountpoint: string
}

export interface Units {
    [key: string]: Unit[]
}