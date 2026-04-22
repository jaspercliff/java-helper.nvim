local SnacksExplorer = require("java-helper.snacks")

local M = {}

---@return string dir 用于放置新文件的目录（绝对路径）
function M.default_target_dir()
	local dir = SnacksExplorer.focused_explorer_dir()
	if dir then
		return dir
	end

	-- 如果上次在 snacks explorer 里选中过目录/文件，
	-- 就算当前焦点不在 explorer，也优先使用该目录
	dir = SnacksExplorer.last_dir()
	if dir then
		return dir
	end

	local buf = vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(buf)
	if name ~= "" then
		return vim.fn.fnamemodify(name, ":p:h")
	end
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
end

return M
