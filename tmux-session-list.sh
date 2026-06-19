#!/usr/bin/env bash
# Emit the picker's session list as  <name>\t<annotation>  lines, sorted so
# sessions waiting for your input come first. Used both for fzf's initial
# input and for its periodic reload. (Called by claude-tmux-picker.sh.)
{
    # <sortkey>\t<name>\t<annotation>; sortkey 0 = waiting, 1 = working, 9 = actions.
    # A running Claude turn shows "esc to interrupt"; its absence means the
    # agent is idle / waiting for you (★).
    while IFS=$'\t' read -r s att; do
        if tmux capture-pane -p -t "$s" 2>/dev/null | grep -q 'esc to interrupt'; then
            key=1; mark='· working…'
        else
            key=0; mark='★ waiting for you'
        fi
        [ -n "$att" ] && mark="$mark  $att"
        printf '%s\t%s\t%s\n' "$key" "$s" "$mark"
    done < <(tmux list-sessions \
                -F $'#{session_name}\t#{?session_attached,(attached),}' 2>/dev/null)
    printf '9\t__NEW__\t＋ create a NEW session\n'
    printf '9\t__SKIP__\t✗ skip (plain shell)\n'
} | sort -s -t$'\t' -k1,1n | cut -f2-
