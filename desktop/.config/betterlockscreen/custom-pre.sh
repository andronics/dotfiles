#!/bin/sh
# Sourced by betterlockscreen (prelock/postlock), not executed.
# Forget the GPG passphrase while away (Stephen, 2026-11-04); never block or fail the lock.
if command -v gpg-connect-agent >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
        timeout 2 gpg-connect-agent reloadagent /bye >/dev/null 2>&1 || :
    else
        gpg-connect-agent reloadagent /bye >/dev/null 2>&1 || :
    fi
fi
bsp hide
