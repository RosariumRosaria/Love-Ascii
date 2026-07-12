local utils = require("utils")
local container = {
	active_container = nil,
	is_open = false,
}

function container:get()
	return self.active_container
end

function container:set(entity)
	if not entity then
		return
	end
	if entity.inventory and utils.get_tag(entity, "container") then
		self.active_container = entity
		return self.active_container
	end
end

function container:open(entity)
	local con = container:set(entity)

	if con then
		self.is_open = true
		return self.active_container
	end
end

function container:close()
	self.is_open = false
	self.active_container = nil
end

return container
