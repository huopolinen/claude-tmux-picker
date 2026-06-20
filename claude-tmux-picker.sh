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
    local refresh="${CLAUDE_TMUX_REFRESH:-2}"   # seconds between live refreshes
    local here preview list
    here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
    preview="${CLAUDE_TMUX_PREVIEW:-$here/tmux-session-preview.sh}"
    list="${CLAUDE_TMUX_LIST:-$here/tmux-session-list.sh}"

    # The list and previews refresh themselves every $refresh seconds: fzf's
    # `load` event fires after each reload, so binding it to a delayed reload
    # makes a self-perpetuating timer. --track keeps the cursor in place.
    local sel name newname
    sel=$(
        "$list" | fzf \
            --delimiter='\t' --with-nth=1,2 \
            --reverse --height='100%' --no-sort --track \
            --prompt='tmux > ' \
            --header="↑/↓ move · Enter choose · Esc skip · ★ waiting · live (${refresh}s)" \
            --preview="'$preview' {1}" \
            --preview-window='right:55%:wrap' \
            --bind="load:reload(sleep $refresh; '$list')+refresh-preview"
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
                local newdir
                read -r -e -p "Start directory (default: $HOME): " newdir
                newdir="${newdir:-$HOME}"
                newdir="${newdir/#\~/$HOME}"   # expand a leading ~
                if [ ! -d "$newdir" ]; then
                    echo "No such directory: $newdir — using $HOME instead." >&2
                    newdir="$HOME"
                fi
                tmux new-session -s "$newname" -c "$newdir" "$new_cmd"
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
