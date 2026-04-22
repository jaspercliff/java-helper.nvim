local M = {}

---@param name string
---@return string|nil class_name
---@return string|nil err
function M.sanitize_class_name(name)
	name = vim.trim(name or ""):gsub("%.java$", ""):gsub("%.JAVA$", "")
	if name == "" then
		return nil, "类名不能为空"
	end
	if not name:match("^[%a_][%w_]*$") then
		return nil, "类名只能包含字母、数字、下划线，且不能以数字开头"
	end
	return name, nil
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
