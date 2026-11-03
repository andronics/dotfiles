# 0002: Official git-crypt

Status: Approved (by the brain coordinator, on Stephen's request, 2026-11-03)
Date: 2026-11-03
Authors: Stephen Cox (decision, via the brain coordinator); the dotfiles coordinator (record)

## Context

This repo is public. Files matching a pattern in `.gitattributes` (today only `*.env`) are meant to be
stored encrypted, through git's clean/smudge filters.

Until now the filter was a custom zsh script, `shell/.local/bin/git-crypt`: `openssl enc -aes-256-cbc
-pbkdf2` with a passphrase read from `pass`. Being on `PATH` under the same name, it shadowed the official
git-crypt (`/usr/bin/git-crypt` 0.8.0, Arch package `git-crypt`). Problems with it:

- Home-grown crypto: random-salted CBC, so every `git add` re-encrypts to a different blob (spurious
  diffs), no authentication of the ciphertext, and no format others can read or audit.
- Symmetric only: the passphrase in `pass` is the single way in; there is no per-person access.
- A name clash with the official tool, which confuses anyone (or any agent) who reads "git-crypt" and
  expects Andrew Ayer's tool and its commands (`unlock`, `status`, `add-gpg-user`).
- No guard: in a clone where the filter wasn't wired, git silently falls through to the identity filter
  and commits a matching file in plaintext, to a public repo.

No file matching a git-crypt pattern is tracked at HEAD, so nothing needs re-encrypting. History holds
13 blobs from earlier patterns (`shell/.config/remote/credentials.json`, `shell/.config/remote/keys/*.json`,
removed by 2026-11-03); all were checked and are old-script ciphertext (`Salted__` header), none plaintext.

## Decision

- Use the official git-crypt and delete the custom script.
- Two ways to unlock:
  - a symmetric key, made with `git-crypt init` and stored in `pass` at
    `hosts/desktop/dotfiles-git-crypt-key-official` as base64 of `git-crypt export-key`;
  - Stephen's GPG key (`903B 5312 DE29 99E5 413A  B134 C7EF AA22 63FA 759F`) as a git-crypt user: the key
    wrapped to it lives in `.git-crypt/keys/default/0/`, encrypted to that GPG key and safe to publish.
- `shell/.postinstall` sets the repo up on install. It removes the old script's `filter.git-crypt.*`
  config (which points at the deleted script), sets `core.hooksPath=.githooks`, and, if the repo is
  locked and the key is in `pass`, unlocks it: the key is decoded into a `mktemp` file in
  `$XDG_RUNTIME_DIR` (or `/dev/shm`) under `umask 077` and `shred -u`-ed by an exit trap. Without `pass`
  it says to use `git-crypt unlock` with the GPG key. It warns and never fails the install.
- A hard gate, because the repo is public:
  - `.githooks/pre-commit` runs `.githooks/check-crypt --staged`, which refuses the commit if any staged
    file whose `filter` attribute is `git-crypt` doesn't start with git-crypt's `\0GITCRYPT\0` header.
  - `./dotfiles check-crypt` (the same script, default mode) checks every file at `HEAD` the same way and
    runs `git-crypt status -e`.
  - The hooks live in the repo (`.githooks/`) and are installed with a repo-local `core.hooksPath`, because
    `~/.gitconfig` sets a global `core.hooksPath` (`~/.git-hooks`), so `.git/hooks` is never read. A
    repo-local `core.hooksPath` hides the global hooks, so `.githooks/_chain` hands each hook on to its
    global namesake (`post-checkout`, `post-commit`, `pre-push` today; `pre-commit` after the gate).

## Alternatives considered

- Keep the custom script and add the gate: keeps the home-grown crypto and the name clash.
- GPG users only, no symmetric key: unlocking would need the GPG key on every host. The symmetric key in
  `pass` keeps the existing GPG → `pass` → key chain working where `pass` is already set up.
- Install the hook into `.git/hooks`: ignored, because of the global `core.hooksPath`.
- Put the gate in the global hooks dir: it would run in every repo, and that dir isn't tracked here.

## Consequences

- Encrypted blobs are deterministic (git-crypt uses AES-CTR with a nonce derived from the content), so
  re-adding an unchanged file produces no diff.
- `git-crypt unlock` needs a clean working tree; a dirty one makes the post-install unlock warn and stop.
- A clone used before `shell/.postinstall` runs has no hook; the gate starts with the first install.
  `git commit --no-verify` bypasses it; `./dotfiles check-crypt` still catches the result before a push.
- Live migration on the desktop (done by the dotfiles coordinator, not by this change): remove the old
  filter config from `~/.dotfiles/.git/config`, unlock from `pass`, set `core.hooksPath`, check
  `git-crypt status`, and delete the stale `~/.local/bin/git-crypt` stow link.
- The old historical blobs remain readable only with the old key (`hosts/desktop/dotfiles-git-crypt-key`).

## For Stephen

- Deleting the old `pass` entry `hosts/desktop/dotfiles-git-crypt-key` is your call. Nothing needs it
  after the migration, except reading the 13 retired, old-encrypted credential files still in this public
  repo's history. Recommendation: keep it until you've confirmed those credentials (the `remote` mount
  manager's service-account keys and OAuth credentials) are revoked, then delete it.

## Open questions

None.
