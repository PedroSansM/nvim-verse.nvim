<p align="center">
	This plugin is not supported by Epic Games
</p>

## Showcase
<img width="584" height="886" alt="image" src="https://github.com/user-attachments/assets/1f2be6a3-a702-4b5f-a63a-11c8bcea7f58" />
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/0aac8959-130d-42f9-b83a-bf61953accdf" />


## Features
- LSP (and text based) autocompletion.
- Diagnostic messages.
- Go to definition.
- Syntax highlighting with Tree-sitter.

## Dependencies
- Lsp-zero (https://github.com/VonHeikemen/lsp-zero.nvim) (autocompletion).
- Trouble (https://github.com/folke/trouble.nvim) (visualization of diagnostic messages).

## Installation
With lasy (remove dependencies if already added elsewhere):

```
{
    {
        'PedroSansM/nvim-verse.nvim',
        dependencies = {
            {'VonHeikemen/lsp-zero.nvim', branch = 'v3.x'},
            {'neovim/nvim-lspconfig'},
            {'hrsh7th/cmp-nvim-lsp'},
            {'hrsh7th/nvim-cmp'},
            {'L3MON4D3/LuaSnip'},
            {'hrsh7th/cmp-buffer'},
            {'vim-denops/denops.vim'},
            {
               'folke/trouble.nvim',
                cmd = 'Trouble',
                keys = {
                    {
                      "<leader>xx",
                      "<cmd>Trouble diagnostics toggle<cr>",
                      desc = "Diagnostics (Trouble)",
                    },
                    {
                      "<leader>xX",
                      "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
                      desc = "Buffer Diagnostics (Trouble)",
                    },
                    {
                      "<leader>cs",
                      "<cmd>Trouble symbols toggle focus=false<cr>",
                      desc = "Symbols (Trouble)",
                    },
                    {
                      "<leader>cl",
                      "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
                      desc = "LSP Definitions / references / ... (Trouble)",
                    },
                    {
                      "<leader>xL",
                      "<cmd>Trouble loclist toggle<cr>",
                      desc = "Location List (Trouble)",
                    },
                    {
                      "<leader>xQ",
                      "<cmd>Trouble qflist toggle<cr>",
                      desc = "Quickfix List (Trouble)",
                    },
                }
            }
        },
        config = function()
            require('nvim_verse').setup({
                lspPath = 'full/path/to/epics/verse/lsp/executable', -- e.g. 'C:/Users/username/.vscode/entensions/epicgames.verse-<version>/bin/Win64/verse-lsp'
                verseProjectPath = 'full/path/to/saved/verseproject' -- e.g. 'C:/Users/username/AppData/Local/UnrealEditorFortnite/Saved/VerseProject'
            })
        end
    }
}
```

Lsp-zero setup example (doesn't show mappings setup):

```
local cmp = require('cmp')
local cmp_action = require('lsp-zero').cmp_action()

cmp.setup({
	sources = {
		{name = 'nvim_lsp'},
		{name = 'buffer'} -- Text based autocompletion is strongly recommended
	},
	preselect = 'item',
	completion = {
		completeopt = 'menu,menuone,noinsert'
	},
	mapping = cmp.mapping.preset.insert({
		['<TAB>'] = cmp.mapping.confirm({select = false}),
  })
})
```
## Tree-sitter
<p align="center">
	MADE WITH AI!
</p>
