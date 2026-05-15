local M = {}

--- 从项目根目录搜索匹配的文件（异步非阻塞）
---@param root string 项目根目录
---@param filename string 要搜索的文件名（不含路径和扩展名）
---@param ext string 扩展名过滤，如 ".xml" 或 ".java"
---@param callback function 搜索完成后的回调函数，传入匹配路径列表
local function find_files_async(root, filename, ext, callback)
	local cmd
	local target_name = filename .. ext

	if vim.fn.executable("rg") == 1 then
		cmd = { "rg", "--files", "--hidden", "-g", target_name, "--glob", "!{target,bin,build,out,.git,.idea,.gradle,node_modules}/*", root }
	elseif vim.fn.executable("fd") == 1 then
		cmd = { "fd", "-H", "-t", "f", "^" .. target_name:gsub("%.", "%%.") .. "$", "-E", "target", "-E", "bin", "-E", "build", "-E", "out", "-E", ".git", "-E", ".idea", "-E", ".gradle", root }
	else
		cmd = { "find", root, "-type", "f", "-name", target_name, "-not", "-path", "*/target/*", "-not", "-path", "*/bin/*", "-not", "-path", "*/build/*", "-not", "-path", "*/.git/*" }
	end

	local results = {}
	local timer = vim.loop.new_timer()
	-- Prevent UI lock by setting a timeout for safety
	timer:start(10000, 0, vim.schedule_wrap(function()
		-- We could kill the job here if we stored the job_id
	end))

	vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		on_stdout = function(_, data)
			if not data then return end
			for _, line in ipairs(data) do
				if line ~= "" then
					table.insert(results, line)
				end
			end
		end,
		on_exit = function()
			timer:stop()
			timer:close()
			vim.schedule(function()
				callback(results)
			end)
		end,
	})
end

M.find_files_async = find_files_async

--- 获取当前光标所在的方法名
local function get_current_method_name(is_java)
	local line_num = vim.api.nvim_win_get_cursor(0)[1]
	
	if is_java then
		local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
		if ok then
			local node = ts_utils.get_node_at_cursor()
			while node do
				if node:type() == "method_declaration" then
					local name_node = node:field("name")[1]
					if name_node then
						local ok_text, text = pcall(vim.treesitter.get_node_text, name_node, 0)
						if ok_text then
							return text
						end
					end
				end
				node = node:parent()
			end
		end

		local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
		local match = line:match("([%w_]+)%s*%(")
		if match then return match end
		
		return vim.fn.expand("<cword>")
	else
		for i = line_num, 1, -1 do
			local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
			local match = line:match('id%s*=%s*["\']([%w_]+)["\']')
			if match then
				return match
			end
			if line:match("</mapper") then break end
		end
		return vim.fn.expand("<cword>")
	end
end

--- 跳转到目标文件的方法定义处
local function jump_to_method(method_name, target_ext)
	if not method_name or method_name == "" then return end
	
	vim.fn.cursor(1, 1)
	
	local found = 0
	if target_ext == ".xml" then
		found = vim.fn.search('id=["\']' .. method_name .. '["\']', "cW")
	else
		found = vim.fn.search('\\v<' .. method_name .. '>\\s*\\(', "cW")
	end
	
	if found > 0 then
		vim.cmd("normal! zz")
	end
end

---@param config JavaHelperConfig
function M.go_to_mapper(config)
	local current_file = vim.api.nvim_buf_get_name(0)

	local is_java = current_file:match("%.java$")
	local is_xml = current_file:match("%.xml$")

	if not is_java and not is_xml then
		vim.notify("当前文件不是 Java 或 XML 文件", vim.log.levels.WARN, { title = "Java Helper" })
		return
	end

	local basename = vim.fn.fnamemodify(current_file, ":t:r")
	
	-- 基础验证：如果是 Java 文件，类名通常以 Mapper 结尾
	if is_java and not basename:match("Mapper$") and not basename:match("Dao$") then
		vim.notify("当前 Java 文件似乎不是 Mapper/Dao 接口", vim.log.levels.INFO, { title = "Java Helper" })
	end

	local target_ext = is_java and ".xml" or ".java"
	local method_name = get_current_method_name(is_java)
	local project_root = vim.fn.getcwd() -- 简单使用当前工作目录作为项目根目录
	
	-- 尝试查找 java_root
	local java_root_mod = require("java-helper.java_root")
	local java_root = java_root_mod.find_java_source_root(vim.fn.fnamemodify(current_file, ":h"))
	if java_root then
		-- 如果找到了 src/main/java，则向上两级到项目根目录
		local possible_root = vim.fn.fnamemodify(java_root, ":h:h")
		if vim.fn.isdirectory(possible_root) == 1 then
			project_root = possible_root
		end
	end

	vim.notify("正在查找 " .. basename .. target_ext .. "...", vim.log.levels.INFO, { title = "Java Helper" })

	find_files_async(project_root, basename, target_ext, function(results)
		if #results == 0 then
			vim.notify("未找到对应的 " .. target_ext .. " 文件", vim.log.levels.WARN, { title = "Java Helper" })
		elseif #results == 1 then
			vim.cmd("edit " .. vim.fn.fnameescape(results[1]))
			jump_to_method(method_name, target_ext)
		else
			vim.ui.select(results, {
				prompt = "找到多个文件，请选择：",
				format_item = function(item)
					-- 截取相对路径以便于阅读
					return item:gsub(project_root .. "/", "")
				end,
			}, function(choice)
				if choice then
					vim.cmd("edit " .. vim.fn.fnameescape(choice))
					jump_to_method(method_name, target_ext)
				end
			end)
		end
	end)
end

--- 提取 XML 文件中对应 methodName 的 SQL 块
---@param filepath string
---@param method_name string
---@return string[]|nil
local function extract_xml_block(filepath, method_name)
	local ok, lines = pcall(vim.fn.readfile, filepath)
	if not ok or not lines then return nil end
	
	local content = table.concat(lines, "\n")
	local s, e = content:find('<[%w_]+[^>]*id=["\']' .. method_name .. '["\'][^>]*>')
	if s then
		local tag = content:match('<([%w_]+)', s)
		if tag then
			local end_tag = "</" .. tag .. ">"
			local s_end, e_end = content:find(end_tag, e, true)
			local block = ""
			if s_end then
				block = content:sub(s, e_end)
			else
				block = content:sub(s, e)
			end
			
			local block_lines = vim.split(block, "\n", { plain = true })
			
			-- 自动去掉多余的缩进，使悬浮窗看起来更整洁
			local min_indent = nil
			for _, line in ipairs(block_lines) do
				if line:match("%S") then
					local indent = line:match("^(%s*)")
					if not min_indent or #indent < min_indent then
						min_indent = #indent
					end
				end
			end
			
			if min_indent and min_indent > 0 then
				for i, line in ipairs(block_lines) do
					if #line >= min_indent then
						block_lines[i] = line:sub(min_indent + 1)
					end
				end
			end
			
			return block_lines
		end
	end
	return nil
end

---@param config JavaHelperConfig
---@param is_auto? boolean 是否是由 CursorHold 自动触发的
function M.mapper_hover(config, is_auto)
	local current_file = vim.api.nvim_buf_get_name(0)

	if not current_file:match("%.java$") then
		if not is_auto then
			vim.notify("悬浮预览 SQL 功能仅在 Java 文件中可用", vim.log.levels.WARN, { title = "Java Helper" })
		end
		return
	end

	local basename = vim.fn.fnamemodify(current_file, ":t:r")
	
	if is_auto and not basename:match("Mapper$") and not basename:match("Dao$") then
		return
	end
	
	local method_name = get_current_method_name(true)

	if not method_name or method_name == "" then
		if not is_auto then
			vim.notify("未能获取当前光标下的方法名", vim.log.levels.WARN, { title = "Java Helper" })
		end
		return
	end

	local project_root = vim.fn.getcwd()
	local java_root_mod = require("java-helper.java_root")
	local java_root = java_root_mod.find_java_source_root(vim.fn.fnamemodify(current_file, ":h"))
	if java_root then
		local possible_root = vim.fn.fnamemodify(java_root, ":h:h")
		if vim.fn.isdirectory(possible_root) == 1 then
			project_root = possible_root
		end
	end

	find_files_async(project_root, basename, ".xml", function(results)
		if #results == 0 then
			if not is_auto then
				vim.notify("未找到对应的 XML 文件", vim.log.levels.WARN, { title = "Java Helper" })
			end
			return
		end

		-- 取第一个匹配的 XML 文件
		local target_xml = results[1]
		local block_lines = extract_xml_block(target_xml, method_name)

		if block_lines then
			vim.lsp.util.open_floating_preview(block_lines, "xml", {
				border = "rounded",
				focus_id = "java_mapper_hover",
			})
		else
			if not is_auto then
				vim.notify("在 XML 中未找到对应的 ID: " .. method_name, vim.log.levels.WARN, { title = "Java Helper" })
			end
		end
	end)
end

return M
