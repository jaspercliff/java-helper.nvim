---@class JavaHelperConfig
---@field create_class_command string
---@field author? string 作者（Javadoc）
---@field since_format? string os.date 格式

local M = {}

---@type JavaHelperConfig
M.defaults = {
	create_class_command = "JavaCreateClass",
	author = nil,
	since_format = "%Y-%m-%d %H:%M:%S",
}

return M
