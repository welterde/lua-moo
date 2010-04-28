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

container = thing:clone()
container.contents = {}

agent = container:clone()
function thing:look(target)
   if target then
	  return target.description
   else
	  local message = self.location.description
	  if next(self.location.contents) then 
		 message = message .. "\n\nThere is "
		 for k,v in pairs(self.location.contents) do
			message = message .. k .. ", "
		 end
		 message = message .. " here."
	  end
	  return message
   end
end
function agent:inventory()
   local message = ""
   if next(self.contents) then
	  for k, v in pairs(self.contents) do
		 message = message .. "  " .. k .. "\n"
	  end
   else
	  message = "You are not carrying anything."
   end
   return message
end
function agent:get(target)
   if target then
	  if (target.location == self.location) then
		 self.location.contents[target.name] = nil
		 target.location = self
		 self.contents[target.name] = target
		 return "You picked up " .. target.name
	  end
	  if (target.location == self) then
		 return "You're already holding that."
	  end
	  return "You're can't reach that."
   else
	  return "What did you want to get?"
   end
end
function agent:drop(target)
   if target then
	  if (target.location == self) then
		 self.location.contents[target.name] = target
		 target.location = self.location
		 self.contents[target.name] = nil
		 return "Dropped " .. target.name
	  end
	  return "You don't have that in your inventory."
   else
	  return "What did you want to drop?"
   end
end
network_agent = agent:clone()
player = network_agent:clone()
programmer = player:clone()
function programmer:AT_describe(target, description)
   if target and description then
	  target.description = description
   end
end
function programmer:AT_show(target)
   function table_print (tt, indent, done)
	  done = done or {}
	  indent = indent or 0
	  if type(tt) == "table" then
		 local sb = {}
		 for key, value in pairs (tt) do
			table.insert(sb, string.rep (" ", indent)) -- indent it
			if type (value) == "table" and not done [value] then
			   done [value] = true
			   table.insert(sb, key .. " = {\n");
			   table.insert(sb, table_print (value, indent + 2, done))
			   table.insert(sb, string.rep (" ", indent)) -- indent it
			   table.insert(sb, "}\n");
			elseif "number" == type(key) then
			   table.insert(sb, string.format("\"%s\"\n", tostring(value)))
			else
			   table.insert(sb, string.format(
							   "%s = \"%s\"\n", tostring (key), tostring(value)))
			end
		 end
		 return table.concat(sb)
	  else
		 return tt .. "\n"
	  end
   end
   
   function to_string( tbl )
	  if  "nil"       == type( tbl ) then
		 return tostring(nil)
	  elseif  "table" == type( tbl ) then
		 return table_print(tbl)
	  elseif  "string" == type( tbl ) then
		 return tbl
	  else
		 return tostring(tbl)
	  end
   end

   if target then
	  return table_print(target)
   end
end
wizard = programmer:clone()
wizard.description = "A shadowy figure of amazing and cromulent power."
function network_agent:input(input)
   -- Determine what to do with the player (or bot) input
   print("[Lua:network_agent.input]:::" .. input)
   local verb, direct, preposition, indirect = self:parse_command(input)
   if verb then print("Verb:::"..verb) end
   if direct then print("Direct:::"..direct) end
   if preposition then print("Preposition:::"..preposition) end
   if indirect then print("Indirect:::"..indirect) end
   local arg, call
   if indirect and not direct then
	  -- The reasoning for this is 'look at <object>'
	  direct = indirect
	  indirect = nil
	  print("Direct assumed to be Indirect")
   end
   if direct then
	  if direct == "self" or direct == "me" then
		 arg = self
		 call = arg[verb]
	  else
		 arg = (self.location.contents[direct] or self.contents[direct])
		 call = self[verb] or arg[verb] or self.location[verb]
	  end
   else
	  call = self[verb]
   end
   local call_function = function () return call(self, arg, indirect) end 
   local result, returned = xpcall(call_function, debug.traceback)
   if result then
	  -- This might be an error
	  return (returned or "Ok") .. "\n"
   else
	  return "Error: " .. returned .. "\n"
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
	  input = input:gsub("^@", "AT_")
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

apple = thing:clone()
apple.name = "Tasty Apple"
apple.description = "A tasty apple."
apple.location = wizard
wizard.contents = {[apple.name]=apple}
