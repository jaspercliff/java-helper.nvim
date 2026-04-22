local Util = require("java-helper.util")
local JavaRoot = require("java-helper.java_root")
local TargetDir = require("java-helper.target_dir")
local Templates = require("java-helper.templates")

local M = {}

---@param config JavaHelperConfig
---@param opts? {target_dir?: string}
function M.create_class(config, opts)
	opts = opts or {}
	vim.ui.input({ prompt = "类名（无需 .java）: " }, function(input)
		if input == nil then
			return
		end

		local parts, err = Util.parse_name(input)
		if not parts then
			vim.notify(err, vim.log.levels.ERROR)
			return
		end
		parts.class_name = Util.capitalize_first_letter(parts.class_name)

		vim.ui.select(Templates.kinds(), {
			prompt = "新建类型：",
			format_item = function(item)
				return item.label
			end,
		}, function(choice)
			if not choice then
				return
			end

			local function join_package(a, b)
				a = a or ""
				b = b or ""
				if a ~= "" and b ~= "" then
					return a .. "." .. b
				end
				return a ~= "" and a or b
			end

			local target_dir = opts.target_dir and vim.fn.fnamemodify(opts.target_dir, ":p") or TargetDir.default_target_dir()
			local java_root = JavaRoot.find_java_source_root(target_dir)
			local input_pkg = parts.package_name or ""
			local base_pkg = ""

			if java_root then
				java_root = vim.fn.fnamemodify(java_root, ":p"):gsub("/$", "")
				if vim.fn.stridx(target_dir, java_root) == 0 then
					base_pkg = JavaRoot.infer_package(java_root, target_dir)
				else
					-- 例如在仓库根目录打开终端：把类放到标准 java 根下
					target_dir = java_root
					base_pkg = ""
				end
			end

			-- 最终包名：父目录推断包 + 输入的包段
			local package_name = join_package(base_pkg, input_pkg)

			if parts.rel_dir and parts.rel_dir ~= "" then
				target_dir = vim.fn.fnamemodify(target_dir .. "/" .. parts.rel_dir, ":p")
			end

			local path = vim.fn.fnamemodify(target_dir .. "/" .. parts.class_name .. ".java", ":p")
			if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
				vim.notify("文件已存在: " .. path, vim.log.levels.ERROR)
				return
			end

			local dir = vim.fn.fnamemodify(path, ":h")
			if vim.fn.isdirectory(dir) ~= 1 then
				vim.fn.mkdir(dir, "p")
			end

			local content = Templates.build_java_source(choice.kind, parts.class_name, package_name, {
				author = config.author,
				since = os.date(config.since_format or "%Y-%m-%d %H:%M:%S"),
			})
			local ok, write_err = pcall(vim.fn.writefile, vim.split(content, "\n", { plain = true }), path)
			if not ok then
				vim.notify("写入失败: " .. tostring(write_err), vim.log.levels.ERROR)
				return
			end

			vim.notify("已创建: " .. path, vim.log.levels.INFO)
			vim.cmd.edit(vim.fn.fnameescape(path))
		end)
	end)
end

return M
