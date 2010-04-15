-- Prototype OO
function clone( base_object, clone_object )
   if type( base_object ) ~= "table" then
    return clone_object or base_object 
   end
   clone_object = clone_object or {}
  clone_object.__index = base_object
   return setmetatable(clone_object, clone_object)
end

-- Sets
--dofile("set.lua")

-- Strings
dofile("string.lua")

-- Slow :(
function isa( clone_object, base_object )
   local clone_object_type = type(clone_object)
   local base_object_type = type(base_object)
  if clone_object_type ~= "table" and base_object_type ~= table then
    return clone_object_type == base_object_type
  end
  local index = clone_object.__index
  local _isa = index == base_object
  while not _isa and index ~= nil do
    index = index.__index
    _isa = index == base_object
  end
  return _isa
end

-- MOO Parent
object = clone( table, { clone = clone, isa = isa } )

----------------------------------------------------------------
thing = object:clone()
thing.description = "You see an object that needs to be described."
function thing:look()
   return self.description
end

container = thing:clone()
container.contents = {}

agent = container:clone()
function agent:look()
   return self.location.description
end
function agent:inventory()
   local message = "Inventory:"
   if next(self.contents) then
	  for k, v in pairs(self.contents)
   else
	  message = "You are not carrying anything."
   end
   return message
end
network_agent = agent:clone()
player = network_agent:clone()
programmer = player:clone()
wizard = programmer:clone()
function network_agent:input(input)
   print("[Lua:network_agent.input]:::" .. input)
   local verb, direct, preposition, indirect = self:parse_command(input)
   --if verb then print("Verb:::"..verb) end
   --if direct then print("Direct:::"..direct) end
   --if preposition then print("Preposition:::"..preposition) end
   --if indirect then print("Indirect:::"..indirect) end
   local call = self[verb]
   result, returned = pcall(call, self)
   if result then
	  return (returned or "Ok") .. "\n"
   else
	  return returned .. "\n"
   end
end
function network_agent:parse_command(input)
   -- put the yellow bird in the clock
   function is_preposition (word)
	  local prepositions = {'named','with','using','at','to','in front of', 'in', 'inside',
					  'into', 'on top of', 'on', 'onto', 'upon', 'out of',
					  'from inside', 'from', 'over', 'through', 'under',
					  'underneath', 'beneath', 'behind', 'beside', 'for',
					  'about', 'is', 'as', 'off', 'off of'}
	  for i, w in ipairs(prepositions) do
		 if word == w then
			return w
		 end
	  end
   end
   if string.len(input) > 0 then
	  input = input:gsub("^;", "eval ")
	  input = input:gsub("^'", "say ")
	  input = input:gsub("^:", "emote ")
	  local split_input = input:split(" ")
	  local verb = split_input[1]
	  for i, word in ipairs(split_input) do
		 preposition = is_preposition(word)
		 if preposition then
			index = i
			break
		 end
	  end
	  if preposition then
		 local direct_object = input:match(verb.."%A(.*)%A"..preposition)
		 local indirect_object = input:match(preposition.."%A(.*)")
		 return verb, direct_object, preposition, indirect_object
	  else
		 local direct_object = input:match(verb.."%A(.*)")
		 return verb, direct_object, nil, nil
	  end
   end
end

room = container:clone()
nowhere = room:clone()
nowhere.description = "It's not much to look at."
first_room = room:clone()
first_room.description = "This is all there is here now."

thing.location = nowhere
thing.owner = wizard
player.location = first_room

