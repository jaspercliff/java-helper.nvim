---@class JavaHelperConfig
---@field create_class_command string

local M = {}

---@type JavaHelperConfig 命令名
local config = {
	create_class_command = "JavaCreateClass",
}

---@param name string
---@return string|nil class_name
---@return string|nil err
--- vim neovim 提供的全局变量
local function sanitize_class_name(name)
	name = vim.trim(name or ""):gsub("%.java$", ""):gsub("%.JAVA$", "")
	if name == "" then
		return nil, "类名不能为空"
	end
	if not name:match("^[%a_][%w_]*$") then
		return nil, "类名只能包含字母、数字、下划线，且不能以数字开头"
	end
	return name, nil
end

---从目录向上查找 Maven/Gradle 风格的 java 源码根目录。
---@param start_dir string
---@return string|nil java_root 绝对路径，末尾无 /
local function find_java_source_root(start_dir)
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
local function infer_package(java_root, file_dir)
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

---@return string dir 用于放置新文件的目录（绝对路径）
local function default_target_dir()
	-- snacks.nvim explorer（左侧文件管理器）里如果选中的是目录/文件，
	-- 优先在该条目所在目录创建
	if _G.Snacks and Snacks.picker and type(Snacks.picker.get) == "function" then
		local ok, pickers = pcall(Snacks.picker.get, { source = "explorer", tab = true })
		if ok and type(pickers) == "table" then
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
		end
	end

	local buf = vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(buf)
	if name ~= "" then
		return vim.fn.fnamemodify(name, ":p:h")
	end
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
end

---@param class_name string
---@param package_name string
---@return string
local function build_java_source(class_name, package_name)
	local lines = {}
	if package_name ~= "" then
		lines[#lines + 1] = "package " .. package_name .. ";"
		lines[#lines + 1] = ""
	end
	lines[#lines + 1] = "public class " .. class_name .. " {"
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	return table.concat(lines, "\n")
end

function M.create_class()
	vim.ui.input({ prompt = "类名（无需 .java）: " }, function(input)
		if input == nil then
			return
		end
		local class_name, err = sanitize_class_name(input)
		if not class_name then
			vim.notify(err, vim.log.levels.ERROR)
			return
		end

		local target_dir = default_target_dir()
		local java_root = find_java_source_root(target_dir)
		local package_name = ""
		if java_root then
			java_root = vim.fn.fnamemodify(java_root, ":p"):gsub("/$", "")
			if vim.fn.stridx(target_dir, java_root) == 0 then
				package_name = infer_package(java_root, target_dir)
			else
				-- 例如在仓库根目录打开终端：把类放到标准 java 根下（默认包）
				target_dir = java_root
				package_name = ""
			end
		end

		local path = vim.fn.fnamemodify(target_dir .. "/" .. class_name .. ".java", ":p")
		if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
			vim.notify("文件已存在: " .. path, vim.log.levels.ERROR)
			return
		end

		local dir = vim.fn.fnamemodify(path, ":h")
		if vim.fn.isdirectory(dir) ~= 1 then
			vim.fn.mkdir(dir, "p")
		end

		local content = build_java_source(class_name, package_name)
		local ok, write_err = pcall(vim.fn.writefile, vim.split(content, "\n", { plain = true }), path)
		if not ok then
			vim.notify("写入失败: " .. tostring(write_err), vim.log.levels.ERROR)
			return
		end

		vim.notify("已创建: " .. path, vim.log.levels.INFO)
		vim.cmd.edit(vim.fn.fnameescape(path))
	end)
end

---@param opts JavaHelperConfig|nil
function M.setup(opts)
	config = vim.tbl_extend("force", config, opts or {})

	vim.api.nvim_create_user_command(config.create_class_command, function()
		M.create_class()
	end, { desc = "在当前目录创建 Java 类（自动包名与类骨架）" })
end

return M
