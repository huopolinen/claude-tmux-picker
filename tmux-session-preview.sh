#!/usr/bin/env bash
# Preview helper for claude-tmux-picker (called by fzf --preview).
# $1 is the first field of the selected line: a session name or a sentinel.
name="$1"

case "$name" in
    __NEW__)
        echo "＋ Create a NEW tmux session"
        echo
        echo "Runs:  ${CLAUDE_TMUX_NEW_CMD:-claude --dangerously-skip-permissions}"
        echo "In:    $HOME"
        echo
        echo "(you'll be asked for a name; default: ${CLAUDE_TMUX_DEFAULT:-main})"
        ;;
    __SKIP__)
        echo "✗ Skip tmux"
        echo
        echo "Drop straight to a plain login shell."
        ;;
    *)
        # Show the tail end of the session's active pane.
        tmux capture-pane -p -t "$name" 2>/dev/null \
            | sed -e 's/[[:space:]]*$//' \
            | cat -s
        ;;
esac
