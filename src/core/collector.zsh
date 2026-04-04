#
# Collector — hooks into shell lifecycle to record commands
#

typeset -g _SAGE_LAST_COMMAND=""
typeset -g _SAGE_PREV_COMMAND=""
typeset -g _SAGE_COMMAND_START=0

# Called before a command executes
_sage_collector_preexec() {
    _SAGE_LAST_COMMAND="$1"
    _SAGE_COMMAND_START=$(date +%s)
}

# Called after a command completes (before next prompt)
_sage_collector_precmd() {
    local exit_code=$?

    # Nothing to record on first prompt
    [[ -z "$_SAGE_LAST_COMMAND" ]] && return

    # Skip recording very short/trivial commands
    [[ ${#_SAGE_LAST_COMMAND} -lt 2 ]] && return

    # Skip commands that start with space (private commands)
    [[ "$_SAGE_LAST_COMMAND" == " "* ]] && return

    local timestamp=$(date +%s)
    local dir="$PWD"
    local git_branch=""

    # Get git branch if in a repo
    if command git rev-parse --is-inside-work-tree &>/dev/null; then
        git_branch=$(command git symbolic-ref --short HEAD 2>/dev/null || echo "")
    fi

    # Record asynchronously to not block the prompt
    {
        _sage_db_record \
            "$_SAGE_LAST_COMMAND" \
            "$dir" \
            "$_SAGE_PREV_COMMAND" \
            "$exit_code" \
            "$timestamp" \
            "$git_branch"
    } &!

    # Shift command history
    _SAGE_PREV_COMMAND="$_SAGE_LAST_COMMAND"
    _SAGE_LAST_COMMAND=""
}
