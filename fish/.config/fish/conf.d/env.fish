export LC_ALL=en_US.UTF-8  
export LANG=en_US.UTF-8

export EDITOR=/opt/homebrew/bin/nvim
export REACT_EDITOR=cursor
export SCRIPTS=$HOME/.scripts
export GOPATH=$HOME/.go

export PATH="$SCRIPTS:$PATH"

export PATH="$HOME/Applications:$PATH"
export PATH="$HOME/.miniconda3/bin:$PATH"
export PATH="$HOME/.go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/python/libexec/bin:$PATH"
export PATH="/opt/homebrew/Cellar/libpq/15.1/bin:$PATH"
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export PATH="$HOME/.composer/vendor/bin:$PATH"
export PATH="./node_modules/.bin:$PATH"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/yandex-cloud/bin:$PATH"
export PATH="/opt/local/bin:$PATH"

export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

export GEM_HOME="$HOME/.gem"
export PATH="$GEM_HOME/bin:$PATH"
export GOOGLE_CLOUD_PROJECT="gen-lang-client-0503296622"

#source ~/.docker/init-zsh.sh || true # Added by Docker Desktop
eval "$(/opt/homebrew/bin/brew shellenv)"
