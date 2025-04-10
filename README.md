<p align="center">
	***This plugin is not supported by Epic Games***
</p>
<br/><br/>
![image](https://github.com/user-attachments/assets/2c3a7441-e073-4d86-a99e-0bac0c4f283a)
(Theme: https://github.com/Luxed/ayu-vim)

## Features
- LSP (and text based) autocompletion.
- Diagnostic messages.
- Go to definition.
- Syntax highlighting.

## Dependencies
- Lsp-zero (https://github.com/VonHeikemen/lsp-zero.nvim) (autocompletion).
- Scorpeon (https://github.com/uga-rosa/scorpeon.vim) (syntax highlighting).
- Trouble (https://github.com/folke/trouble.nvim) (visualization of diagnostic messages).

## Instalation
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
            {
                'uga-rosa/scorpeon.vim',
                init = function()
                    vim.g.scorpeon_extensions_path = 'full/path/to/vscode/extensions/directory'
                end
            }, 
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
                lspPath = 'full/path/to/epics/verse/lsp/executable',
                verseProjectPath = 'full/path/to/saved/verseproject' -- e.g. C:/Users/username/AppData/Local/UnrealEditorFortnite/Saved/VerseProject/'
            })
        end
    }
}
```

Lsp-zero setup example (don't show mappings setup):

```
local cmp = require('cmp')
local cmp_action = require('lsp-zero').cmp_action()

cmp.setup({
	sources = {
		{name = 'nvim_lsp'},
		{name = 'buffer'} -- Text based auto completion is strongly recomended.
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
