local M = {}

---@class JavaHelperNameParts
---@field class_name string
---@field package_name string "" 表示默认包
---@field rel_dir string "com/a/b" 或 ""

---@param name string
---@return JavaHelperNameParts|nil parts
---@return string|nil err
function M.parse_name(name)
	name = vim.trim(name or ""):gsub("%.java$", ""):gsub("%.JAVA$", "")
	if name == "" then
		return nil, "类名不能为空"
	end

	-- 支持 Foo 或 com.a.b.Foo
	if not name:match("^[%a_][%w_%.]*$") then
		return nil, "只能包含字母、数字、下划线、点，且不能以数字开头"
	end
	if name:find("..", 1, true) then
		return nil, "包名格式不合法：不能包含连续的点"
	end
	if name:sub(-1) == "." then
		return nil, "包名格式不合法：不能以点结尾"
	end

	local package_name = ""
	local class_name = name
	if name:find(".", 1, true) then
		local parts = vim.split(name, ".", { plain = true })
		class_name = parts[#parts]
		table.remove(parts, #parts)
		package_name = table.concat(parts, ".")
	end

	if class_name == "" then
		return nil, "类名不能为空"
	end
	if not class_name:match("^[%a_][%w_]*$") then
		return nil, "类名只能包含字母、数字、下划线，且不能以数字开头"
	end

	local rel_dir = package_name ~= "" and package_name:gsub("%.", "/") or ""
	return {
		class_name = class_name,
		package_name = package_name,
		rel_dir = rel_dir,
	}, nil
end

---@param name string
---@return string
function M.capitalize_first_letter(name)
	local first = name:sub(1, 1)
	if first:match("%a") then
		return first:upper() .. name:sub(2)
	end
	return name
end

return M
