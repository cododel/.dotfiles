# Dotfiles

Набор конфигураций для `fish`, `neovim`, `git`, `htop`, `lf`, `zed`, `opencode` и вспомогательных скриптов. Символические ссылки раскладываются через `stow` (см. `sync.sh`). Секреты хранятся локально в `.secrets.env`, он игнорируется.

## Требования
- `stow` для развёртывания в `$HOME`.
- `fish` 3.x, `fisher`, `starship`.
- `neovim` ≥ 0.10 с поддержкой Lua; `git` и `curl` для `lazy.nvim`.
- `node`/`bun` и `pnpm` (используются в скриптах и в `fish/config.fish`).
- `gh` (если нужен конфиг `git/.config/gh`).

## Быстрый старт
1. Клонируй репозиторий, например: `git clone https://github.com/имярек/dotfiles ~/.dotfiles`.
2. Скопируй `secrets.example.env` в `~/.dotfiles/.secrets.env` и заполни значения.
3. Запусти из корня `./sync.sh` — он вызовет `stow */` и разложит симлинки по `$HOME`.
4. Перезапусти `fish` или открой новую сессию, затем запусти `nvim`, чтобы `lazy.nvim` подтянул плагины.

## Секреты
- `.secrets.env` не трекается (в `.gitignore`).
- `fish/conf.d/00_secrets.fish` читает этот файл и экспортирует пары `KEY=VALUE` в окружение.
- В репозитории остаётся только шаблон `secrets.example.env`.

## Структура
- `fish/.config/fish` — конфиг с `starship`, `enable_transience`, путём к `pnpm`, инициализацией OrbStack/Antigravity; в `conf.d` лежат алиасы, env и загрузка секретов. `fish_plugins` перечисляет плагины для `fisher`.
- `git/.gitconfig` — пользователь, `git-lfs`, `pull.rebase = false`.
- `git/.config/gh` — настройка `gh` (алиас `co`, протокол HTTPS, без токенов).
- `htop/.config/htop/htoprc`, `lf/.config/lf/lfrc` — базовые настройки.
- `nvim/.config/nvim` — `init.lua` тянет `config.lazy`, `config.settings`, `config.keymaps`. `lazy.lua` бутстрапит `lazy.nvim`. Плагины описаны в `lua/plugins` (`nvim-tree`, `bufferline`, `telescope`, `alpha`, `gitsigns`, `treesitter`, `autopairs`, LSP и др.). Настройки включают номера строк, табы 2 пробела (4 для Python), хоткеи для LSP/форматирования/буферов/файлового дерева.
- `opencode/.config/opencode` — агент `code-reviewer`, TUI, локальный MCP `context7` через `bunx`.
- `scripts/.scripts` — набор утилит; в `twitch/chat_ws` — Node-приложение (в `.gitignore` там `node_modules`).
- `zed/.config/zed` — `settings.json`, `keymap.json`; `prompts/**/*.mdb` игнорируются.
- `.gitignore` — исключает `.secrets.env` и `**/.DS_Store`; в `zed` и `twitch/chat_ws` есть локальные `.gitignore` для артефактов.
- `sync.sh` — однострочник `stow */`.

## Как обновлять и синхронизировать
- После изменений запускай `./sync.sh`, чтобы обновить симлинки.
- Можно разворачивать выборочно: `stow fish`, `stow nvim` и т.п. из корня.
- Обновление плагинов Neovim — просто запусти `nvim`, `lazy.nvim` сам проверит обновления (`checker.enabled = true`).

## Примечания
- Новые секреты добавляй только в `.secrets.env`.
- Для новых скриптов кладём файлы в `scripts/.scripts`; `stow` подхватит их при следующем запуске.
- Если используешь `gh`, убедись, что вход выполнен (`gh auth login`), так как в конфиге токенов нет.