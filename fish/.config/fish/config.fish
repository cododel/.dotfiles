if status is-interactive
    # Commands to run in interactive sessions can go here
    starship init fish | source
    enable_transience
end

#source ~/.docker/init-fish.sh || true # Added by Docker Desktop

# pnpm
set -gx PNPM_HOME "/Users/cododel/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end




# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

# Added by Antigravity
fish_add_path /Users/cododel/.antigravity/antigravity/bin

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f /Users/cododel/.miniconda3/bin/conda
    eval /Users/cododel/.miniconda3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/Users/cododel/.miniconda3/etc/fish/conf.d/conda.fish"
        . "/Users/cododel/.miniconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/Users/cododel/.miniconda3/bin" $PATH
    end
end
# <<< conda initialize <<<

