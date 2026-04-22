local M = {}

---@return string|nil dir 绝对路径
function M.focused_explorer_dir()
	if not (_G.Snacks and Snacks.picker and type(Snacks.picker.get) == "function") then
		return nil
	end

	local ok, pickers = pcall(Snacks.picker.get, { source = "explorer", tab = true })
	if not ok or type(pickers) ~= "table" then
		return nil
	end

	for _, picker in ipairs(pickers) do
		if picker and type(picker.is_focused) == "function" and picker:is_focused() then
			local item = type(picker.current) == "function" and picker:current() or nil
			local file = item and item.file or nil
			if type(file) == "string" and file ~= "" then
				local dir = (item.dir and file) or vim.fs.dirname(file)
				return vim.fn.fnamemodify(dir, ":p")
			end
			if type(picker.dir) == "function" then
				local dir = picker:dir()
				if type(dir) == "string" and dir ~= "" then
					return vim.fn.fnamemodify(dir, ":p")
				end
			end
		end
	end

	return nil
end

return M
