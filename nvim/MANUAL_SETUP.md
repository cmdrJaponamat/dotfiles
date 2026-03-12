# Neovim Manual Setup Guide

Этот файл объясняет, где в текущем конфиге что настраивается вручную.

## 1. Главная точка входа

- `~/.config/nvim/init.lua`
- Что делает:
- Инициализирует `lazy.nvim`
- Подключает базовые модули `core/*`
- Подключает список плагинов `lua/plugins.lua`

## 2. Базовые настройки

- `~/.config/nvim/lua/core/options.lua`
- Здесь менять:
- табы/пробелы
- номера строк
- поведение поиска
- визуальные опции редактора

## 3. Все хоткеи

- `~/.config/nvim/lua/core/keymaps.lua`
- Здесь менять:
- глобальные горячие клавиши
- бинды под плагины (`Telescope`, `Neo-tree`, `Trouble`, форматирование)

Шпаргалка по текущим клавишам:
- `~/.config/nvim/KEYMAPS.md`

## 4. Автокоманды

- `~/.config/nvim/lua/core/autocmds.lua`
- Здесь менять:
- что делать при старте `nvim`
- что делать при открытии/сохранении файла
- filetype-specific поведение

## 5. Подключение плагинов

- `~/.config/nvim/lua/plugins.lua`
- Здесь менять:
- какие плагины установлены
- условия lazy-load (`event`, `cmd`, `ft`, `keys`)
- зависимости и вызов конфигов

Правило:
- если добавляете плагин, добавляйте и отдельный config-файл в `lua/plugins/configs/`.

## 6. Конфиги плагинов (где что править)

- `lua/plugins/configs/lsp.lua`: LSP, Mason, серверы (`clangd`, `pyright`, `lua_ls`)
- `lua/plugins/configs/conform.lua`: форматтеры по filetype
- `lua/plugins/configs/lint.lua`: линтеры по filetype
- `lua/plugins/configs/trouble.lua`: UI для diagnostics/quickfix
- `lua/plugins/configs/treesitter.lua`: treesitter запуск и поведение
- `lua/plugins/configs/neo-tree.lua`: файловое дерево
- `lua/plugins/configs/cmp.lua`: автодополнение
- `lua/plugins/configs/telescope.lua`: поиск
- `lua/plugins/configs/gitsigns.lua`: git-метки/обвинение строки
- `lua/plugins/configs/toggleterm.lua`: встроенный терминал

## 7. Что ставить через Mason для C++/Python

Открыть `:Mason` и установить:
- `clangd`
- `pyright`
- `lua-language-server`
- `clang-format`
- `clang-tidy`
- `ruff`
- `black`
- `isort`

CLI-вариант:
```vim
:MasonInstall clangd pyright lua-language-server clang-format clang-tidy ruff black isort
```

## 8. Проверка после изменений

После правок:
1. `:Lazy sync`
2. Перезапустить `nvim`
3. `:checkhealth`
4. `:LspInfo` в `*.cpp` и `*.py` файлах

Полезно:
- `:messages` чтобы увидеть последние ошибки конфигурации

## 9. Минимальный workflow ручной настройки нового плагина

1. Добавить плагин в `lua/plugins.lua`
2. Создать `lua/plugins/configs/<name>.lua`
3. Подключить config через `config = function() require("plugins.configs.<name>") end`
4. Добавить хоткеи в `lua/core/keymaps.lua` (если нужны)
5. `:Lazy sync`
6. Проверить `:messages` и `:checkhealth`
