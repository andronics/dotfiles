export interface Filter{
    audio?: FilterAudio
    filename: string
    mimetype: string
    video?: FilterVideo 
}

export interface Filters {
    [key: string]: Filter
}

export interface FilterAudio {
    bitRate?: number
    format?: string
}

export interface FilterVideo {
    bitDepth?: number
    bitRate?: number
    format?: string
    height?: number
    width?: number
}