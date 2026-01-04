set -gx LC_ALL en_US.UTF-8
set -gx LANG en_US.UTF-8

set -gx EDITOR /opt/homebrew/bin/nvim
set -gx REACT_EDITOR cursor
set -gx SCRIPTS $HOME/.scripts
set -gx GOPATH $HOME/.go

# Path configuration
fish_add_path $SCRIPTS
fish_add_path $HOME/Applications
fish_add_path $HOME/.miniconda3/bin
fish_add_path $HOME/.go/bin
fish_add_path $HOME/.local/bin
fish_add_path --append /opt/homebrew/opt/python/libexec/bin
fish_add_path /opt/homebrew/Cellar/libpq/15.1/bin
fish_add_path /opt/homebrew/opt/libpq/bin
fish_add_path $HOME/.composer/vendor/bin
fish_add_path ./node_modules/.bin

set -gx BUN_INSTALL $HOME/.bun
fish_add_path $BUN_INSTALL/bin
fish_add_path $HOME/yandex-cloud/bin
fish_add_path /opt/local/bin

set -gx DOCKER_BUILDKIT 1
set -gx COMPOSE_DOCKER_CLI_BUILD 1

set -gx GEM_HOME $HOME/.gem
fish_add_path $GEM_HOME/bin
set -gx GOOGLE_CLOUD_PROJECT "gen-lang-client-0503296622"

# Homebrew environment
if test -f /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
end
