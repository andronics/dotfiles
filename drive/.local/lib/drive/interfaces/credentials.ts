export interface Credential {
    scope: string
    client_id: string
    client_secret: string
    token: CredentialToken
}


export interface Credentials {
    [key: string]: Credential
}

export interface CredentialToken {
    access_token: string
    token_type: string
    refresh_token: string
    expiry: string
}