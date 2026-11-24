# fish-Vervollständigung für shell-set: Befehle, Schlüssel (mit Erklärung) und Werte kommen aus dem
# Schema (shell-set __complete …). Wird von install.sh nach ~/.config/fish/completions/ kopiert.
function __shell_set_n
    test (count (commandline -opc)) -eq $argv[1]
end
function __shell_set_erstes
    set -l t (commandline -opc)
    contains -- "$t[2]" $argv
end
set -l befehle list get reset undo redo history profile export import monitor
complete -c shell-set -f
complete -c shell-set -n '__shell_set_n 1' -a "$befehle"
complete -c shell-set -n '__shell_set_n 1' -a '(shell-set __complete describe)'
complete -c shell-set -n '__shell_set_n 2; and __shell_set_erstes list' -a '(shell-set __complete areas)'
complete -c shell-set -n '__shell_set_n 2; and __shell_set_erstes get' -a '(shell-set __complete describe)'
complete -c shell-set -n '__shell_set_n 2; and __shell_set_erstes reset' -a 'all (shell-set __complete areas) (shell-set __complete keys)'
complete -c shell-set -n '__shell_set_n 2; and __shell_set_erstes profile' -a 'save load list delete'
complete -c shell-set -n '__shell_set_n 3; and __shell_set_erstes profile' -a '(shell-set __complete profiles)'
complete -c shell-set -n '__shell_set_n 2; and __shell_set_erstes export import' -F
# Bildschirm drehen: shell-set monitor <name> rotate|mirror|transform <wert>
complete -c shell-set -n '__shell_set_n 2; and __shell_set_erstes monitor' -a '(shell-set __complete monitors)'
complete -c shell-set -n '__shell_set_n 3; and __shell_set_erstes monitor' -a 'rotate mirror transform'
complete -c shell-set -n '__shell_set_n 4; and __shell_set_erstes monitor; and contains -- (commandline -opc)[4] rotate' -a '0 90 180 270'
complete -c shell-set -n '__shell_set_n 4; and __shell_set_erstes monitor; and contains -- (commandline -opc)[4] mirror' -a 'on off'
complete -c shell-set -n '__shell_set_n 4; and __shell_set_erstes monitor; and contains -- (commandline -opc)[4] transform' -a 'normal 90 180 270 flipped flipped-90 flipped-180 flipped-270'
complete -c shell-set -n "__shell_set_n 2; and not __shell_set_erstes $befehle" -a '(shell-set __complete values (commandline -opc)[2])'
