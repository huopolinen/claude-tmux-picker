#!/usr/bin/env bash
# Kill a tmux session after confirmation. Called by claude-tmux-picker.sh via
# fzf's `execute` binding. $1 is the session name from the highlighted line;
# the action sentinels are ignored.
#
# fzf may wire the command's stdin/stdout to pipes, which would (a) hide a
# buffered prompt and (b) break a normal `read`. So we talk to the controlling
# terminal directly via /dev/tty, and read a single keypress (no Enter needed).
name="$1"

case "$name" in
    __NEW__|__SKIP__|'')
        exit 0
        ;;
esac

if [ -e /dev/tty ]; then
    printf 'Kill session "%s"? [y/N] ' "$name" > /dev/tty
    read -rsn1 ans < /dev/tty
    printf '%s\n' "$ans" > /dev/tty
    out=/dev/tty
else
    # Fallback for non-interactive contexts (e.g. tests): line-based on stdin.
    printf 'Kill session "%s"? [y/N] ' "$name"
    read -r ans
    out=/dev/stdout
fi

case "$ans" in
    y|Y)
        if tmux kill-session -t "$name" 2>/dev/null; then
            printf 'killed: %s\n' "$name" > "$out"
        else
            printf 'could not kill: %s\n' "$name" > "$out"
        fi
        ;;
    *)
        printf 'cancelled.\n' > "$out"
        ;;
esac
