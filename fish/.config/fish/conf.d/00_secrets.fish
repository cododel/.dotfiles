# Load secrets from .secrets.env file in the dotfiles root
set -l secrets_file "$HOME/.dotfiles/.secrets.env"

if test -f "$secrets_file"
    for line in (cat "$secrets_file" | grep -v "^#")
        set -l item (string split -m 1 "=" $line)
        if test (count $item) -eq 2
            set -l key (string trim -- $item[1])
            set -l value (string trim --chars='"' -- $item[2])
            set -gx $key $value
        end
    end
end
