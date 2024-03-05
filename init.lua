newplayer = {}

local S = minetest.get_translator("newplayer")


if type(minetest.colorize) == "function" then
	newplayer.colorize = minetest.colorize
else
	newplayer.colorize = function(color,text)
		return text
	end
end

local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-keywords.txt","r")
if f then
	local d = f:read("*all")
	newplayer.keywords = minetest.deserialize(d)
	f:close()
else
	newplayer.keywords = {}
end

newplayer.assigned_keywords = {}

newplayer.hudids = {}

local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-rules.txt","r")
if f then
	local d = f:read("*all")
	newplayer.rules = minetest.formspec_escape(d)
	f:close()
else
	newplayer.rules = S("Rules file not found!\n\nThe file should be named \"newplayer-rules.txt\" and placed in the following location:\n\n @1", minetest.get_worldpath() .. DIR_DELIM)
end

function newplayer.savekeywords()
	local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-keywords.txt","w")
	local d = minetest.serialize(newplayer.keywords)
	f:write(d)
	f:close()
end

local editformspec1 = "size[13,9]"..
	"label[0,-0.1;" .. S("Editing Server Rules") .. "]"..
	"textarea[0.25,0.5;12.5,7;rules;;"
-- the rules get inserted between these two on demand
local editformspec2 = "]"..
	"button_exit[0.5,8.1;2,1;save;" .. S("Save") .."]"..
	"button_exit[5,8.1;2,1;quit;" .. S("Cancel") .."]"

function newplayer.showrulesform(name)

	-- Word-wrap the file
	local strstart = 1
	local charpos = 0
	local linelen = 0
	local tline = 1
	local lastbreak = 1

	newplayer.rules_formspec_buffer = ""

	while charpos < #newplayer.rules do
		charpos = charpos + 1
		linelen = linelen + 1
		local c = string.sub(newplayer.rules, charpos, charpos)
		if c == " " or c == "\t" or c == "\n" or c == "\r" then lastbreak = charpos end
		if linelen > 70 or c == "\n" or c == "\r" then
			newplayer.rules_formspec_buffer = newplayer.rules_formspec_buffer..","..string.sub(newplayer.rules, strstart, lastbreak-1)
			tline = tline + 1
			strstart = lastbreak + 1
			charpos = strstart
			linelen = 0
		end
	end

	if #newplayer.keywords > 0 then
		newplayer.assigned_keywords[name] = newplayer.keywords[math.random(1,#newplayer.keywords)]
		newplayer.rules_subbed = string.gsub(newplayer.rules_formspec_buffer,"@KEYWORD",newplayer.assigned_keywords[name])
	else
		newplayer.rules_subbed = newplayer.rules_formspec_buffer
	end
	if #newplayer.keywords > 0 and minetest.check_player_privs(name,{interact=true}) and not minetest.check_player_privs(name,{server=true}) then
		newplayer.rules_subbed_interact = string.gsub(newplayer.rules_formspec_buffer,"@KEYWORD",minetest.formspec_escape("[Hidden because you already have interact]"))
	else
		newplayer.rules_subbed_interact = newplayer.rules_formspec_buffer
	end		
	local form_interact = "size[13,9]"..
				"label[0,-0.1;" .. S("Server Rules") .."]"..
				"textlist[0.25,0.5;12.5,6.25;rules;"..newplayer.rules_subbed_interact.."]"
	local form_nointeract = "size[13,9]"..
				"label[0,-0.1;" .. S("Server Rules") .."]"..
				"textlist[0.25,0.5;12.5,6.25;rules;"..newplayer.rules_subbed.."]"..
				"button[1,8;2,1;yes;" .. S("I agree") .."]"..
				"button[5,8;2,1;no;" .. S("I do not agree") .."]"
	if #newplayer.keywords > 0 then
		form_nointeract = form_nointeract.."field[0.5,7.6;8,1;keyword;Enter keyword from rules above:;]"
	end
	local hasinteract = minetest.check_player_privs(name,{interact=true})
	if hasinteract then
		if minetest.check_player_privs(name,{server=true}) then
			form_interact = form_interact.."button_exit[0.4,8.1;2,1;quit;" .. S("OK") .."]"
			form_interact = form_interact.."button[4,8.1;2,1;edit;" .. S("Edit") .."]"
		else
			form_interact = form_interact.."button_exit[0.4,8.1;2,1;quit;" .. S("OK") .."]"
		end
		minetest.show_formspec(name,"newplayer:rules_interact",form_interact)
	else
		minetest.show_formspec(name,"newplayer:rules_nointeract",form_nointeract)
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if minetest.check_player_privs(name,{interact=true}) then
		return
	end
	local nointeractspawn = minetest.setting_get_pos("spawnpoint_no_interact")
	if nointeractspawn then
		player:setpos(nointeractspawn)
	end
	newplayer.hudids[name] = player:hud_add({
		hud_elem_type = "text",
		position = {x=0.5,y=0.5},
		scale = {x=100,y=100},
		text = S("BUILDING DISABLED\nYou must agree to\nthe rules before building!\nUse the /rules command\nto see them."),
		number = 0xFF6666,
		alignment = {x=0,y=0},
		offset = {x=0,y=0}
	})
	minetest.after(0,newplayer.showrulesform,name)
end)

minetest.register_on_player_receive_fields(function(player,formname,fields)
	local name = player:get_player_name()
	if formname == "newplayer:rules_nointeract" then
		if fields.yes then
			if  #newplayer.keywords == 0 or (not newplayer.assigned_keywords[name]) or string.lower(fields.keyword) == string.lower(newplayer.assigned_keywords[name]) then
				local privs = minetest.get_player_privs(name)
				privs.interact = true
				local extraprivs = minetest.settings:get("newplayer.extra_privs")
				if extraprivs then
					for i in string.gmatch(extraprivs,"%S+") do
						privs[i] = true
					end
				end
				minetest.set_player_privs(name,privs)
				if newplayer.hudids[name] then
					minetest.get_player_by_name(name):hud_remove(newplayer.hudids[name])
					minetest.get_player_by_name(name):hud_remove(newplayer.hudids[name]-1)
					newplayer.hudids[name] = nil
				end
				local spawn = minetest.setting_get_pos("spawnpoint_interact")
				if spawn then
					minetest.chat_send_player(name,S("Teleporting to spawn..."))
					player:setpos(spawn)
				else
					minetest.chat_send_player(name,newplayer.colorize("#FF0000","ERROR: ")..S("The spawn point is not set!"))
				end
				local form =    "size[5,3]"..
						"label[1,0;" .. S("Thank you for agreeing") .. "]"..
						"label[1,0.5;" .. S("to the rules!") .. "]"..
						"label[1,1;" .. S("You are now free to play normally.") .. "]"
				if minetest.check_player_privs(name,"teleport") then
					form = form .. "label[1,1.5;" .. S("You can also use /spawn to return here.") .. "]"
				end
				form = form .. "button_exit[1.5,2;2,1;quit;" .. S("OK") .. "]"
				
				minetest.show_formspec(name,"newplayer:agreethanks",form)
			else
				local form =    "size[5,3]"..
						"label[1,0;" .. S("Incorrect keyword!") .. "]"..
						"button[1.5,2;2,1;quit;" .. S("Try Again") .. "]"
				minetest.show_formspec(name,"newplayer:tryagain",form)
			end
		elseif fields.no then
			local form =    "size[5,3]"..
					"label[1,0;" .. S("You may remain on the server,") .. "]"..
					"label[1,0.5;" .. S("but you may not dig or build") .. "]"..
					"label[1,1;" .. S("until you agree to the rules.") .. "]"..
					"button_exit[1.5,2;2,1;quit;" .. S("OK") .. "]"
			minetest.show_formspec(name,"newplayer:disagreewarning",form)
		end
		return true
	elseif formname == "newplayer:tryagain" then
		newplayer.showrulesform(name)
		return true
	elseif formname == "newplayer:editrules" then
		if minetest.check_player_privs(name, {server=true}) then
			if fields.save then
				local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-rules.txt","w")
				f:write(fields.rules)
				f:close()
				newplayer.rules = minetest.formspec_escape(fields.rules)
				minetest.chat_send_player(name,newplayer.colorize("#55FF55","Success: ")..S("Rules/keyword updated."))
			end
		else
			minetest.chat_send_player(name,S("You hacker you... nice try!"))
		end
	elseif formname == "newplayer:rules_interact" then
		if fields.edit and minetest.check_player_privs(name,{server=true}) then
			minetest.show_formspec(name,"newplayer:editrules",editformspec1..newplayer.rules..editformspec2)
		end
	elseif formname == "newplayer:agreethanks" or formname == "newplayer:disagreewarning" then
		return true
	elseif formname == "newplayer:help" then
		if fields.yes then
			newplayer.showrulesform(name)
		end
		return true
	else
		return false
	end
end)

minetest.register_chatcommand("rules",{
	params = "",
	description = S("View the rules"),
	func = newplayer.showrulesform
	}
)

minetest.register_chatcommand("editrules",{
	params = "",
	description = S("Edit the rules"),
	privs = {server=true},
	func = function(name)
		minetest.show_formspec(name,"newplayer:editrules",editformspec1..newplayer.rules..editformspec2)
		return true
	end}
)

minetest.register_chatcommand("set_no_interact_spawn",{
	params = "",
	description = S("Set the spawn point for players without interact to your current position"),
	privs = {server=true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		local pos = player:get_pos()
		minetest.setting_set("spawnpoint_no_interact",string.format("%s,%s,%s",pos.x,pos.y,pos.z))
		minetest.setting_save()
		return true, newplayer.colorize("#55FF55",S("Success: "))..S("Spawn point for players without interact set to: ")..newplayer.colorize("#00FFFF",minetest.pos_to_string(pos))
	end}
)

minetest.register_chatcommand("set_interact_spawn",{
	params = "",
	description = S("Set the spawn point for players with interact to your current position"),
	privs = {server=true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		local pos = player:get_pos()
		minetest.setting_set("spawnpoint_interact",string.format("%s,%s,%s",pos.x,pos.y,pos.z))
		minetest.setting_save()
		return true, newplayer.colorize("#55FF55",S("Success: "))..S("Spawn point for players with interact set to: ")..newplayer.colorize("#00FFFF",minetest.pos_to_string(pos))
	end}
)

minetest.register_chatcommand("getkeywords",{
	params = "",
	description = S("Gets the list of keywords used to obtain the interact privilege"),
	privs = {server=true},
	func = function(name)
		local out = ""
		if #newplayer.keywords > 0 then
			out = S("Currently configured keywords:")
			for _,kw in pairs(newplayer.keywords) do
				out = out.."\n"..newplayer.colorize("#00FFFF",kw)
			end
		else
			out = S("No keywords are currently set.")
		end
		return true, out
	end}
)

minetest.register_chatcommand("addkeyword",{
	params = "<keyword>",
	description = S("Add a keyword to the list of keywords used to obtain the interact privilege"),
	privs = {server=true},
	func = function(name,param)
		if (not param) or param == "" then
			return true, newplayer.colorize("#FF0000","ERROR: ")..S("No keyword supplied")
		end
		table.insert(newplayer.keywords,param)
		newplayer.savekeywords()
		return true, string.format("Keyword \"%s\" added",param)
	end}
)

minetest.register_chatcommand("delkeyword",{
	params = "<keyword>",
	description = S("Remove a keyword from the list of keywords used to obtain the interact privilege"),
	privs = {server=true},
	func = function(name,param)
		if (not param) or param == "" then
			return true, newplayer.colorize("#FF0000","ERROR: ")..S("No keyword supplied")
		end
		for k,v in pairs(newplayer.keywords) do
			if v == param then
				newplayer.keywords[k] = nil
				newplayer.savekeywords()
				return true, S("Keyword @1 removed",newplayer.colorize("#00FFFF",param))
			end
		end
		return true, newplayer.colorize("#FF0000",S("ERROR: "))..S("Keyword @1 not found",newplayer.colorize("#00FFFF",param))
	end}
)

minetest.register_chatcommand("spawn",{
	params = "",
	description = S("Teleport to the spawn"),
	privs = {teleport=true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		local hasinteract = minetest.check_player_privs(name,{interact=true})
		if hasinteract then
			local pos = minetest.setting_get_pos("spawnpoint_interact")
			if pos then
				player:set_pos(pos)
				return true, S("Teleporting to spawn...")
			else
				return true, newplayer.colorize("#FF0000",S("ERROR: "))..S("The spawn point is not set!")
			end
		else
			local pos = minetest.setting_get_pos("spawnpoint_no_interact")
			if pos then
				player:set_pos(pos)
				return true, S("Teleporting to spawn...")
			else
				return true, newplayer.colorize("#FF0000",S("ERROR: "))..S("The spawn point is not set!")
			end
		end
	end}
)

minetest.register_on_chat_message(function(name, message)
	if minetest.check_player_privs(name,{interact=true}) then
		return
	end
	if message:lower():find("rules") then
		newplayer.showrulesform(name)
	elseif message:lower():find("help") then
		local fs =      "size[5,3]"..
				"label[0,0;" .. S("In order to build,") .."]"..
				"label[0,0.5;" .. S("you must read and agree to the rules.") .."]"..
				"label[0,1;" .. S("View them now?") .."]"..
				"button[0,2;2,1;yes;" .. S("Yes") .."]"..
				"button_exit[3,2;2,1;quit;" .. S("No") .."]"
		minetest.show_formspec(name,"newplayer:help",fs)
	end
end)
