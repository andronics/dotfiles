# Design records

Why the code is the way it is. Copy [0000-template.md](0000-template.md) to `NNNN-short-title.md` before a
new feature, a new dependency, or a public-interface change, and add a line below. Status moves Proposed →
Approved (by a human) → Implemented; supersede an implemented record with a new one, never rewrite it.

**Index:** read this first, then open only the records relevant to your task. This repo has no CI yet, so
nothing checks that every record is listed: keep the index complete by hand.

| # | Title | Status | Decision in one line |
|---|---|---|---|
| [0001](0001-polybar-ipc-module-taxonomy.md) | Polybar IPC module taxonomy | Proposed | Bar modules that show live state become `custom/ipc` modules redrawn by a controller process, in three kinds (single-item, multi-item, aggregate), with right-click menus, icon-first labels and a three-tier colour scheme (unavailable, idle, active) |
