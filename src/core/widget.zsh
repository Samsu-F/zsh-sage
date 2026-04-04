#
# Widget — ZLE integration for inline suggestions
#
# This is the user-facing layer. It hooks into Zsh Line Editor
# to show ghost text (POSTDISPLAY) as the user types.
#

typeset -g _SAGE_CURRENT_SUGGESTION=""
typeset -g _SAGE_AI_PID=0
typeset -g _SAGE_AI_TMPFILE="/tmp/zsh-sage-ai-$$"

# ── Main suggestion widget ───────────────────────────────────────
# Called on every keystroke via ZLE
_sage_suggest_widget() {
    emulate -L zsh

    # Run the original widget first (so the character actually gets typed)
    zle .self-insert

    _sage_update_suggestion
}

# ── Update the suggestion based on current buffer ────────────────
_sage_update_suggestion() {
    local prefix="$BUFFER"

    # Clear suggestion if buffer is empty
    if [[ -z "$prefix" ]]; then
        POSTDISPLAY=""
        _SAGE_CURRENT_SUGGESTION=""
        return
    fi

    # Get best suggestion from local scoring
    local suggestion
    suggestion=$(_sage_rank_candidates "$prefix" "$PWD" "$_SAGE_PREV_COMMAND")

    if [[ -n "$suggestion" && "$suggestion" != "$prefix" && "$suggestion" == "$prefix"* ]]; then
        # Show the part after what's already typed as ghost text
        _SAGE_CURRENT_SUGGESTION="$suggestion"
        POSTDISPLAY="${suggestion#$prefix}"
    else
        POSTDISPLAY=""
        _SAGE_CURRENT_SUGGESTION=""

        # If AI is enabled and no local match, trigger async AI suggestion
        if [[ "$ZSH_SAGE_AI_ENABLED" == "true" && -n "$ZSH_SAGE_API_KEY" ]]; then
            _sage_ai_suggest_async "$prefix"
        fi
    fi
}

# ── Accept suggestion (right arrow / end of line) ────────────────
_sage_accept_widget() {
    emulate -L zsh

    if [[ -n "$_SAGE_CURRENT_SUGGESTION" ]]; then
        BUFFER="$_SAGE_CURRENT_SUGGESTION"
        CURSOR=${#BUFFER}
        POSTDISPLAY=""
        _SAGE_CURRENT_SUGGESTION=""
    else
        # Fall through to default behavior
        zle .forward-char
    fi
}

# ── Accept partial suggestion (word by word with Ctrl+Right) ─────
_sage_accept_word_widget() {
    emulate -L zsh

    if [[ -n "$POSTDISPLAY" ]]; then
        # Get the next word from the suggestion
        local remaining="$POSTDISPLAY"
        local next_word="${remaining%% *}"

        # If no space found, take the whole thing
        if [[ "$next_word" == "$remaining" ]]; then
            BUFFER="$_SAGE_CURRENT_SUGGESTION"
            CURSOR=${#BUFFER}
            POSTDISPLAY=""
            _SAGE_CURRENT_SUGGESTION=""
        else
            BUFFER="${BUFFER}${next_word} "
            CURSOR=${#BUFFER}
            POSTDISPLAY="${remaining#$next_word }"
        fi
    else
        zle .forward-word
    fi
}

# ── Dismiss suggestion (Escape) ─────────────────────────────────
_sage_dismiss_widget() {
    emulate -L zsh
    POSTDISPLAY=""
    _SAGE_CURRENT_SUGGESTION=""
}

# ── Check for async AI result on each prompt redraw ──────────────
_sage_check_ai_result() {
    if [[ -f "$_SAGE_AI_TMPFILE" ]]; then
        local ai_suggestion
        ai_suggestion=$(<"$_SAGE_AI_TMPFILE")
        rm -f "$_SAGE_AI_TMPFILE"

        if [[ -n "$ai_suggestion" && "$ai_suggestion" == "$BUFFER"* && -z "$POSTDISPLAY" ]]; then
            _SAGE_CURRENT_SUGGESTION="$ai_suggestion"
            POSTDISPLAY="${ai_suggestion#$BUFFER}"
            zle -R  # Force redraw
        fi
    fi
}

# ── Register all widgets and keybindings ─────────────────────────
_sage_widget_init() {
    # Create named widgets
    zle -N sage-suggest _sage_suggest_widget
    zle -N sage-accept _sage_accept_widget
    zle -N sage-accept-word _sage_accept_word_widget
    zle -N sage-dismiss _sage_dismiss_widget

    # Override self-insert — this is how zsh-autosuggestions does it.
    # self-insert is called for every printable character, so overriding
    # it catches all typing without touching control keys (Enter, Tab, etc.)
    zle -N self-insert _sage_suggest_widget

    # Accept full suggestion: right arrow
    bindkey '^[[C' sage-accept      # Right arrow
    bindkey '^[OC' sage-accept      # Right arrow (alternate)

    # Accept word: Ctrl+Right
    bindkey '^[[1;5C' sage-accept-word  # Ctrl+Right

    # Backspace should clear and re-suggest
    zle -N sage-backspace _sage_backspace_widget
    bindkey '^?' sage-backspace     # Backspace
    bindkey '^H' sage-backspace     # Ctrl+H
}

# ── Backspace handler ────────────────────────────────────────────
_sage_backspace_widget() {
    emulate -L zsh
    zle .backward-delete-char
    _sage_update_suggestion
}
