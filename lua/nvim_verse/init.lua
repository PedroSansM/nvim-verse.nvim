local M = {}

M.setup = function(opts)
    M._lspPath = opts.lspPath
    M._verseProjectPath = opts.VerseProjectPath
end

function StartVerseLSP()
    local projectPath = vim.fn.getcwd()
    local projectName = vim.fs.basename(vim.fs.dirname(projectPath))
    local clientId = vim.lsp.start({
		name = 'verse-lsp',
		cmd = {NVimVerse._lspPath},
		workspace_folders = {
			{uri = vim.uri_from_fname(M._verseProjectPath..projectName..'/Fortnite'), name = 'Fortnite'},
			{uri = vim.uri_from_fname(M._verseProjectPath..projectName..'/UnrealEngine'), name = 'UnrealEngine'},
			{uri = vim.uri_from_fname(M._verseProjectPath..projectName..'/Verse'), name = 'Verse'},
			{uri = vim.uri_from_fname(M._verseProjectPath..projectName..'/'..projectName..'-Assets'), name = projectName..'/Assets'},
			{uri = vim.uri_from_fname(M._verseProjectPath..projectName..'/vproject'), name = 'vproject'},
			{uri = vim.uri_from_fname(projectPath), name = 'PROJECT'}
		}
	})
	if clientId ~= nil then
		vim.lsp.buf_attach_client(0, clientId)
	end
end

vim.api.nvim_create_autocmd('LspAttach', {
	callback = function(args)
		vim.keymap.set('n', '<F12>', vim.lsp.buf.definition, {buffer = args.buf})
		vim.keymap.set('n', 'gh', vim.lsp.buf.hover, {buffer = args.buf})
		vim.keymap.set({'n', 'i'}, '<C-.>', vim.lsp.buf.code_action, {buffer = args.buf})
	end
})

vim.api.nvim_create_autocmd('BufEnter', {
    pattern = {'*.verse'},
	callback = function(args)
        StartVerseLSP()
        vim.cmd[[ScorpeonHighlightEnable]]
	end
})

return M
