# bash-Vervollständigung für shell-set: Befehle, Schlüssel und Werte kommen aus dem Schema
# (shell-set __complete …). Wird von install.sh nach
# ~/.local/share/bash-completion/completions/shell-set kopiert.
_shell_set() {
    local cur="${COMP_WORDS[COMP_CWORD]}" first="${COMP_WORDS[1]:-}" w
    local befehle="list get reset undo redo history profile export import monitor"
    COMPREPLY=()
    if [ "$COMP_CWORD" -eq 1 ]; then
        w="$befehle $(shell-set __complete keys 2>/dev/null)"
    elif [ "$COMP_CWORD" -eq 2 ]; then
        case "$first" in
            list) w="$(shell-set __complete areas 2>/dev/null)" ;;
            get) w="$(shell-set __complete keys 2>/dev/null)" ;;
            reset) w="all $(shell-set __complete areas 2>/dev/null) $(shell-set __complete keys 2>/dev/null)" ;;
            profile) w="save load list delete" ;;
            monitor) w="$(shell-set __complete monitors 2>/dev/null)" ;;
            export|import) mapfile -t COMPREPLY < <(compgen -f -- "$cur"); return 0 ;;
            undo|redo|history) return 0 ;;
            *) w="$(shell-set __complete values "$first" 2>/dev/null)" ;;
        esac
    elif [ "$COMP_CWORD" -eq 3 ] && [ "$first" = profile ]; then
        case "${COMP_WORDS[2]}" in load|delete) w="$(shell-set __complete profiles 2>/dev/null)" ;; *) return 0 ;; esac
    elif [ "$COMP_CWORD" -eq 3 ] && [ "$first" = monitor ]; then
        w="rotate mirror transform"
    elif [ "$COMP_CWORD" -eq 4 ] && [ "$first" = monitor ]; then
        case "${COMP_WORDS[3]}" in
            rotate) w="0 90 180 270" ;;
            mirror) w="on off" ;;
            transform) w="normal 90 180 270 flipped flipped-90 flipped-180 flipped-270" ;;
            *) return 0 ;;
        esac
    else
        return 0
    fi
    mapfile -t COMPREPLY < <(compgen -W "$w" -- "$cur")
}
complete -F _shell_set shell-set
