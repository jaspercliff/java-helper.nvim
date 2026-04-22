local M = {}

---从目录向上查找 Maven/Gradle 风格的 java 源码根目录。
---@param start_dir string
---@return string|nil java_root 绝对路径，末尾无 /
function M.find_java_source_root(start_dir)
	local ancestor = vim.fn.fnamemodify(start_dir, ":p"):gsub("/$", "")
	while ancestor ~= "" and ancestor ~= "/" do
		for _, marker in ipairs({ "src/main/java", "src/test/java" }) do
			local root = vim.fn.fnamemodify(ancestor .. "/" .. marker, ":p"):gsub("/$", "")
			if vim.fn.isdirectory(root) == 1 then
				return root
			end
		end
		local parent = vim.fn.fnamemodify(ancestor, ":h")
		if parent == ancestor then
			break
		end
		ancestor = parent
	end
	return nil
end

---@param java_root string
---@param file_dir string
---@return string package 点分形式，可能为空字符串（默认包）
function M.infer_package(java_root, file_dir)
	java_root = vim.fn.fnamemodify(java_root, ":p"):gsub("/$", "")
	file_dir = vim.fn.fnamemodify(file_dir, ":p"):gsub("/$", "")
	if vim.fn.stridx(file_dir, java_root) ~= 0 then
		return ""
	end
	local rel = file_dir:sub(#java_root + 1)
	rel = rel:gsub("^/+", ""):gsub("/+$", "")
	if rel == "" then
		return ""
	end
	return rel:gsub("/", ".")
end

return M
