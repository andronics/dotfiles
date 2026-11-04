#!/usr/bin/env zsh
# Tests for brain-links (shell/.local/bin/brain-links over dotlib
# _brain_links): one link per brain tool, never clobbering what isn't its own.
#
# Scratch dirs only: BRAIN_BIN is a stub tool folder and BRAIN_LINKS_DIR a
# stub link folder; nothing touches ~/.local/bin or /mnt/brain. The journal
# is off (TOOL_JOURNAL=off).
#
#   zsh tests/brain-links.zsh

emulate -L zsh
setopt no_unset

unset TOOL_STATS COORDINATOR LOG_LEVEL DISPATCHER_DRY_RUN DISPATCHER_VERBOSE
typeset -r REPO=${0:A:h:h}
mkdir -p ~/.cache || exit 1
typeset -r S=$(mktemp -d ~/.cache/brain-links-test.XXXXXX)
[[ -d ${S:-} ]] || exit 1
typeset -r BIN=$S/brain/bin LINKS=$S/links OTHER=$S/other

export DOTLIB=$REPO/shell/.local/share/dotlib TOOL_JOURNAL=off
export BRAIN_BIN=$BIN BRAIN_LINKS_DIR=$LINKS

integer pass=0 fail=0
typeset out rc
cleanup() { rm -rf -- "${S:?}"; }
trap cleanup EXIT

ok()  { (( ++pass )); print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

# bl <args>: runs the wrapper (zsh -f, so ~/.zshenv can't repoint DOTLIB or
# BRAIN_BIN).
bl() { rc=0; out=$(zsh -f $REPO/shell/.local/bin/brain-links "$@" 2>&1) || rc=$?; }

# fresh: a brain with tools alpha, beta, gamma (executable) and notes (not),
# a folder of links holding a regular file named gamma, a foreign link named
# beta, an unrelated dangling link and a dangling link into the brain.
fresh() {
    rm -rf -- "${S:?}/brain" "${S:?}/links" "${S:?}/other"
    mkdir -p $BIN $LINKS $OTHER
    local t; for t in alpha beta gamma; do print '#!/bin/sh' >$BIN/$t; chmod +x $BIN/$t; done
    print 'not a tool' >$BIN/notes
    print -r -- 'mine' >$LINKS/gamma
    print '#!/bin/sh' >$OTHER/beta; chmod +x $OTHER/beta
    ln -s $OTHER/beta $LINKS/beta
    ln -s $OTHER/gone $LINKS/unrelated
    ln -s $BIN/retired $LINKS/retired
}

# 1. Dry run: says what it would do, changes nothing.
fresh; bl --dry-run
check "dry run exits 0" '(( rc == 0 ))' "rc=$rc"
check "dry run lists alpha to create" '[[ $out == *"would create alpha -> $BIN/alpha"* ]]' "$out"
check "dry run lists retired to remove" '[[ $out == *"would remove retired"* ]]' "$out"
check "dry run creates nothing" '[[ ! -e $LINKS/alpha && ! -L $LINKS/alpha ]]'
check "dry run removes nothing" '[[ -L $LINKS/retired ]]'
check "dry run counts" '[[ $out == *"would create 1, keep 0, skip 2 (not ours), would remove 1"* ]]' "$out"

# 2. A real run.
fresh; bl
check "run exits 0" '(( rc == 0 ))' "rc=$rc $out"
check "creates the missing link" '[[ -L $LINKS/alpha && $(readlink $LINKS/alpha) == $BIN/alpha ]]'
check "never replaces a regular file" '[[ ! -L $LINKS/gamma && $(<$LINKS/gamma) == mine ]]'
check "never replaces a foreign link" '[[ $(readlink $LINKS/beta) == $OTHER/beta ]]'
check "warns of the file and the foreign link" '[[ $out == *"$LINKS/gamma is not a link"* && $out == *"$LINKS/beta points at $OTHER/beta"* ]]' "$out"
check "skips a non-executable" '[[ ! -e $LINKS/notes && ! -L $LINKS/notes ]]'
check "removes a dangling link into BRAIN_BIN" '[[ ! -L $LINKS/retired ]]'
check "keeps a dangling link elsewhere" '[[ -L $LINKS/unrelated ]]'

# 3. Again: the link it made is kept, and nothing prints.
rm -f -- "${LINKS:?}/gamma" "${LINKS:?}/beta"; bl
check "second run is quiet" '[[ -z $out ]] && (( rc == 0 ))' "rc=$rc $out"
check "keeps its own link" '[[ $(readlink $LINKS/alpha) == $BIN/alpha ]]'
bl --verbose
check "verbose reports a keep" '[[ $out == *"keep    alpha"* && $out == *"keep 3"* ]]' "$out"

# 4. A tool removed from the brain: its link goes; a tool added: a link comes.
rm -f -- "${BIN:?}/alpha" && print '#!/bin/sh' >$BIN/delta && chmod +x $BIN/delta; bl
check "removed tool's link goes" '[[ ! -L $LINKS/alpha ]]'
check "added tool's link comes" '[[ $(readlink $LINKS/delta) == $BIN/delta ]]'

# 5. A tool that is itself a link into the brain's repo still counts.
fresh; ln -s $BIN/alpha $BIN/alias; bl
check "links a tool that is a link" '[[ $(readlink $LINKS/alias) == $BIN/alias ]]'

# 6. No brain: nothing happens, exit 0.
fresh; BRAIN_BIN=$S/nobrain bl --dry-run
check "no BRAIN_BIN dir: exit 0, no output" '(( rc == 0 )) && [[ -z $out ]]' "rc=$rc $out"
BRAIN_BIN=$S/nobrain bl
check "no BRAIN_BIN dir: links untouched" '[[ -L $LINKS/retired && ! -e $LINKS/alpha && ! -L $LINKS/alpha ]]'

# 7. A link folder that is itself a link (a folded stow dir): refused.
fresh; ln -s $LINKS $S/folded; BRAIN_LINKS_DIR=$S/folded bl
check "folded link folder refused" '(( rc != 0 )) && [[ ! -e $LINKS/alpha && ! -L $LINKS/alpha ]]' "rc=$rc $out"

# 8. A trailing slash on BRAIN_BIN still matches the links it made.
fresh; bl; BRAIN_BIN=$BIN/ bl
check "trailing slash keeps links" '[[ $(readlink $LINKS/alpha) == $BIN/alpha ]]'

# 9. A link elsewhere in the brain (vault-query's case): kept, info not warning.
fresh; mkdir -p $S/brain/tools; print '#!/bin/sh' >$S/brain/tools/alpha
ln -s $S/brain/tools/alpha $LINKS/alpha; bl
check "brain's own link kept, quiet" '(( rc == 0 )) && [[ $(readlink $LINKS/alpha) == $S/brain/tools/alpha && $out != *"$LINKS/alpha"* ]]' "rc=$rc $out"
check "foreign link outside the brain still warns" '[[ $out == *"[WARNING]"*"$LINKS/beta points at"* ]]' "$out"
check "regular file still warns" '[[ $out == *"[WARNING]"*"$LINKS/gamma is not a link"* ]]' "$out"
bl --dry-run
check "brain's own link noted at info on dry run" '[[ $out == *"[INFO]"*"$LINKS/alpha points at"*"brain'"'"'s own"* && $out != *"[WARNING]"*"$LINKS/alpha"* ]]' "$out"

# 10. Flags before sync, or with no command at all, reach sync.
fresh; bl --dry-run sync
check "--dry-run sync is a dry run" '(( rc == 0 )) && [[ $out == *"would create alpha"* && ! -L $LINKS/alpha ]]' "rc=$rc $out"
fresh; bl -v
check "-v alone runs sync verbosely" '(( rc == 0 )) && [[ $out == *"create  alpha"* && -L $LINKS/alpha ]]' "rc=$rc $out"

# 11. Unknown option: exit 2, nothing changed.
fresh; bl sync --bogus
check "unknown option exits 2" '(( rc == 2 )) && [[ ! -L $LINKS/alpha ]]' "rc=$rc $out"

print "\n$pass passed, $fail failed"
(( fail == 0 ))
