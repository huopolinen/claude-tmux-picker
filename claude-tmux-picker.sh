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
#     CLAUDE_TMUX_START_DIR directory a new session starts in; when set, the
#                           picker no longer asks for a directory (unset: asks,
#                           default $HOME)
#     CLAUDE_TMUX_NO_PROMPT set to 1 to also skip the name question: new sessions
#                           get CLAUDE_TMUX_DEFAULT (a taken name gets -2, -3, …)
#     CLAUDE_TMUX_AUTO_NEW  set to 1 to skip the menu when there are no sessions
#                           yet and go straight to creating one
#     CLAUDE_TMUX_PREVIEW   path to the preview helper (default: alongside this script)

claude_tmux_picker() {
    command -v fzf  >/dev/null 2>&1 || return 0
    command -v tmux >/dev/null 2>&1 || return 0

    local new_cmd="${CLAUDE_TMUX_NEW_CMD:-claude --dangerously-skip-permissions}"
    local default_name="${CLAUDE_TMUX_DEFAULT:-main}"
    local start_dir="${CLAUDE_TMUX_START_DIR:-}"
    local no_prompt="${CLAUDE_TMUX_NO_PROMPT:-0}"
    local auto_new="${CLAUDE_TMUX_AUTO_NEW:-0}"
    local refresh="${CLAUDE_TMUX_REFRESH:-2}"   # seconds between live refreshes
    local here preview list kill
    here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
    preview="${CLAUDE_TMUX_PREVIEW:-$here/tmux-session-preview.sh}"
    list="${CLAUDE_TMUX_LIST:-$here/tmux-session-list.sh}"
    kill="${CLAUDE_TMUX_KILL:-$here/tmux-session-kill.sh}"

    # The list and previews refresh themselves every $refresh seconds: fzf's
    # `load` event fires after each reload, so binding it to a delayed reload
    # makes a self-perpetuating timer. --track keeps the cursor in place.
    local sel name newname
    if [ "$auto_new" = 1 ] && ! tmux list-sessions >/dev/null 2>&1; then
        sel=__NEW__   # nothing to pick from: go straight to a new session
    else
    sel=$(
        "$list" | fzf \
            --delimiter='\t' --with-nth=1,2 \
            --reverse --height='100%' --no-sort --track \
            --prompt='tmux > ' \
            --header="↑/↓ move · Enter choose · ⌫ kill · Esc skip · ★ waiting · live (${refresh}s)" \
            --preview="'$preview' {1}" \
            --preview-window='right:55%' \
            --bind="load:reload(sleep $refresh; '$list')+refresh-preview" \
            --bind="bspace:execute('$kill' {1})+reload('$list')"
    )
    fi

    name=${sel%%$'\t'*}
    case "$name" in
        ''|__SKIP__)
            : # plain shell, do nothing
            ;;
        __NEW__)
            local newdir
            if [ "$no_prompt" = 1 ]; then
                # No name question: default name, or name-2, name-3, … if taken.
                newname=$default_name
                local n=2
                while tmux has-session -t "$newname" 2>/dev/null; do
                    newname="$default_name-$n"; n=$((n + 1))
                done
            else
                read -r -p "New session name (default: $default_name): " newname
                newname="${newname:-$default_name}"
                if tmux has-session -t "$newname" 2>/dev/null; then
                    tmux attach-session -t "$newname"
                    return
                fi
            fi
            if [ -n "$start_dir" ]; then
                newdir=$start_dir   # fixed start directory: no question
            else
                read -r -e -p "Start directory (default: $HOME): " newdir
                newdir="${newdir:-$HOME}"
            fi
            newdir="${newdir/#\~/$HOME}"   # expand a leading ~
            if [ ! -d "$newdir" ]; then
                echo "No such directory: $newdir — using $HOME instead." >&2
                newdir="$HOME"
            fi
            tmux new-session -s "$newname" -c "$newdir" "$new_cmd"
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
