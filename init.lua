
--
-- Helper functions
--

local function get_sign(i)
	if i == 0 then
		return 0
	else
		return i/math.abs(i)
	end
end

local function get_velocity(vx, vy, vz, yaw)
	local x = math.cos(yaw)*vx+math.cos(math.pi/2+yaw)*vz
	local z = math.sin(yaw)*vx+math.sin(math.pi/2+yaw)*vz
	return {x=x, y=vy, z=z}
end

local function get_v(v)
	return math.sqrt(vx^2+vz^2)
end

--
-- Heli entity
--

local heli = {
	physical = true,
	collisionbox = {-1,-0.6,-1, 1,0.3,1},
	
	--Just copy from lua api for test
	collide_with_objects = true,
	weight = 5,
	
	visual = "mesh",
	mesh = "root.x",
	--Player
	driver = nil,
	
	--Heli mesh
	model = nil,
	
	--In progress
	motor = nil,
	left = true,
	timer=0,
	
	--Rotation
	yaw=0,
	
	--Detect hit an object or node
	prev_y=0,
	
	--Speeds
	vx=0,
	vy=0,
	vz=0
	
	
}
local heliModel = {
	visual = "mesh",
	mesh = "heli.x",
	textures = {"blades.png","blades.png","heli.png","Glass.png"},
}	
local motor = {
	physical = true,
	collisionbox = {-2,0.5,-1, 1,1,1},
	visual = "mesh",
	mesh = "motor.x",
	textures = {"motor.png"},
	driver = nil,
	left = true,
	timer=0,
	vx = 0,--Velo. for/back-ward
	vy = 0,--Velo. up/down
	vz = 0--Velo. side
}

function heli:on_rightclick(clicker)
	if not clicker or not clicker:is_player() then
		return
	end
	if self.driver and clicker == self.driver then
		clicker:set_attach(self.model, "Root", {x=0,y=0,z=0}, {x=0,y=0,z=0})
		self.driver = nil
		clicker:set_detach()
		self.model:set_animation({x=0,y=1},0, 0)
	elseif not self.driver then
		self.model:set_animation({x=0,y=10},10, 0)
		self.driver = clicker
		--self.driver:set_animation({ x= 81, y=160, },10,0)
		clicker:set_attach(self.model, "Root", {x=0,y=0,z=-10}, {x=-90,y=0,z=-90})
		--self.object:setyaw(clicker:get_look_yaw())
	end
end

function heliModel:on_activate(staticdata, dtime_s)
	self.object:set_armor_groups({immortal=1})
	local is_attached = false
	for _,object in ipairs(minetest.env:get_objects_inside_radius(self.object:getpos(), 2)) do
		if object and object:get_luaentity() and object:get_luaentity().name=="helicopter:heli" then
			if object:get_luaentity().model == nil then
				object:get_luaentity().model = self
			end
			if object:get_luaentity().model == self then
				is_attached = true
			end
		end
	end
	if is_attached == false then
		self.object:remove()
	end
	
end

function heli:on_activate(staticdata, dtime_s)
	self.object:set_armor_groups({immortal=1})
	self.prev_y=self.object:getpos()
	if self.model == nil then
		self.model = minetest.env:add_entity(self.object:getpos(), "helicopter:heliModel")
		self.model:set_attach(self.object, "Root", {x=0,y=0,z=2}, {x=0,y=0,z=0})	
	end
end

function heli:get_staticdata(self)	
end

function heli:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if self.model ~= nil then
		self.model:remove()
	end
	self.object:remove()
	if puncher and puncher:is_player() then
		puncher:get_inventory():add_item("main", "helicopter:heli")
	end
end
function heliModel:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	self.object:remove()
end
function heli:on_step(dtime)
	--Prevent shaking heli while sitting in it
	
	
	--Prevent multi heli control bug
	if self.driver and ( math.abs(self.driver:getpos().x-self.object:getpos().x)>10*dtime or math.abs(self.driver:getpos().y-self.object:getpos().y)>10*dtime or math.abs(self.driver:getpos().z-self.object:getpos().z)>10*dtime) then
		self.driver = nil
	end
	
	if self.driver then
		--self.driver:set_animation({ x= 81, y=160, },10,0)
		self.yaw = self.driver:get_look_yaw()
		v = self.object:getvelocity()
		local ctrl = self.driver:get_player_control()
		--Forward/backward
		if ctrl.up then
			self.vx = self.vx + math.cos(self.driver:get_look_yaw())*0.1
			self.vz = self.vz + math.sin(self.driver:get_look_yaw())*0.1
		end
		if ctrl.down then
			self.vx = self.vx-math.cos(self.driver:get_look_yaw())*0.1
			self.vz = self.vz-math.sin(self.driver:get_look_yaw())*0.1
		end
		--Left/right
		if ctrl.left then
			self.vz = self.vz+math.cos(self.driver:get_look_yaw())*0.1
			self.vx = self.vx+math.sin(math.pi+self.driver:get_look_yaw())*0.1
		end
		if ctrl.right then
			self.vz = self.vz-math.cos(self.driver:get_look_yaw())*0.1
			self.vx = self.vx-math.sin(math.pi+self.driver:get_look_yaw())*0.1
		end
		--up/down
		if ctrl.jump then
			if self.vy<1.5 then
				self.vy = self.vy+0.2
			end
		end
		if ctrl.sneak then
			if self.vy>-1.5 then
				self.vy = self.vy-0.2
			end
		end
		--
		--Speed limit
		if math.abs(self.vx) > 4.5 then
			self.vx = 4.5*get_sign(self.vx)
		end
		if math.abs(self.vz) > 4.5 then
			self.vz = 4.5*get_sign(self.vz)
		end
		
	end
	
	--Decelerating
	local sx=get_sign(self.vx)
	self.vx = self.vx - 0.02*sx
	local sz=get_sign(self.vz)
	self.vz = self.vz - 0.02*sz
	local sy=get_sign(self.vy)
	self.vy = self.vy-0.01*sy
	
	--Stop
	if sx ~= get_sign(self.vx) then
		self.vx = 0
	end
	if sz ~= get_sign(self.vz) then
		self.vz = 0
	end
	
	
	--Speed limit
	if math.abs(self.vx) > 4.5 then
		self.vx = 4.5*get_sign(self.vx)
	end
	if math.abs(self.vz) > 4.5 then
		self.vz = 4.5*get_sign(self.vz)
	end
	if math.abs(self.vy) > 4.5 then
		self.vz = 4.5*get_sign(self.vz)
	end
	
	--Set speed to entity
	self.object:setvelocity({x=self.vx, y=self.vy,z=self.vz})
	--Model rotation 
	--[[if self.driver then
	self.model:set_attach(self.object,"Root", 
	{x=-(self.driver:getpos().x-self.object:getpos().x)*dtime,
	y=-(self.driver:getpos().z-self.object:getpos().z)*dtime,
	z=-(self.driver:getpos().y-self.object:getpos().y)*dtime}, {
			x=-90+self.vz*5*math.cos(self.yaw)-self.vx*5*math.sin(self.yaw), 
			y=0-self.vz*5*math.sin(self.yaw)-self.vx*5*math.cos(self.yaw), 
			z=self.yaw*57})
	else]]--
	if self.model then
		self.model:set_attach(self.object,"Root", {x=0,y=0,z=0}, {
			x=-90+self.vz*4*math.cos(self.yaw)-self.vx*4*math.sin(self.yaw), 
			y=0-self.vz*4*math.sin(self.yaw)-self.vx*4*math.cos(self.yaw), 
			z=self.yaw*57})
	end
end

--
--Registration
--

minetest.register_entity("helicopter:heli", heli)
minetest.register_entity("helicopter:heliModel", heliModel)
minetest.register_entity("helicopter:motor", motor)
--minetest.register_entity("helicopter:rocket", rocket)

--
--Craft items
--

--Blades
minetest.register_craftitem("helicopter:blades",{
	description = "Blades",
	inventory_image = "blades_inv.png",
	wield_image = "blades_inv.png",
})
--Cabin
minetest.register_craftitem("helicopter:cabin",{
	description = "Cabin for heli",
	inventory_image = "cabin_inv.png",
	wield_image = "cabin_inv.png",
})
--Heli
minetest.register_craftitem("helicopter:heli", {
	description = "Helicopter",
	inventory_image = "heli_inv.png",
	wield_image = "heli_inv.png",
	wield_scale = {x=1, y=1, z=1},
	liquids_pointable = false,
	
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return
		end
		pointed_thing.under.y = pointed_thing.under.y+1
		minetest.env:add_entity(pointed_thing.under, "helicopter:heli")
		--minetest.env:add_entity(pointed_thing.under, "helicopter:heliModel")
		--minetest.env:add_entity(pointed_thing.under, "helicopter:motor")
		itemstack:take_item()
		return itemstack
	end,
})

--
--Craft
--

minetest.register_craft({
	output = 'helicopter:blades',
	recipe = {
		{'', 'default:steel_ingot', ''},
		{'default:steel_ingot', 'group:stick', 'default:steel_ingot'},
		{'', 'default:steel_ingot', ''},
	}
})
minetest.register_craft({
	output = 'helicopter:cabin',
	recipe = {
		{'', 'group:wood', ''},
		{'group:wood', 'default:mese_crystal','default:glass'},
		{'group:wood','group:wood','group:wood'},		
	}
})		
minetest.register_craft({
	output = 'helicopter:heli',
	recipe = {
		{'', 'helicopter:blades', ''},
		{'helicopter:blades', 'helicopter:cabin',''},	
	}
})	

