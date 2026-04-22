local M = {}

local last_dir ---@type string|nil

---@param dir string|nil
function M.set_last_dir(dir)
	if type(dir) == "string" and dir ~= "" then
		last_dir = vim.fn.fnamemodify(dir, ":p")
	end
end

---@return string|nil
function M.last_dir()
	return last_dir
end

---@param item? {file?: string, dir?: boolean}
---@return string|nil dir 绝对路径
function M.dir_from_item(item)
	if not item or type(item) ~= "table" then
		return nil
	end
	local file = item.file
	if type(file) ~= "string" or file == "" then
		return nil
	end
	local dir = (item.dir and file) or vim.fs.dirname(file)
	return vim.fn.fnamemodify(dir, ":p")
end

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
			local dir = M.dir_from_item(item)
			if dir then
				M.set_last_dir(dir)
				return dir
			end
			if type(picker.dir) == "function" then
				local dir = picker:dir()
				if type(dir) == "string" and dir ~= "" then
					dir = vim.fn.fnamemodify(dir, ":p")
					M.set_last_dir(dir)
					return dir
				end
			end
		end
	end

	return nil
end

return M
