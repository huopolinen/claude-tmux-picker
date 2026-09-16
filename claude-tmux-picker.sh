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
#     CLAUDE_TMUX_START_DIR directory a new session starts in (default: $HOME)
#     CLAUDE_TMUX_NO_PROMPT set to 1 to create new sessions without asking for a
#                           name or directory (uses the two defaults above; a taken
#                           name gets -2, -3, …); with no sessions at all the menu
#                           is skipped and a session is created right away
#     CLAUDE_TMUX_PREVIEW   path to the preview helper (default: alongside this script)

claude_tmux_picker() {
    command -v fzf  >/dev/null 2>&1 || return 0
    command -v tmux >/dev/null 2>&1 || return 0

    local new_cmd="${CLAUDE_TMUX_NEW_CMD:-claude --dangerously-skip-permissions}"
    local default_name="${CLAUDE_TMUX_DEFAULT:-main}"
    local start_dir="${CLAUDE_TMUX_START_DIR:-$HOME}"
    local no_prompt="${CLAUDE_TMUX_NO_PROMPT:-0}"
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
    if [ "$no_prompt" = 1 ] && ! tmux list-sessions >/dev/null 2>&1; then
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
                # No questions: default name (or name-2, name-3, … if taken) in the start directory.
                newname=$default_name
                local n=2
                while tmux has-session -t "$newname" 2>/dev/null; do
                    newname="$default_name-$n"; n=$((n + 1))
                done
                newdir=$start_dir
            else
                read -r -p "New session name (default: $default_name): " newname
                newname="${newname:-$default_name}"
                if tmux has-session -t "$newname" 2>/dev/null; then
                    tmux attach-session -t "$newname"
                    return
                fi
                read -r -e -p "Start directory (default: $start_dir): " newdir
                newdir="${newdir:-$start_dir}"
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
