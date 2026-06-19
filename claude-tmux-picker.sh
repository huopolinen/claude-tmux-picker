#!/usr/bin/env bash
# claude-tmux-picker — interactive tmux session picker for Claude Code on a server.
#
# On SSH login it shows an fzf menu of your tmux sessions with a live preview
# of each session's tail, and flags which ones are waiting for your input.
# Pick one to attach, or create a fresh session that launches Claude Code.
#
# Install: add this line to your ~/.bashrc
#     source /path/to/claude-tmux-picker.sh
#
# Optional environment overrides (export before sourcing):
#     CLAUDE_TMUX_NEW_CMD   command a new session runs (default: claude --dangerously-skip-permissions)
#     CLAUDE_TMUX_DEFAULT   default name for a new session (default: main)
#     CLAUDE_TMUX_PREVIEW   path to the preview helper (default: alongside this script)

claude_tmux_picker() {
    command -v fzf  >/dev/null 2>&1 || return 0
    command -v tmux >/dev/null 2>&1 || return 0

    local new_cmd="${CLAUDE_TMUX_NEW_CMD:-claude --dangerously-skip-permissions}"
    local default_name="${CLAUDE_TMUX_DEFAULT:-main}"
    local here preview
    here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
    preview="${CLAUDE_TMUX_PREVIEW:-$here/tmux-session-preview.sh}"

    local sel name newname
    sel=$(
        {
            # For each session emit:  <sortkey>\t<name>\t<annotation>
            # sortkey 0 = waiting for you, 1 = working — so waiting floats to the top.
            # A turn in progress shows "esc to interrupt" in Claude's status line;
            # its absence means Claude is idle / waiting for your input (★).
            local s att key mark
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
            # Action entries pinned to the bottom (sortkey 9).
            printf '9\t__NEW__\t＋ create a NEW session\n'
            printf '9\t__SKIP__\t✗ skip (plain shell)\n'
        } \
            | sort -s -t$'\t' -k1,1n \
            | cut -f2- \
            | fzf \
                --delimiter='\t' --with-nth=1,2 \
                --reverse --height='100%' \
                --prompt='tmux > ' \
                --header='↑/↓ move · Enter choose · Esc skip · ★ = waiting for you' \
                --preview="'$preview' {1}" \
                --preview-window='right:55%:wrap'
    )

    name=${sel%%$'\t'*}
    case "$name" in
        ''|__SKIP__)
            : # plain shell, do nothing
            ;;
        __NEW__)
            read -r -p "New session name (default: $default_name): " newname
            newname="${newname:-$default_name}"
            if tmux has-session -t "$newname" 2>/dev/null; then
                tmux attach-session -t "$newname"
            else
                tmux new-session -s "$newname" "$new_cmd"
            fi
            ;;
        *)
            tmux attach-session -t "$name"
            ;;
    esac
}

# Run only for interactive SSH shells that aren't already inside tmux.
if [[ $- == *i* ]] && [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ]; then
    claude_tmux_picker
fi
