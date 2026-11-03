# Design records

Why the code is the way it is. Copy [0000-template.md](0000-template.md) to `NNNN-short-title.md` before a
new feature, a new dependency, or a public-interface change, and add a line below. Status moves Proposed →
Approved (by a human) → Implemented; supersede an implemented record with a new one, never rewrite it.

**Index:** read this first, then open only the records relevant to your task. This repo has no CI yet, so
nothing checks that every record is listed: keep the index complete by hand.

| # | Title | Status | Decision in one line |
|---|---|---|---|
| [0002](0002-official-git-crypt.md) | Official git-crypt | Approved | Replace the custom openssl `git-crypt` script with the official git-crypt: a symmetric key in `pass` plus Stephen's GPG key as a git-crypt user, and a pre-commit gate and self-test that refuse plaintext in files marked for encryption |
