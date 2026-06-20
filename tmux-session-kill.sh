#!/usr/bin/env bash
# Kill a tmux session after confirmation. Called by claude-tmux-picker.sh via
# fzf's `execute` binding (so it runs on the real terminal). $1 is the session
# name from the highlighted line; the action sentinels are ignored.
name="$1"

case "$name" in
    __NEW__|__SKIP__|'')
        exit 0
        ;;
esac

printf 'Kill session "%s"? [y/N] ' "$name"
read -r ans
case "$ans" in
    y|Y|yes|YES)
        if tmux kill-session -t "$name" 2>/dev/null; then
            echo "killed: $name"
        else
            echo "could not kill: $name"
        fi
        ;;
    *)
        echo "cancelled."
        ;;
esac
