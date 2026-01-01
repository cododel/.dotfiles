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
