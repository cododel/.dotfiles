#!/bin/bash
shopt -s extglob

stow !(_shared)/

mkdir -p "$HOME/.config/opencode" "$HOME/.gemini"
ln -sf "$HOME/.dotfiles/_shared/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
ln -sf "$HOME/.dotfiles/_shared/AGENTS.md" "$HOME/.gemini/AGENTS.md"
