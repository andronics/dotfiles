# 0004: Theme text contrast on surfaces

Status: Implemented (approved with changes by the ⚖️ Arbiter, record 0023, 2026-11-04; built in PR 108)
Date: 2026-11-04
Authors: written up by the desktop coordinator's agent, for the ⚖️ Arbiter (record 0023)

This record changes one part of the approved theming design (`ricing/DESIGN.md`, kept outside the repo
by the desktop coordinator, §4.3 "Contrast and distinctness guarantees"): which backgrounds the secondary
text role `fg_dim` and the quiet role `dim` are checked against, and whether `dim` may carry text.
Everything else in that table stands.

## Context

### The audit

An accessibility audit found two theme roles below what their use needs: `dim` at 3.0:1 on the background
(`bg`), and `fg_dim` at 3.2:1 on the raised surface (`bg_alt`), where body text needs 4.5:1 (WCAG AA,
success criterion 1.4.3). Both numbers are the Tokyo Night scheme as the resolver leaves it today (table
below: 3.03 and 3.22).

### Why it happens

The resolver (`shell/.local/share/dotlib/_theme`) sets the floors `_THEME_MIN_FG_DIM=4.5` and
`_THEME_MIN_DIM=3.0` (line 158). `_theme-floor` (line 837) checks a role against `bg` only, and the
"dimmer than fg_dim" fix-up (lines 1048-1060) compares the two roles on `bg` only. The design says the
same: "`fg_dim` on `bg` 4.5" and "`dim` on `bg` 3.0 and dimmer than `fg_dim`". `theme check`'s contrast
table (`_theme-contrast-table`) reports `fg_dim/bg` and `dim/bg`, so nothing shows the `bg_alt` numbers.

But `bg_alt` is not a minor surface. The resolver swaps it to base02 when base01 is too close to `bg`
(Catppuccin Mocha, Macchiato and Latte, both Rosé Pines, Tokyo Night), which makes it further from `bg` and closer to the dim roles, and
both roles are drawn on it: the inverse bar segments, rofi's input bar.

### Measurement

Every installed scheme (13: 10 dark, 3 light), as the resolver leaves it today. Contrast ratios, WCAG
formula; a cell in bold misses the floor its use needs (4.5 for `fg_dim`, 3.0 for `dim`). The pairs are
Catppuccin Mocha, Macchiato and Frappé with Latte, Gruvbox Dark with Light, and Rosé Pine with Dawn;
Dracula, Everforest, Kanagawa, Nord and Tokyo Night have no light twin.

| Scheme | Mode | fg_dim on bg | fg_dim on bg_alt | dim on bg | dim on bg_alt | fg_dim : dim (on bg) |
|---|---|---|---|---|---|---|
| catppuccin-frappe | dark | 5.55 | 6.23 | 3.02 | 3.39 | 1.84 |
| catppuccin-macchiato | dark | 6.62 | 5.03 | 3.15 | **2.40** | 2.10 |
| catppuccin-mocha | dark | 7.37 | 5.65 | 3.36 | **2.57** | 2.19 |
| catppuccin-latte | light | 4.50 | **3.30** | 3.00 | **2.20** | 1.50 |
| dracula | dark | 6.02 | 6.68 | 3.03 | 3.36 | 1.99 |
| everforest | dark | 5.12 | **4.44** | 3.84 | 3.33 | 1.33 |
| gruvbox-dark | dark | 4.52 | **3.55** | 3.00 | **2.36** | 1.50 |
| gruvbox-light | light | 4.54 | **3.76** | 3.01 | **2.49** | 1.51 |
| kanagawa | dark | 4.52 | 4.98 | 3.01 | 3.32 | 1.50 |
| nord | dark | 9.25 | 7.45 | 3.01 | **2.43** | 3.07 |
| rose-pine | dark | 5.48 | 4.71 | 3.42 | **2.94** | 1.60 |
| rose-pine-dawn | light | 4.51 | **4.10** | 3.02 | **2.75** | 1.49 |
| tokyo-night | dark | 4.53 | **3.22** | 3.03 | **2.16** | 1.50 |

Today's floors hold on `bg` in every scheme. On `bg_alt`, `fg_dim` misses 4.5 in 6 of 13 schemes (all
three light ones among them) and `dim` misses 3.0 in 9 of 13. Generated themes (from a wallpaper or a
colour, through matugen) go through the same resolver but were not measured: their palettes vary.

Evidence: `zsh tests/theme-contrast-measure.zsh` prints this table from the repo, with each scheme's raw
slots before the fix-ups, `fg` and `surface` too, then every cell below the floors on the worse surface
(15 today: the bold cells). It sources this checkout's `_theme` and calls the resolver only, with a scratch
`THEME_STATE_DIR` it removes after: no apply, no render, no reloader, never the live state. The option
projection below comes from `zsh tests/theme-contrast-project.zsh`, which works the same way.

### Who draws them, and as what

| Role | Where | As | On |
|---|---|---|---|
| `fg_dim` | bar `player-metadata`: the track title while paused or stopped (barctl's idle tier colours the whole cell) | **text** | bg |
| `fg_dim` | bar `audio-level`: the volume ("45%") while muted | **text** | bg |
| `fg_dim` | rofi input bar placeholder ("Type to filter..."), `fg-alt-color`, in every scheme but Catppuccin | **text** | bg_alt |
| `fg_dim` | alacritty search matches and hint ends: `bg` text on an `fg_dim` background | **text** (the same pair as fg_dim on bg) | — |
| `fg_dim` | bar crew strip: a running, idle coordinator's glyph; `player-play-pause`'s glyph while paused | icon | bg; bg_alt (inverse segment) |
| `fg_dim` | crew menu: an idle coordinator's glyph, Stop all with some running | icon | rofi row |
| `dim` | bar crew strip: a stopped coordinator; `desk`'s "+" cell; `audio-level` with no sound server; `player-play-pause` with no player | icon (no label in these states) | bg; bg_alt for play-pause |
| `dim` | crew menu: a stopped coordinator's glyph, Stop all with none running | icon | rofi row |
| `dim` | bspwm `active_border_color`, `presel_feedback_color` | border | window content |
| `dim` | polybar `bspwm` module's empty label | icon | bg (the module is on no bar today) |

So today `dim` carries no text anywhere, and `fg_dim`'s text sits on `bg` except rofi's placeholder, on
`bg_alt`. The Catppuccin schemes take the placeholder from the palette's `subtext1`, bypassing the
resolver: 7.1 or more in the dark three, 4.05 in Latte (`tests/theme-contrast-measure.zsh` prints these too). GTK draws
neither role: its dim labels are adw-gtk3's own alpha of `fg`. Dunst, the lock screen and Xresources use
neither.

## Decision

Option (a), below, stated as properties of the roles:

- **`fg_dim`** (secondary text) reaches 4.5 against the worse of `bg` and `bg_alt`.
- **`dim`** (non-text: icons, borders) reaches 3.0 against the worse of `bg` and `bg_alt`, stays below
  `fg_dim` on both, and never draws text.
- **`fg`** (body text) is unchanged: the theming design's D4 (AAA, 7:1, auto-degrading to AA 4.5) stands;
  `fg_dim` is secondary text, not body text.

In detail:

1. **Both surfaces.** `fg_dim` and `dim` are checked against `bg` and `bg_alt`, each against whichever of
   the two gives it the lower contrast. `_theme-floor` gains that "worse of" check for these two roles.
2. **Floors unchanged:** `fg_dim` ≥ 4.5 (text), `dim` ≥ 3.0 (WCAG 1.4.11, non-text: icons, borders).
3. **Hierarchy on both surfaces:** `dim`'s contrast stays below `fg_dim`'s on `bg` and on `bg_alt`; if it
   does not, `dim` is refitted to 3.0 on the worse surface, as today's fix-up does on `bg`.
4. **`dim` never draws text.** A consumer that needs quiet text uses `fg_dim`. Nothing draws `dim` as text
   today, so nothing moves; the rule goes into `_theme`'s header, the theming design and barctl's tier
   notes (its unavailable tier must keep showing a glyph only).
5. **`theme check` reports** `fg_dim/bg_alt` and `dim/bg_alt` next to the `bg` pairs, and `theme
   self-test` asserts the four pairs for every scheme.

Projected onto every scheme with the resolver's own helpers (`tests/theme-contrast-project.zsh`; a
projection, not the build): `fg_dim` moves in 6 schemes, by up to ΔE 0.09 (OKLab; Tokyo Night), `dim` in
9, by up to 0.08. Worst-surface `fg_dim : dim` stays 1.36 or more (Everforest's own 1.33 today), `fg :
fg_dim` 1.11 or more (Nord's own today).

## Alternatives considered

Each with what it costs the dim/fg_dim hierarchy and the look; numbers from the projection.

- **(a) Check both roles on both surfaces, keep the floors, `dim` never text.** Chosen. Hierarchy: kept;
  `dim` stays a clear step below `fg_dim` (1.5 at the floors, 1.36 at worst, Everforest's own). Look: the
  dim roles lift slightly where `bg_alt` is close to them (Tokyo Night, Gruvbox, Latte most), so "not
  running" glyphs read a little brighter on the bar. Cost: two more checks in the resolver.
- **(b) `dim` ≥ 4.5 too, `fg_dim` raised to keep a step above it (projected at 4.5 × 1.3 = 5.85).** Lets
  `dim` carry text. Hierarchy: squeezed from three levels into a narrow band: `fg_dim : dim` falls to about 1.3
  in 12 of 13 schemes (all but Nord) and `fg : fg_dim` to 1.2 in Latte, Everforest, Rosé Pine Dawn and Tokyo Night, so
  body text, secondary text and "not running" start to look alike. Look: the largest shift, `dim` moving
  up to ΔE 0.18 and `fg_dim` 0.16; the bar's off/idle/busy tiers, whose meaning rests partly on
  brightness, lose contrast between each other. Lost: no consumer needs `dim` as text.
- **(c) Keep the floors on `bg`, add a third role for text on a surface (say `fg_dim_alt`, ≥ 4.5 on
  `bg_alt`).** Hierarchy: untouched on `bg`; on `bg_alt` the new role sits between `fg_dim` and `fg`.
  Look: none on the bar. Lost: one more role for every template and consumer to pick between, for one
  text use today (rofi's placeholder), and it leaves `dim` at 2.2-2.9 on `bg_alt` in 9 schemes, so the
  inverse segment's "no player" glyph stays below the non-text floor.

## Consequences

- Easier: the guarantee the design promises ("the resolver guarantees contrast for each role") holds on
  every surface the roles are drawn on, and `theme check` shows it.
- Harder: nothing for consumers; the resolver does two more checks per role.
- Look: the dim roles lift in the schemes named above; Dracula, Frappé and Kanagawa are unchanged.
- Rollout: the build starts only after Stephen's click-test of the crew strip, because it brightens the
  strip's colours (the stopped and idle coordinator glyphs). Then one PR to `_theme` (and the rofi
  template, per question 2), checked with `theme self-test`
  and `theme check` against a scratch state for every scheme, then a visual scan. Applying it to the live
  desktop is a separate go.
- Rollback: revert that PR and re-apply the theme.
- Docs: `ricing/DESIGN.md` §4.3's two rows change to "on `bg` and `bg_alt`" and gain the "`dim` never
  text" rule; this repo's `_theme` header (lines 56-57) the same.

## Open questions

1. **Which option?** (a) both surfaces, same floors, `dim` never text; (b) `dim` at 4.5 with `fg_dim`
   above it; (c) a third role for text on surfaces. Recommendation: (a). It fixes every failing cell with
   the smallest change to the look and keeps the three bar tiers apart; (b) blurs them, and (c) adds a role
   for one use and leaves `dim` failing on `bg_alt`.

   **Decided (the ⚖️ Arbiter):** as recommended.
2. **Rofi's placeholder in Catppuccin.** It uses the palette's `subtext1`, which the resolver never checks
   (4.05 on Latte's `bg_alt`). Options: (i) use `fg_dim` in every scheme, so the resolver guarantees it;
   (ii) keep `subtext1` but have the template fall back to `fg_dim` when `subtext1` misses 4.5; (iii) leave
   it. Recommendation: (i). One rule for every scheme, and Catppuccin's `fg_dim` (subtext0) is within a
   step of `subtext1`, so the dark three barely change.

   **Decided (the ⚖️ Arbiter):** as recommended.
3. **Which surfaces count?** Options: `bg` and `bg_alt` only; or also `surface` (hovered and selected
   rows). Recommendation: `bg` and `bg_alt` only. Nothing draws `fg_dim` or `dim` on `surface` today; add
   it when a consumer does, with this record's rule.

   **Decided (the ⚖️ Arbiter):** as recommended.
4. **A minimum step between `fg_dim` and `dim`?** Today "dimmer" only means "lower ratio". Options: keep
   that; or require `fg_dim : dim` ≥ 1.3. Recommendation: keep it. Under (a) the worst case is 1.36,
   Everforest's own design; a step rule would move Everforest's colours for no failing check.

   **Decided (the ⚖️ Arbiter):** as recommended.
5. **Who updates `ricing/DESIGN.md`?** It lives outside the repo, owned by the desktop coordinator.
   Options: the build task edits its §4.3 rows; or the rows get a pointer to this record. Recommendation:
   the build task edits the two rows and adds "see record 0004", so the design and the code agree.

   **Decided (the ⚖️ Arbiter):** as recommended.

## Build order

0. Wait for Stephen's crew click-test (the build brightens the crew strip's colours).
1. Resolver: a "worse of `bg` and `bg_alt`" floor for `fg_dim` and `dim`; the hierarchy check on both
   surfaces; `theme check`'s table gains `fg_dim/bg_alt` and `dim/bg_alt`; `theme self-test` asserts the
   four pairs for every scheme. The `_theme` header states the rule.
2. Rofi template: the placeholder colour per question 2.
3. The "`dim` never text" rule written into the theming design and, as a follow-up issue in
   andronics/desktop-tools, barctl's tier notes (its unavailable tier keeps a glyph only).
4. Checks against a scratch state: `theme self-test`, `theme check` for every scheme, `theme pick
   --dry-run`, `rofi-preview` on a light and a dark scheme; `tests/theme-contrast-measure.zsh` shows no
   cell below the floors.
5. `ricing/DESIGN.md` §4.3 updated (question 5); status here moves to Implemented when the PR merges.
   Applying it to the live desktop waits for its own go.

## Change log

| When | Change |
|---|---|
| 2026-11-04 | Proposed (PR 99) |
| 2026-11-04T08:28:09+00:00 | Approved by the arbiter, 2026-11-04T08:28:09+00:00, with changes (❓ 2026-11-04 Approve Dotfiles Record 0004 On Theme Text Contrast); the five open questions as recommended |
| 2026-11-04 | Built in PR 108 (`_theme`: fg_dim and dim checked on bg and bg_alt, `theme check` and `theme self-test` report the four pairs; rofi's placeholder is fg_dim); status stays Approved until the live switch |
| 2026-11-04T16:32:34+00:00 | Implemented: built in PR 108 and live on the desktop (`theme apply` of the current scheme): `theme check` shows fg_dim and dim passing on bg and bg_alt (Dracula: fg_dim 6.02/6.68, dim 3.03/3.36), `theme self-test` 133/133, the measurement script 0 below the floors. Status change decided by the arbiter. |
