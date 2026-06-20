#!/usr/bin/env bash
# Preview helper for claude-tmux-picker (called by fzf --preview).
# $1 is the first field of the selected line: a session name or a sentinel.
name="$1"

case "$name" in
    __NEW__)
        echo "＋ Create a NEW tmux session"
        echo
        echo "Runs:  ${CLAUDE_TMUX_NEW_CMD:-claude --dangerously-skip-permissions}"
        echo
        echo "You'll be asked for:"
        echo "  • a name       (default: ${CLAUDE_TMUX_DEFAULT:-main})"
        echo "  • a directory  (default: $HOME)"
        ;;
    __SKIP__)
        echo "✗ Skip tmux"
        echo
        echo "Drop straight to a plain login shell."
        ;;
    *)
        # Show the tail end of the session's active pane, anchored to the
        # bottom so the latest output/prompt is always visible. Keep the real
        # line layout (no blank-line squeezing) so it matches the live screen;
        # just trim trailing whitespace and any trailing blank lines, then show
        # the last screenful that fits the preview window.
        lines=${FZF_PREVIEW_LINES:-40}
        tmux capture-pane -p -t "$name" 2>/dev/null \
            | sed -e 's/[[:space:]]*$//' \
            | awk '{a[NR]=$0}
                   END{last=NR
                       while (last>0 && a[last] ~ /^[[:space:]]*$/) last--
                       for (i=1;i<=last;i++) print a[i]}' \
            | tail -n "$lines"
        ;;
esac
