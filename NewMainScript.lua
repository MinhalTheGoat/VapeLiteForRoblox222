local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end
local vapelite

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local contextActionService = cloneref(game:GetService('ContextActionService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local suc, web = pcall(function() return WebSocket.connect('ws://127.0.0.1:6892/') end)
if not suc or type(web) == 'boolean' then
	repeat
		suc, web = pcall(function() return WebSocket.connect('ws://127.0.0.1:6892/') end)
		if not suc or type(web) == 'boolean' then
			print('websocket error:', web)
		else
			break
		end
		task.wait(1)
	until suc and type(web) ~= 'boolean'
end

run(function()
	vapelite = {
		Connections = {},
		Loaded = false,
		Modules = {}
	}

	local function getTableSize(tab)
		local ind = 0
		for _ in tab do ind += 1 end
		return ind
	end

	function vapelite:UpdateTextGUI() end

	function vapelite:CreateModule(modulesettings)
		local moduleapi = {
			Enabled = false,
			Options = {},
			Connections = {},
			Name = modulesettings.Name,
			Tooltip = modulesettings.Tooltip
		}

		function moduleapi:CreateToggle(s)
			local api = {Type = 'Toggle', Enabled = false, Index = getTableSize(moduleapi.Options), Object = {Visible = s.Visible ~= false}}
			s.Function = s.Function or function() end
			function api:Toggle()
				api.Enabled = not api.Enabled
				s.Function(api.Enabled)
			end
			if s.Default then api:Toggle() end
			moduleapi.Options[s.Name] = api
			return api
		end

		function moduleapi:CreateSlider(s)
			local api = {Type = 'Slider', Value = s.Default or s.Min, Min = s.Min, Max = s.Max, Index = getTableSize(moduleapi.Options), Object = {Visible = s.Visible ~= false}}
			s.Function = s.Function or function() end
			function api:SetValue(v)
				if tonumber(v) == math.huge or v ~= v then return end
				api.Value = v
				s.Function(v)
			end
			moduleapi.Options[s.Name] = api
			return api
		end

		function moduleapi:CreateTwoSlider(s)
			local minVal = s.DefaultMin or s.Min
			local maxVal = s.DefaultMax or s.Max
			local api = {
				Type = 'Slider',
				Value = minVal,
				ValueMax = maxVal,
				Min = s.Min,
				Max = s.Max,
				Index = getTableSize(moduleapi.Options),
				Object = {Visible = s.Visible ~= false}
			}
			s.Function = s.Function or function() end
			function api:SetValue(v)
				if tonumber(v) == math.huge or v ~= v then return end
				api.Value = v
				s.Function(v)
			end
			function api.GetRandomValue()
				local lo = math.min(api.Value, api.ValueMax)
				local hi = math.max(api.Value, api.ValueMax)
				if lo == hi then return lo end
				return lo + math.random() * (hi - lo)
			end
			moduleapi.Options[s.Name] = api
			return api
		end

		function moduleapi:CreateDropdown(s)
			local api = {Type = 'Dropdown', Value = s.Default or (s.List and s.List[1]) or '', List = s.List or {}, Index = getTableSize(moduleapi.Options), Object = {Visible = s.Visible ~= false}}
			s.Function = s.Function or function() end
			function api:SetValue(v)
				api.Value = v
				s.Function(v)
			end
			moduleapi.Options[s.Name] = api
			return api
		end

		function moduleapi:CreateTargets(s)
			local api = {Type = 'Targets', Index = getTableSize(moduleapi.Options), Object = {Visible = true}}
			for k, v in s do
				local entry = {Enabled = v, Object = {Visible = true}}
				entry.Toggle = function(self) self.Enabled = not self.Enabled end
				api[k] = entry
			end
			if not api.Walls then
				api.Walls = {Enabled = false, Object = {Visible = false}, Toggle = function(self) self.Enabled = not self.Enabled end}
			end
			moduleapi.Options['Targets'] = api
			return api
		end

		function moduleapi:CreateColorSlider(s)
			local api = {Type = 'ColorSlider', Hue = s.DefaultHue or 0, Sat = 1, Value = 1, Opacity = s.DefaultOpacity or 1, Index = getTableSize(moduleapi.Options), Object = {Visible = s.Visible ~= false}}
			moduleapi.Options[s.Name] = api
			return api
		end

		function moduleapi:CreateTextBox(s)
			local api = {Type = 'TextBox', Value = s.Default or '', Index = getTableSize(moduleapi.Options), Object = {Visible = s.Visible ~= false}}
			s.Function = s.Function or function() end
			moduleapi.Options[s.Name] = api
			return api
		end

		function moduleapi:Clean(obj)
			table.insert(moduleapi.Connections, obj)
		end

		function moduleapi:Toggle()
			moduleapi.Enabled = not moduleapi.Enabled
			if not moduleapi.Enabled then
				for _, v in moduleapi.Connections do
					pcall(function()
						if typeof(v) == 'Instance' then
							v:ClearAllChildren()
							v:Destroy()
						elseif type(v) == 'function' then
							v()
						else
							v:Disconnect()
						end
					end)
				end
				table.clear(moduleapi.Connections)
			end
			task.spawn(modulesettings.Function, moduleapi.Enabled)
			vapelite:UpdateTextGUI()
		end

		vapelite.Modules[modulesettings.Name] = moduleapi
		return moduleapi
	end

	vapelite.Categories = setmetatable({}, {
		__index = function(self, cat)
			local stub = {}
			stub.CreateModule = function(_, s) return vapelite:CreateModule(s) end
			rawset(self, cat, stub)
			return stub
		end
	})

	function vapelite:Save()
		if not vapelite.Loaded then return end
		vapelite:Send({
			msg = 'writesettings',
			id = (game.PlaceId == 6872265039 and 'bedwarslobbynew' or 'bedwarsmainnew'),
			content = httpService:JSONEncode(vapelite.Modules)
		})
	end

	function vapelite:Load()
		vapelite.read = Instance.new('BindableEvent')
		vapelite:Send({
			msg = 'readsettings',
			id = (game.PlaceId == 6872265039 and 'bedwarslobbynew' or 'bedwarsmainnew')
		})

		local got, data = pcall(function() return httpService:JSONDecode(vapelite.read.Event:Wait()) end)
		if type(data) == 'table' then
			for i, v in data do
				local obj = vapelite.Modules[i]
				if obj then
					for i2, v2 in v.Options do
						local opt = obj.Options[i2]
						if opt then
							if v2.Type == 'Toggle' then
								if v2.Enabled ~= opt.Enabled then opt:Toggle() end
							elseif opt.SetValue then
								opt:SetValue(v2.Value)
							end
						end
					end
					if v.Enabled then obj:Toggle() end
				end
			end
		end

		local replicatedmodules = {}
		for i, v in vapelite.Modules do
			local newmodule = {name = i, desc = v.Tooltip, options = {}, toggled = v.Enabled}
			for i2, v2 in v.Options do
				if v2.Type == 'Slider' then
					table.insert(newmodule.options, {name = i2, type = 'Slider', state = v2.Value, min = v2.Min, max = v2.Max, index = v2.Index, visible = v2.Object.Visible})
				elseif v2.Type == 'Dropdown' then
					table.insert(newmodule.options, {name = i2, type = 'Dropdown', state = v2.Value, list = v2.List, index = v2.Index, visible = v2.Object.Visible})
				elseif v2.Type == 'ColorSlider' then
					table.insert(newmodule.options, {name = i2, type = 'ColorSlider', Hue = v2.Hue, Sat = v2.Sat, Value = v2.Value, index = v2.Index, visible = v2.Object.Visible})
				elseif v2.Type == 'Targets' then
					local targopt = {name = i2, type = 'Targets', index = v2.Index}
					for _, key in {'Players', 'NPCs', 'Walls'} do
						if v2[key] and v2[key].Object and v2[key].Object.Visible ~= false then
							targopt[key] = v2[key].Enabled
						end
					end
					table.insert(newmodule.options, targopt)
				elseif v2.Type == 'TextBox' then
					table.insert(newmodule.options, {name = i2, type = 'TextBox', state = v2.Value, index = v2.Index, visible = v2.Object.Visible})
				else
					table.insert(newmodule.options, {name = i2, type = 'Toggle', toggled = v2.Enabled, index = v2.Index, visible = v2.Object.Visible})
				end
			end
			table.sort(newmodule.options, function(a, b) return a.index < b.index end)
			table.insert(replicatedmodules, newmodule)
		end
		table.sort(replicatedmodules, function(a, b) return a.name < b.name end)

		vapelite.Loaded = true
		vapelite:Send({msg = 'connectrequest', modules = replicatedmodules})
	end

	function vapelite:Send(data)
		if suc and web then
			pcall(function() web:Send(httpService:JSONEncode(data)) end)
		end
	end

	function vapelite.Receive(data)
		local ok, d = pcall(function() return httpService:JSONDecode(data) end)
		if not ok then return end

		if d.msg == 'togglemodule' then
			local module = vapelite.Modules[d.module]
			if module and d.state ~= module.Enabled then module:Toggle() end
		elseif d.msg == 'togglebuttontoggle' then
			local option = vapelite.Modules[d.module] and vapelite.Modules[d.module].Options[d.setting]
			if option then
				if option.Type == 'Toggle' then
					if option.Enabled ~= d.state then option:Toggle() end
				elseif option.Type == 'Targets' then
					local sub = option[d.setting]
					if sub then sub.Enabled = d.state end
				end
			end
		elseif d.msg == 'togglebuttonslider' then
			local option = vapelite.Modules[d.module] and vapelite.Modules[d.module].Options[d.setting]
			if option and option.SetValue then option:SetValue(d.state) end
		elseif d.msg == 'togglebuttondropdown' then
			local option = vapelite.Modules[d.module] and vapelite.Modules[d.module].Options[d.setting]
			if option and option.SetValue then option:SetValue(d.state) end
		elseif d.msg == 'togglebuttontextbox' then
			local option = vapelite.Modules[d.module] and vapelite.Modules[d.module].Options[d.setting]
			if option then option.Value = d.state end
		elseif d.msg == 'readsettings' then
			if vapelite.read then
				vapelite.read:Fire(d.result)
				vapelite.read:Destroy()
			end
		end

		if d.msg ~= 'readsettings' then vapelite:Save() end
	end

	function vapelite.Uninject(tp)
		if web then pcall(function() web:Disconnect() end) end
		vapelite:Save()
		vapelite.Loaded = nil
		for _, v in vapelite.Modules do if v.Enabled then v:Toggle() end end
		for _, v in vapelite.Connections do pcall(function() v:Disconnect() end) end
		shared.vapelite = nil
		if tp then return end
		task.spawn(function()
			repeat task.wait() until game:IsLoaded()
			repeat task.wait(5) until isfile('vapelite.injectable.txt')
			delfile('vapelite.injectable.txt')
			loadstring(readfile('vapelite.lua'))()
		end)
	end

	shared.vapelite = vapelite.Uninject
end)

run(function()
	if game.GameId ~= 2619619496 then return end

	local KnitGotten, KnitClient
	repeat
		KnitGotten, KnitClient = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitGotten then break end
		task.wait()
	until KnitGotten

	if not debug.getupvalue(KnitClient.Start, 1) then
		repeat task.wait() until debug.getupvalue(KnitClient.Start, 1)
	end

	local Client = require(replicatedStorage.TS.remotes).default.Client

	run(function()
		local Sprint
		local oldSprint = KnitClient.Controllers.SprintController.stopSprinting
		Sprint = vapelite:CreateModule({
			Name = 'Sprint',
			Function = function(callback)
				local sc = KnitClient.Controllers.SprintController
				if callback then
					sc.stopSprinting = function(self, ...)
						local r = oldSprint(self, ...)
						sc:startSprinting()
						return r
					end
					sc:stopSprinting()
				else
					sc.stopSprinting = oldSprint
					sc:stopSprinting()
				end
			end,
			Tooltip = 'always sprinting no cap'
		})
	end)

	if game.PlaceId == 6872265039 then return end

	local store = {
		attackReach = 0,
		attackReachUpdate = tick(),
		hand = {},
		KillauraTarget = nil,
		tools = {},
		inventory = {inventory = {items = {}, armor = {}}, hotbar = {}}
	}

	local Reach = {}
	local HitBoxes = {}

	local entitylib = {
		isAlive = false,
		character = {},
		List = {},
		Events = setmetatable({}, {
			__index = function(self, index)
				local ev = {Connections = {}}
				ev.Connect = function(ev2, func)
					table.insert(ev2.Connections, func)
					return {Disconnect = function()
						local i = table.find(ev2.Connections, func)
						if i then table.remove(ev2.Connections, i) end
					end}
				end
				ev.Fire = function(ev2, ...)
					for _, v in ev2.Connections do task.spawn(v, ...) end
				end
				ev.Destroy = function(ev2) table.clear(ev2.Connections) end
				self[index] = ev
				return ev
			end
		})
	}

	entitylib.AllPosition = function(params)
		if not entitylib.isAlive then return {} end
		local lteam = lplr:GetAttribute('Team')
		local range = params.Range or 20
		local selfpos = entitylib.character.RootPart.Position
		local results = {}
		for _, v in entitylib.List do
			if not v.Character or not v.RootPart then continue end
			if v.Player and v.Player:GetAttribute('Team') == lteam then continue end
			if v.Health <= 0 then continue end
			if (v.RootPart.Position - selfpos).Magnitude > range then continue end
			if params.Wallcheck then
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = {lplr.Character}
				local ray = workspace:Raycast(selfpos, v.RootPart.Position - selfpos, rp)
				if ray and not ray.Instance:IsDescendantOf(v.Character) then continue end
			end
			table.insert(results, v)
			if #results >= (params.Limit or 999) then break end
		end
		if params.Sort then
			local wrapped = {}
			for _, v in results do table.insert(wrapped, {Entity = v}) end
			table.sort(wrapped, params.Sort)
			results = {}
			for _, v in wrapped do table.insert(results, v.Entity) end
		end
		return results
	end

	entitylib.EntityPosition = function(params)
		return entitylib.AllPosition(params)[1]
	end

	local sortmethods = {
		Damage = function(a, b)
			return (a.Entity.Character:GetAttribute('LastDamageTakenTime') or 0) < (b.Entity.Character:GetAttribute('LastDamageTakenTime') or 0)
		end,
		Distance = function(a, b)
			if not entitylib.isAlive then return false end
			local pos = entitylib.character.RootPart.Position
			return (a.Entity.RootPart.Position - pos).Magnitude < (b.Entity.RootPart.Position - pos).Magnitude
		end,
		Health = function(a, b)
			return a.Entity.Health < b.Entity.Health
		end,
		Angle = function(a, b)
			local selfpos = entitylib.character.RootPart.Position
			local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			local angleA = math.acos(math.clamp(localfacing:Dot(((a.Entity.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)).Unit), -1, 1))
			local angleB = math.acos(math.clamp(localfacing:Dot(((b.Entity.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)).Unit), -1, 1))
			return angleA < angleB
		end
	}

	local inventoryEvent = Instance.new('BindableEvent')
	local swingEvent = Instance.new('BindableEvent')
	local Attacking
	local Particles, Boxes = {}, {}
	local AnimDelay, AnimTween, armC0 = tick()
	local AttackRemote = {FireServer = function() end}
	local bedwars = {}
	local attackRemoteInstance = nil

	-- switchItem: switches to hotbar slot containing the given tool
	local function switchItem(tool, delay)
		for slot, item in store.inventory.hotbar do
			if item and item.item and item.item.tool == tool then
				if store.inventory.hotbarSlot ~= (slot - 1) then
					bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = slot - 1})
					inventoryEvent.Event:Wait()
				end
				if delay and delay > 0 then task.wait(delay) end
				return true
			end
		end
	end

	-- safeCall: safely calls a function with pcall
	local function safeCall(func) pcall(func) end

	-- targetinfo: tracks targets for killaura
	local targetinfo = {Targets = {}}

	local function getEntitiesNear(range)
		if entitylib.isAlive then
			local localpos, lteam = entitylib.character.RootPart.Position, lplr:GetAttribute('Team')
			local returned, mag = nil, range
			for _, v in entitylib.List do
				if v.Player:GetAttribute('Team') ~= lteam and v.Health > 0 then
					local newmag = (v.RootPart.Position - localpos).Magnitude
					if newmag <= mag then
						returned, mag = v, newmag
					end
				end
			end
			return returned
		end
	end

	local function hotbarSwitch(slot)
		if slot and store.inventory.hotbarSlot ~= slot then
			bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = slot})
			inventoryEvent.Event:Wait()
			return true
		end
		return false
	end

	run(function()
		local function dumpRemote(tab)
			local ind
			for i, v in tab do
				if v == 'Client' then ind = i break end
			end
			return ind and tab[ind + 1] or ''
		end

		local attackRemoteName = dumpRemote(debug.getconstants(KnitClient.Controllers.SwordController.sendServerRequest))
		local pickupRemoteName = dumpRemote(debug.getconstants(KnitClient.Controllers.ItemDropController.checkForPickup))

		local OldGet = Client.Get

		local combatConstant = nil
		pcall(function()
			combatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant
		end)

		bedwars = setmetatable({
			AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
			AttackRemote = attackRemoteName,
			BlockBreaker = KnitClient.Controllers.BlockBreakController.blockBreaker,
			Client = Client,
			ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
			KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
			PickupRemote = pickupRemoteName,
			QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
			SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
			SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
			Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
			UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
			CombatConstant = combatConstant
		}, {
			__index = function(self, ind)
				rawset(self, ind, KnitClient.Controllers[ind])
				return rawget(self, ind)
			end
		})

		task.spawn(function()
			local ok, r = pcall(function() return Client:Get(attackRemoteName) end)
			if ok and r then
				attackRemoteInstance = r
			end
		end)

		Client.Get = function(self, remoteName)
			local call = OldGet(self, remoteName)
			if remoteName == attackRemoteName then
				return {
					instance = call.instance,
					SendToServer = function(_, attackTable, ...)
						local selfpos = attackTable.validate.selfPosition.value
						local targetpos = attackTable.validate.targetPosition.value
						store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
						store.attackReachUpdate = tick() + 1
						if Reach.Enabled or HitBoxes.Enabled then
							attackTable.validate.raycast = attackTable.validate.raycast or {}
							attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
						end
						return call:SendToServer(attackTable, ...)
					end
				}
			end
			return call
		end

		local function getSword()
			local best, bestSlot, bestDmg = nil, nil, 0
			for slot, item in store.inventory.inventory.items do
				local m = bedwars.ItemMeta[item.itemType]
				if m and m.sword and m.sword.damage > bestDmg then
					best, bestSlot, bestDmg = item, slot, m.sword.damage
				end
			end
			return best, bestSlot
		end

		local function getTool(breakType)
			local best, bestSlot, bestDmg = nil, nil, 0
			for slot, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				local m = meta and meta.breakBlock
				if m then
					local dmg = m[breakType] or 0
					if dmg > bestDmg then best, bestSlot, bestDmg = item, slot, dmg end
				end
			end
			return best, bestSlot
		end

		local function updateStore(new, old)
			if new.Inventory ~= old.Inventory then
				local ni = new.Inventory and new.Inventory.observedInventory or {inventory = {}}
				local oi = old.Inventory and old.Inventory.observedInventory or {inventory = {}}
				store.inventory = ni
				if ni ~= oi then inventoryEvent:Fire() end
				if ni.inventory and ni.inventory.items ~= (oi.inventory and oi.inventory.items) then
					store.tools.sword = getSword()
					for _, v in {'stone', 'wood', 'wool'} do store.tools[v] = getTool(v) end
				end
				if ni.inventory and ni.inventory.hand ~= (oi.inventory and oi.inventory.hand) then
					local h = ni.inventory.hand
					local ht = ''
					if h then
						local hd = bedwars.ItemMeta[h.itemType]
						if hd then
							ht = hd.sword and 'sword' or hd.block and 'block' or (h.itemType:find('bow') and 'bow' or '')
						end
					end
					store.hand = {tool = h and h.tool, toolType = ht, amount = h and h.amount or 0}
				end
			end
		end

		local storeChanged = bedwars.Store.changed:connect(updateStore)
		updateStore(bedwars.Store:getState(), {})

		local function addEntity(char)
			repeat task.wait() until char.PrimaryPart
			local rp = char.PrimaryPart
			local head = char:WaitForChild('Head', 10)
			local hum = char:WaitForChild('Humanoid', 10)
			if not hum or not head or vapelite.Loaded == nil then return end
			local plr = playersService:GetPlayerFromCharacter(char)
			if not plr then return end

			local entity = {
				Connections = {},
				Character = char,
				Health = char:GetAttribute('Health') or hum.Health,
				Head = head,
				Humanoid = hum,
				HumanoidRootPart = rp,
				HipHeight = hum.HipHeight + (rp.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
				MaxHealth = char:GetAttribute('MaxHealth') or hum.MaxHealth,
				Player = plr,
				RootPart = rp,
				Targetable = plr ~= lplr and lplr:GetAttribute('Team') ~= plr:GetAttribute('Team')
			}

			if plr == lplr then
				entitylib.character = entity
				entitylib.isAlive = true
				entitylib.Events.LocalAdded:Fire(entity)
			else
				table.insert(entitylib.List, entity)
				for _, attr in {'Health', 'MaxHealth'} do
					table.insert(entity.Connections, char:GetAttributeChangedSignal(attr):Connect(function()
						entity.Health = char:GetAttribute('Health') or 100
						entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
						entitylib.Events.EntityUpdated:Fire(entity)
					end))
				end
				table.insert(entity.Connections, plr:GetAttributeChangedSignal('Team'):Connect(function()
					entity.Targetable = lplr:GetAttribute('Team') ~= plr:GetAttribute('Team')
				end))
				table.insert(entity.Connections, lplr:GetAttributeChangedSignal('Team'):Connect(function()
					entity.Targetable = lplr:GetAttribute('Team') ~= plr:GetAttribute('Team')
				end))
				entitylib.Events.EntityAdded:Fire(entity)
			end
		end

		local swingHook = KnitClient.Controllers.SwordController.swingSwordAtMouse
		KnitClient.Controllers.SwordController.swingSwordAtMouse = function(...)
			swingEvent:Fire(select(2, ...))
			return swingHook(...)
		end

		table.insert(vapelite.Connections, collectionService:GetInstanceAddedSignal('inventory-entity'):Connect(addEntity))
		table.insert(vapelite.Connections, collectionService:GetInstanceRemovedSignal('inventory-entity'):Connect(function(char)
			local plr = playersService:GetPlayerFromCharacter(char)
			if plr == lplr then
				entitylib.isAlive = false
				entitylib.Events.LocalRemoved:Fire()
			else
				for i, v in entitylib.List do
					if v.Player == plr then
						for _, c in v.Connections do pcall(function() c:Disconnect() end) end
						table.clear(v.Connections)
						table.remove(entitylib.List, i)
						entitylib.Events.EntityRemoved:Fire(v)
						break
					end
				end
			end
		end))

		for _, v in collectionService:GetTagged('inventory-entity') do
			task.spawn(addEntity, v)
		end

		table.insert(vapelite.Connections, {Disconnect = function()
			pcall(function() KnitClient.Controllers.SwordController.swingSwordAtMouse = swingHook end)
			pcall(function() Client.Get = OldGet end)
			pcall(function() storeChanged:disconnect() end)
			pcall(function() swingEvent:Destroy() end)
			pcall(function() inventoryEvent:Destroy() end)
			for _, v in entitylib.List do
				for _, c in v.Connections do pcall(function() c:Disconnect() end) end
				table.clear(v.Connections)
			end
			table.clear(entitylib.List)
			table.clear(entitylib)
			table.clear(store)
			table.clear(bedwars)
		end})
	end)

	run(function()
		local TextGUI
		local Sort = {Value = 1}
		local Font = {Value = 1}
		local Size = {Value = 20}
		local Shadow = {Enabled = true}
		local Watermark = {Enabled = true}
		local Rainbow = {Enabled = false}
		local VapeLabels = {}
		local VapeShadowLabels = {}

		local VapeLiteLogo = Drawing.new('Image')
		pcall(function()
			VapeLiteLogo.Data = game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/VapeLiteForRoblox/main/VapeLiteLogo.png', true)
		end)
		VapeLiteLogo.Size = Vector2.new(140, 64)
		VapeLiteLogo.ZIndex = 2
		VapeLiteLogo.Visible = false

		local VapeLiteLogoShadow = Drawing.new('Image')
		pcall(function()
			VapeLiteLogoShadow.Data = game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/VapeLiteForRoblox/main/VapeLiteLogoShadow.png', true)
		end)
		VapeLiteLogoShadow.Size = Vector2.new(140, 64)
		VapeLiteLogoShadow.ZIndex = 1
		VapeLiteLogoShadow.Visible = false

		local function getDrawingFont(idx)
			return math.clamp(math.floor(idx) - 1, 0, 3)
		end

		local function getTextSize(str, fontIdx, sz)
			local obj = Drawing.new('Text')
			obj.Text = str
			obj.Size = sz or 20
			obj.Font = getDrawingFont(fontIdx or 1)
			local res = obj.TextBounds
			pcall(function() obj.Visible = false; obj:Remove() end)
			return res
		end

		function vapelite:UpdateTextGUI()
			local enabled = TextGUI and TextGUI.Enabled
			VapeLiteLogo.Visible = enabled and Watermark.Enabled
			VapeLiteLogoShadow.Visible = enabled and Watermark.Enabled and Shadow.Enabled
			if enabled then
				VapeLiteLogo.Position = Vector2.new(gameCamera.ViewportSize.X - 160, 52)
				VapeLiteLogoShadow.Position = VapeLiteLogo.Position + Vector2.new(1, 1)
			end
			for _, v in VapeLabels do pcall(function() v.Visible = false; v:Remove() end) end
			for _, v in VapeShadowLabels do pcall(function() v.Visible = false; v:Remove() end) end
			table.clear(VapeLabels)
			table.clear(VapeShadowLabels)
			if not enabled then return end

			local modulelist = {}
			for i, v in vapelite.Modules do
				if i ~= 'TextGUI' and v.Enabled then
					table.insert(modulelist, {Text = i, Size = getTextSize(i, Font.Value, Size.Value)})
				end
			end
			if Sort.Value == 1 then
				table.sort(modulelist, function(a, b) return a.Size.X > b.Size.X end)
			else
				table.sort(modulelist, function(a, b) return a.Text < b.Text end)
			end

			local startX = gameCamera.ViewportSize.X - 20
			local startY = 52 + 64
			local newY = 0
			for i, v in modulelist do
				local draw = Drawing.new('Text')
				draw.Position = Vector2.new(startX - v.Size.X, startY + newY)
				draw.Color = Rainbow.Enabled and Color3.fromHSV((tick()/4 + i*-0.05) % 1, 0.89, 1) or Color3.fromRGB(67, 117, 255)
				draw.Text = v.Text
				draw.Size = Size.Value
				draw.Font = getDrawingFont(Font.Value)
				draw.ZIndex = 2
				draw.Visible = true
				table.insert(VapeLabels, draw)
				if Shadow.Enabled then
					local ds = Drawing.new('Text')
					ds.Position = draw.Position + Vector2.new(1, 1)
					ds.Color = Color3.fromRGB(22, 37, 81)
					ds.Text = v.Text
					ds.Size = draw.Size
					ds.Font = draw.Font
					ds.ZIndex = 1
					ds.Visible = true
					table.insert(VapeShadowLabels, ds)
				end
				newY += v.Size.Y
			end
		end

		TextGUI = vapelite:CreateModule({
			Name = 'TextGUI',
			Function = function(callback)
				if callback then
					TextGUI:Clean(gameCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
						vapelite:UpdateTextGUI()
					end))
					if Rainbow.Enabled then
						TextGUI:Clean(runService.RenderStepped:Connect(function()
							for i, v in VapeLabels do
								v.Color = Color3.fromHSV((tick()/4 + i*-0.05) % 1, 0.89, 1)
							end
						end))
					end
				end
				vapelite:UpdateTextGUI()
			end,
			Tooltip = 'shows enabled modules on screen'
		})
		Sort = TextGUI:CreateSlider({Name = 'Sort', Min = 1, Max = 2, Default = 1, Function = function() vapelite:UpdateTextGUI() end})
		Font = TextGUI:CreateSlider({Name = 'Font', Min = 1, Max = 4, Default = 1, Function = function() vapelite:UpdateTextGUI() end})
		Size = TextGUI:CreateSlider({Name = 'Text Size', Min = 8, Max = 36, Default = 20, Function = function() vapelite:UpdateTextGUI() end})
		Shadow = TextGUI:CreateToggle({Name = 'Shadow', Default = true, Function = function() vapelite:UpdateTextGUI() end})
		Watermark = TextGUI:CreateToggle({Name = 'Watermark', Default = true, Function = function() vapelite:UpdateTextGUI() end})
		Rainbow = TextGUI:CreateToggle({
			Name = 'Rainbow',
			Function = function(cb)
				if TextGUI.Enabled then TextGUI:Toggle() TextGUI:Toggle() end
			end
		})
	end)

	run(function()
		local TriggerBot
		local CPS
		local ProjectileMode
		local ProjectileFireRate
		local ProjectileWaitDelay
		local ProjectileFirstPerson
		local rayParams = RaycastParams.new()
		local lastProjectileShot = 0
		local wasHoldingProjectile = false
		local VirtualInputManager = game:GetService("VirtualInputManager")
		local tick = tick
		local task_wait = task.wait
		local pcall = pcall
		local lastClickTime = 0
		local clickCooldown = 0.015

		local function leftClick()
			local now = tick()
			if now - lastClickTime < clickCooldown then return false end
			local success = pcall(function()
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
				task_wait(0.02)
				VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
			end)
			if success then lastClickTime = now end
			return success
		end

		local lastFPCheck = 0
		local cachedFPResult = false
		local function isFirstPerson()
			local now = tick()
			if now - lastFPCheck < 0.1 then return cachedFPResult end
			lastFPCheck = now
			cachedFPResult = gameCamera.CFrame.Position.Magnitude - (gameCamera.Focus.Position).Magnitude < 1
			return cachedFPResult
		end

		local lastProjectileCheck = 0
		local cachedProjectileResult = false
		local lastHotbarSlot = -1
		local function isHoldingProjectile()
			if not entitylib.isAlive then cachedProjectileResult = false return false end
			local currentSlot = store.inventory.hotbarSlot
			if currentSlot == lastHotbarSlot and (tick() - lastProjectileCheck) < 0.2 then return cachedProjectileResult end
			lastHotbarSlot = currentSlot
			lastProjectileCheck = tick()
			local slotItem = store.inventory.hotbar[currentSlot + 1]
			if slotItem and slotItem.item and slotItem.item.itemType then
				local itemMeta = bedwars.ItemMeta[slotItem.item.itemType]
				if itemMeta and itemMeta.projectileSource then
					local projectileSource = itemMeta.projectileSource
					if projectileSource.ammoItemTypes and table.find(projectileSource.ammoItemTypes, 'arrow') then
						cachedProjectileResult = true
						return true
					end
				end
			end
			cachedProjectileResult = false
			return false
		end

		local cachedSwordRange = nil
		local lastSwordTool = nil

		TriggerBot = vapelite:CreateModule({
			Name = 'TriggerBot',
			Function = function(callback)
				if callback then
					local frameCounter = 0
					local lastToolType = nil
					repeat
						frameCounter = frameCounter + 1
						local doAttack = false
						local holdingProjectile = isHoldingProjectile()
						if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) and entitylib.isAlive then
							if ProjectileMode.Enabled and holdingProjectile then
								if ProjectileFirstPerson.Enabled and not isFirstPerson() then
									wasHoldingProjectile = false
								else
									if holdingProjectile and not wasHoldingProjectile then
										task_wait(ProjectileWaitDelay.Value)
										leftClick()
										lastProjectileShot = tick()
										wasHoldingProjectile = true
									elseif holdingProjectile then
										local currentTime = tick()
										if (currentTime - lastProjectileShot) >= ProjectileFireRate.Value then
											leftClick()
											lastProjectileShot = currentTime
										end
									else
										wasHoldingProjectile = false
									end
								end
							elseif store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
								local currentTool = store.hand.tool
								if currentTool ~= lastSwordTool then
									lastSwordTool = currentTool
									local itemMeta = bedwars.ItemMeta[currentTool.Name]
									cachedSwordRange = itemMeta and itemMeta.sword and itemMeta.sword.attackRange or 14.4
								end
								local attackRange = cachedSwordRange or 14.4
								if frameCounter % 2 == 0 then
									rayParams.FilterDescendantsInstances = {lplr.Character}
									local unit = lplr:GetMouse().UnitRay
									local localPos = entitylib.character.RootPart.Position
									local rayRange = attackRange
									local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
									if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
										local entityList = entitylib.List
										for i = 1, #entityList do
											local ent = entityList[i]
											doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
											if doAttack then break end
										end
									end
								end
								if not doAttack then
									doAttack = bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
								end
								if doAttack then
									bedwars.SwordController:swingSwordAtMouse()
								end
							else
								wasHoldingProjectile = false
							end
						end
						if doAttack and not holdingProjectile then
							task_wait(1 / CPS.GetRandomValue())
						else
							task_wait(holdingProjectile and 0.033 or 0.05)
						end
					until not TriggerBot.Enabled
				else
					cachedSwordRange = nil
					lastSwordTool = nil
					lastHotbarSlot = -1
					wasHoldingProjectile = false
				end
			end,
			Tooltip = 'Automatically swings when hovering over a entity'
		})

		CPS = TriggerBot:CreateTwoSlider({Name = 'CPS', Min = 1, Max = 9, DefaultMin = 7, DefaultMax = 7})
		ProjectileMode = TriggerBot:CreateToggle({Name = 'Projectile Mode', Tooltip = 'Auto-shoots crossbow/bow when holding projectile weapon'})
		ProjectileFireRate = TriggerBot:CreateSlider({Name = 'Projectile Fire Rate', Min = 0.1, Max = 3, Default = 1.2, Decimal = 10, Suffix = function(val) return val == 1 and 'second' or 'seconds' end, Tooltip = 'How fast to auto-fire'})
		ProjectileWaitDelay = TriggerBot:CreateSlider({Name = 'Projectile Wait Delay', Min = 0, Max = 1, Default = 0, Decimal = 100, Suffix = 's', Tooltip = 'Delay before shooting'})
		ProjectileFirstPerson = TriggerBot:CreateToggle({Name = 'Projectile First Person Only', Default = false, Tooltip = 'Only works in first person mode'})
	end)

	run(function()
		local ReachModule
		local Attack
		local Mine
		local Place
		local oldAttackReach, oldMineReach
		local oldIsAllowedPlacement

		ReachModule = vapelite:CreateModule({
			Name = 'Reach',
			Function = function(callback)
				if callback then
					oldAttackReach = bedwars.CombatConstant and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
					if bedwars.CombatConstant then
						bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
					end
					task.spawn(function()
						repeat task.wait(0.1) until bedwars.BlockBreakController or not ReachModule.Enabled
						if not ReachModule.Enabled then return end
						pcall(function()
							local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
							if blockBreaker then
								oldMineReach = oldMineReach or blockBreaker:getRange()
								blockBreaker:setRange(Mine.Value)
							end
						end)
					end)
					task.spawn(function()
						repeat task.wait(0.1) until bedwars.BlockEngine or not ReachModule.Enabled
						if not ReachModule.Enabled then return end
						pcall(function()
							if not oldIsAllowedPlacement then
								oldIsAllowedPlacement = bedwars.BlockEngine.isAllowedPlacement
								bedwars.BlockEngine.isAllowedPlacement = function(self, player, blockType, position, rotation, mouseBlockInfo)
									local result = oldIsAllowedPlacement(self, player, blockType, position, rotation, mouseBlockInfo)
									if not result and player == lplr then
										local blockExists = self:getStore():getBlockAt(position)
										if not blockExists then return true end
									end
									return result
								end
							end
						end)
					end)
					task.spawn(function()
						repeat task.wait(0.1) until bedwars.BlockPlacementController or not ReachModule.Enabled
						if not ReachModule.Enabled then return end
						pcall(function()
							local blockPlacer = bedwars.BlockPlacementController:getBlockPlacer()
							if blockPlacer and blockPlacer.blockHighlighter then
								blockPlacer.blockHighlighter:setRange(Place.Value)
								blockPlacer.blockHighlighter.range = Place.Value
							end
						end)
					end)
					task.spawn(function()
						while ReachModule.Enabled do
							if bedwars.CombatConstant and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE ~= Attack.Value + 2 then
								bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
							end
							pcall(function()
								local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
								if blockBreaker and blockBreaker:getRange() ~= Mine.Value then blockBreaker:setRange(Mine.Value) end
							end)
							pcall(function()
								local blockPlacer = bedwars.BlockPlacementController:getBlockPlacer()
								if blockPlacer and blockPlacer.blockHighlighter then
									if blockPlacer.blockHighlighter.range ~= Place.Value then
										blockPlacer.blockHighlighter:setRange(Place.Value)
										blockPlacer.blockHighlighter.range = Place.Value
									end
								end
							end)
							task.wait(0.5)
						end
					end)
				else
					if bedwars.CombatConstant then
						bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach or 14.4
					end
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then blockBreaker:setRange(oldMineReach or 18) end
					end)
					pcall(function()
						local blockPlacer = bedwars.BlockPlacementController:getBlockPlacer()
						if blockPlacer and blockPlacer.blockHighlighter then
							blockPlacer.blockHighlighter:setRange(18)
							blockPlacer.blockHighlighter.range = 18
						end
					end)
					if oldIsAllowedPlacement then
						pcall(function() bedwars.BlockEngine.isAllowedPlacement = oldIsAllowedPlacement end)
					end
					oldAttackReach, oldMineReach, oldIsAllowedPlacement = nil, nil, nil
				end
			end,
			Tooltip = 'extends reach for attacking, mining, and placing'
		})

		Reach = ReachModule
		Attack = ReachModule:CreateSlider({Name = 'attack range', Min = 0, Max = 20, Default = 18, Function = function(val) if ReachModule.Enabled and bedwars.CombatConstant then bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2 end end, Suffix = function(val) return val == 1 and 'stud' or 'studs' end})
		Mine = ReachModule:CreateSlider({Name = 'mine range', Min = 0, Max = 30, Default = 18, Function = function(val) if ReachModule.Enabled then pcall(function() local bb = bedwars.BlockBreakController:getBlockBreaker() if bb then bb:setRange(val) end end) end end, Suffix = function(val) return val == 1 and 'stud' or 'studs' end})
		Place = ReachModule:CreateSlider({Name = 'place range', Min = 0, Max = 30, Default = 18, Function = function(val) if ReachModule.Enabled then pcall(function() local bp = bedwars.BlockPlacementController:getBlockPlacer() if bp and bp.blockHighlighter then bp.blockHighlighter:setRange(val) bp.blockHighlighter.range = val end end) end end, Suffix = function(val) return val == 1 and 'stud' or 'studs' end})
	end)

	-- GrandKillaura - adapted from original vape killaura for vapelite
	local Attacking
	run(function()
		local Killaura
		local SwingRange
		local AttackRange
		local MaxTargets
		local Mouse
		local Swing
		local GUI
		local SophiaCheck
		local Limit
		local LegitAura = {}
		-- AnimDelay replaces vape.Libraries.auraanims (animation timing only, no arm animation library needed)
		local AnimDelay = tick()
		local lastFiredSwing = 0
		local swingCooldown = 0

		-- Cache the attack remote once bedwars is ready (replaces bedwars.Client:Get(remotes.AttackEntity).instance)
		local cachedAttackRemote = nil
		task.spawn(function()
			repeat task.wait() until bedwars and bedwars.Client and bedwars.AttackRemote
			cachedAttackRemote = bedwars.Client:Get(bedwars.AttackRemote)
		end)

		local function flatAngle(selfpos, targetpos, facing)
			local flat = (targetpos - selfpos) * Vector3.new(1, 0, 1)
			if flat.Magnitude < 0.001 then return 0 end
			return math.acos(math.clamp(facing:Dot(flat.Unit), -1, 1))
		end

		local function flatFacing(rootCFrame)
			local lv = rootCFrame.LookVector * Vector3.new(1, 0, 1)
			if lv.Magnitude < 0.001 then return rootCFrame.RightVector * Vector3.new(1, 0, 1) end
			return lv.Unit
		end

		local function calculatePosition(selfpos, actualRoot)
			return CFrame.lookAt(actualRoot.Position, selfpos).LookVector * math.max((selfpos - actualRoot.Position).Magnitude / 10, 0)
		end

		local function isInView(rootPart)
			local pos, vis = gameCamera:WorldToViewportPoint(rootPart.Position)
			return vis
		end

		-- isFrozen replacement: checks for Sophia freeze without vape's isFrozen function
		local function isFrozenCheck()
			if not entitylib.isAlive then return false end
			local char = entitylib.character.Character
			if not char then return false end
			local hasIceBlock = char:FindFirstChild('IceBlock') or char:FindFirstChild('FrozenBlock') or char:FindFirstChild('IceShell')
			local coldStacks = char:GetAttribute('ColdStacks') or char:GetAttribute('FrostStacks') or char:GetAttribute('FreezeStacks') or 0
			local humanoid = char:FindFirstChildOfClass('Humanoid')
			if humanoid and humanoid.WalkSpeed <= 2 then return true end
			return hasIceBlock ~= nil or coldStacks >= 10
		end

		local function getAttackData()
			if SophiaCheck and SophiaCheck.Enabled then
				if isFrozenCheck() then return false end
			end
			if Mouse and Mouse.Enabled then
				local mousePressed = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
				if not mousePressed then return false end
			end
			if GUI and GUI.Enabled then
				if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
			end
			local sword = (Limit and Limit.Enabled) and store.hand or store.tools.sword
			if not sword or not sword.tool then return false end
			local meta = bedwars.ItemMeta[sword.tool.Name]
			if not meta or not meta.sword then return false end
			if Limit and Limit.Enabled then
				if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
			end
			if LegitAura and LegitAura.Enabled then
				if (tick() - (bedwars.SwordController.lastSwing or 0)) > 0.11 then
					return false
				end
			end
			return sword, meta
		end

		-- vapelite:CreateModule replaces vape.Categories.Blatant:CreateModule
		Killaura = vapelite:CreateModule({
			Name = 'GrandKillaura',
			Function = function(callback)
				if callback then
					if inputService.TouchEnabled then
						pcall(function()
							lplr.PlayerGui.MobileUI['2'].Visible = Limit and Limit.Enabled
						end)
					end

					repeat
						if SophiaCheck and SophiaCheck.Enabled then
							if isFrozenCheck() then
								Attacking = false
								store.KillauraTarget = nil
								task.wait(0.3)
								continue
							end
						end

						local attacked, sword, meta = {}, getAttackData()
						Attacking = false
						store.KillauraTarget = nil

						if sword then
							local plrs = entitylib.AllPosition({
								Range = SwingRange.Value,
								Wallcheck = true,
								Part = 'RootPart',
								Players = true,
								NPCs = true,
								Limit = MaxTargets.Value,
								Sort = sortmethods['Distance']
							})

							if #plrs > 0 then
								switchItem(sword.tool, 0)
								local selfpos = entitylib.character.RootPart.Position

								for _, v in plrs do
									local delta = (v.RootPart.Position - selfpos)

									if not isInView(v.RootPart) then continue end

									targetinfo.Targets[v] = tick() + 1 - 0.005

									if not Attacking then
										Attacking = true
										store.KillauraTarget = v
										if not (Swing and Swing.Enabled) and AnimDelay < tick() and not (LegitAura and LegitAura.Enabled) then
											local effectDelay = meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.11
											AnimDelay = tick() + effectDelay
											-- playSwordEffect replaces vape's sword swing animation
											pcall(function()
												bedwars.SwordController:playSwordEffect(meta, false)
												if meta.displayName:find(' Scythe') then
													bedwars.ScytheController:playLocalAnimation()
												end
											end)
											-- safeCall/vape.ThreadFix not needed in vapelite
											safeCall(function() end)
										end
									end

									if delta.Magnitude > AttackRange.Value then continue end
									if (tick() - swingCooldown) < 0.14 then continue end

									local actualRoot = v.Character.PrimaryPart
									if not actualRoot then continue end

									local calc = calculatePosition(selfpos, actualRoot)
									local dir = CFrame.lookAt(selfpos, actualRoot.Position + calc).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									swingCooldown = tick()

									if LegitAura and LegitAura.Enabled then
										lastFiredSwing = bedwars.SwordController.lastSwing or 0
									end

									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									bedwars.SwordController.lastSwingServerTime = workspace:GetServerTimeNow() - tick()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick()

									-- cachedAttackRemote:SendToServer replaces AttackRemote:FireServer
									if cachedAttackRemote then
										cachedAttackRemote:SendToServer({
											weapon = sword.tool,
											chargedAttack = {chargeRatio = 0},
											lastSwingServerTimeDelta = 0.5,
											entityInstance = v.Character,
											validate = {
												raycast = {
													cameraPosition = {value = pos + Vector3.new(0, 2, 0)},
													cursorDirection = {value = dir}
												},
												targetPosition = {value = actualRoot.Position + calc},
												selfPosition = {value = pos + Vector3.new(0, 1, 0)}
											}
										})
									end
								end
							end
						end

						task.wait(1 / 60)
					until not Killaura.Enabled
				else
					store.KillauraTarget = nil
					if inputService.TouchEnabled then
						pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = true end)
					end
					Attacking = false
				end
			end,
			Tooltip = 'Attack players around you\nwithout aiming at them.'
		})

		SwingRange = Killaura:CreateSlider({
			Name = 'Swing range', Min = 1, Max = 18, Default = 18,
			Suffix = function(val) return val == 1 and 'stud' or 'studs' end
		})
		AttackRange = Killaura:CreateSlider({
			Name = 'Attack range', Min = 1, Max = 18, Default = 18,
			Suffix = function(val) return val == 1 and 'stud' or 'studs' end
		})
		MaxTargets = Killaura:CreateSlider({Name = 'Max targets', Min = 1, Max = 5, Default = 5})
		Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
		Swing = Killaura:CreateToggle({Name = 'No Swing'})
		GUI = Killaura:CreateToggle({Name = 'GUI check'})
		Limit = Killaura:CreateToggle({
			Name = 'Limit to items',
			Function = function(callback)
				if inputService.TouchEnabled and Killaura.Enabled then
					pcall(function() lplr.PlayerGui.MobileUI['2'].Visible = callback end)
				end
			end,
			Tooltip = 'Only attacks when the sword is held'
		})
		LegitAura = Killaura:CreateToggle({
			Name = 'Swing only',
			Tooltip = 'Only attacks while swinging manually'
		})
		SophiaCheck = Killaura:CreateToggle({
			Name = 'Sophia Check',
			Tooltip = 'Stops Killaura when frozen by Sophia',
			Default = false
		})
	end)

	run(function()
		getgenv().swapping = os.clock()

		local AutoClicker
		local CPS
		local BlockCPS = {}
		local SwordCPS = {}
		local PlaceBlocksToggle
		local SwingSwordToggle
		local Thread
		local KeybindToggle
		local KeybindList
		local MouseBindToggle
		local MouseBindList
		local KeybindMode
		local CurrentKeybind = Enum.KeyCode.LeftAlt
		local CurrentMouseBind = Enum.UserInputType.MouseButton2
		local UseMouseBind = false
		local KeybindEnabled = false
		local KeybindHeld = false
		local KeybindActive = false
		local ActivationScheduled = nil
		local mouseDownTime = 0
		local MIN_HOLD_TIME = 0.03

		local function isHoldingProjectile()
			return store.hand and store.hand.toolType == 'bow' or false
		end

		local function getSafeCPS()
			local cachedToolType = store.hand and store.hand.toolType or nil
			if cachedToolType == 'block' and PlaceBlocksToggle and PlaceBlocksToggle.Enabled and BlockCPS and BlockCPS.GetRandomValue then
				return BlockCPS
			elseif cachedToolType == 'sword' and SwingSwordToggle and SwingSwordToggle.Enabled and SwordCPS and SwordCPS.GetRandomValue then
				return SwordCPS
			elseif CPS and CPS.GetRandomValue then
				return CPS
			end
			return nil
		end

		local function UpdateKeybindState()
			if not KeybindEnabled then KeybindActive = true return end
			if KeybindMode.Value == 'Toggle' then return end
			if UseMouseBind then
				KeybindActive = inputService:IsMouseButtonPressed(CurrentMouseBind)
			else
				KeybindActive = inputService:IsKeyDown(CurrentKeybind)
			end
		end

		local function AutoClick()
			if Thread then task.cancel(Thread) end
			local initialCPS = getSafeCPS()
			if not initialCPS then return end
			Thread = task.delay(1 / initialCPS.GetRandomValue(), function()
				repeat
					if KeybindEnabled and KeybindMode.Value == 'Hold' then
						UpdateKeybindState()
						if not KeybindActive then task.wait(0.1) continue end
					end
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						local cachedToolType = store.hand and store.hand.toolType or nil
						if PlaceBlocksToggle.Enabled and cachedToolType == 'block' then
							local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
							if blockPlacer then
								local serverTime = workspace:GetServerTimeNow()
								if (serverTime - (bedwars.BlockCpsController and bedwars.BlockCpsController.lastPlaceTimestamp or 0)) >= ((1 / 12) * 0.5) then
									local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
									if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
										task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
									end
								end
							end
						elseif SwingSwordToggle.Enabled and cachedToolType == 'sword' then
							bedwars.SwordController:swingSwordAtMouse(0.39)
						end
					end
					local currentCPS = getSafeCPS()
					if not currentCPS then task.wait(0.1) else task.wait(1 / currentCPS.GetRandomValue()) end
				until not AutoClicker.Enabled
			end)
		end

		local function StartAutoClick()
			if not Thread then AutoClick() end
		end

		local function StopAutoClick()
			if Thread then task.cancel(Thread) Thread = nil end
			if ActivationScheduled then task.cancel(ActivationScheduled) ActivationScheduled = nil end
		end

		local function ToggleKeybind()
			if KeybindMode.Value == 'Toggle' then
				KeybindHeld = not KeybindHeld
				KeybindActive = KeybindHeld
				if KeybindActive then StartAutoClick() else StopAutoClick() end
			end
		end

		local lastToggleRestart = 0
		local function SafeToggleRestart()
			local now = tick()
			if now - lastToggleRestart < 0.2 then return end
			lastToggleRestart = now
			if AutoClicker.Enabled then
				AutoClicker:Toggle()
				task.wait(0.05)
				AutoClicker:Toggle()
			end
		end

		AutoClicker = vapelite:CreateModule({
			Name = 'AutoClicker',
			Function = function(callback)
				if callback then
					if KeybindEnabled then
						AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
							if UseMouseBind then
								if input.UserInputType == CurrentMouseBind then
									if KeybindMode.Value == 'Hold' then StartAutoClick()
									elseif KeybindMode.Value == 'Toggle' then ToggleKeybind() end
								end
							else
								if input.UserInputType == Enum.UserInputType.Keyboard then
									if input.KeyCode == CurrentKeybind then
										if KeybindMode.Value == 'Hold' then StartAutoClick()
										elseif KeybindMode.Value == 'Toggle' then ToggleKeybind() end
									end
								end
							end
						end))
						AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
							if KeybindMode.Value == 'Hold' then
								if UseMouseBind then
									if input.UserInputType == CurrentMouseBind then StopAutoClick() end
								else
									if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == CurrentKeybind then StopAutoClick() end
								end
							end
						end))
					else
						AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 and (os.clock() - getgenv().swapping) > 0.12 then
								mouseDownTime = os.clock()
								ActivationScheduled = task.delay(MIN_HOLD_TIME, function()
									if inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
										AutoClick()
									end
								end)
							end
						end))
						AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 then
								if ActivationScheduled then task.cancel(ActivationScheduled) ActivationScheduled = nil end
								if Thread and (os.clock() - mouseDownTime) >= MIN_HOLD_TIME and (os.clock() - getgenv().swapping) > 0.12 then
									task.cancel(Thread)
									Thread = nil
								end
							end
						end))
					end
				else
					StopAutoClick()
				end
			end,
			Tooltip = 'hold to auto click fr'
		})

		CPS = AutoClicker:CreateTwoSlider({Name = 'cps', Min = 1, Max = 9, DefaultMin = 7, DefaultMax = 7})
		KeybindToggle = AutoClicker:CreateToggle({Name = 'use keybind', Default = false, Function = function(callback) KeybindEnabled = callback if KeybindList.Object then KeybindList.Object.Visible = callback and not UseMouseBind end if MouseBindToggle.Object then MouseBindToggle.Object.Visible = callback end if MouseBindList.Object then MouseBindList.Object.Visible = callback and UseMouseBind end if KeybindMode.Object then KeybindMode.Object.Visible = callback end SafeToggleRestart() end})
		KeybindMode = AutoClicker:CreateDropdown({Name = 'keybind mode', List = {'Hold', 'Toggle'}, Default = 'Hold', Visible = false, Function = function(value) KeybindHeld = false KeybindActive = false SafeToggleRestart() end})
		KeybindList = AutoClicker:CreateDropdown({Name = 'keybind', List = {'LeftAlt','LeftControl','LeftShift','RightAlt','RightControl','RightShift','Space','CapsLock','Tab','E','Q','R','F','G','X','Z','V','B'}, Default = 'LeftAlt', Visible = false, Function = function(value) CurrentKeybind = Enum.KeyCode[value] KeybindHeld = false KeybindActive = false SafeToggleRestart() end})
		MouseBindToggle = AutoClicker:CreateToggle({Name = 'use mouse button', Default = false, Visible = false, Function = function(callback) UseMouseBind = callback if KeybindList.Object then KeybindList.Object.Visible = KeybindEnabled and not callback end if MouseBindList.Object then MouseBindList.Object.Visible = KeybindEnabled and callback end KeybindHeld = false KeybindActive = false SafeToggleRestart() end})
		MouseBindList = AutoClicker:CreateDropdown({Name = 'mouse button', List = {'right click', 'middle click'}, Default = 'right click', Visible = false, Function = function(value) local map = {['right click'] = Enum.UserInputType.MouseButton2, ['middle click'] = Enum.UserInputType.MouseButton3} CurrentMouseBind = map[value] KeybindHeld = false KeybindActive = false SafeToggleRestart() end})
		PlaceBlocksToggle = AutoClicker:CreateToggle({Name = 'place blocks', Default = true, Function = function(callback) if BlockCPS.Object then BlockCPS.Object.Visible = callback end end})
		BlockCPS = AutoClicker:CreateTwoSlider({Name = 'block cps', Min = 1, Max = 12, DefaultMin = 12, DefaultMax = 12})
		SwingSwordToggle = AutoClicker:CreateToggle({Name = 'swing sword', Default = true, Function = function(callback) if SwordCPS.Object then SwordCPS.Object.Visible = callback end end})
		SwordCPS = AutoClicker:CreateTwoSlider({Name = 'sword cps', Min = 1, Max = 9, DefaultMin = 7, DefaultMax = 7})
	end)

	run(function()
		local AimAssist
		local Range
		local Smoothness
		local Active
		local Vertical

		AimAssist = vapelite:CreateModule({
			Name = 'AimAssist',
			Function = function(callback)
				if callback then
					AimAssist:Clean(runService.RenderStepped:Connect(function(delta)
						if store.hand.toolType == 'sword' and (Active.Enabled or (tick() - bedwars.SwordController.lastSwing) < 0.2) then
							local plr = getEntitiesNear(Range.Value)
							if plr and not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
								local pos, vis = gameCamera:WorldToViewportPoint(plr.RootPart.Position)
								if vis and isrbxactive() then
									pos = (Vector2.new(pos.X, pos.Y) - inputService:GetMouseLocation()) * ((100 - Smoothness.Value) * delta / 3)
									mousemoverel(pos.X, Vertical.Enabled and pos.Y or 0)
								end
							end
						end
					end))
				end
			end,
			Tooltip = 'Helps you aim at the enemy'
		})
		Range = AimAssist:CreateSlider({Name = 'Range', Min = 1, Max = 30, Default = 30})
		Smoothness = AimAssist:CreateSlider({Name = 'Smoothness', Min = 1, Max = 100, Default = 70})
		Active = AimAssist:CreateToggle({Name = 'Always active'})
		Vertical = AimAssist:CreateToggle({Name = 'Vertical aim'})
	end)

	run(function()
		local Velocity
		local Horizontal
		local Vertical
		local Chance
		local old

		Velocity = vapelite:CreateModule({
			Name = 'Velocity',
			Function = function(callback)
				if callback then
					old = bedwars.KnockbackUtil.applyKnockback
					bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
						knockback = knockback or {}
						if Horizontal.Value == 0 and Vertical.Value == 0 then return end
						knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
						knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
						return old(root, mass, dir, knockback, ...)
					end
				else
					bedwars.KnockbackUtil.applyKnockback = old
				end
			end,
			Tooltip = 'Reduces knockback taken'
		})
		Horizontal = Velocity:CreateSlider({Name = 'Horizontal', Min = 0, Max = 100, Default = 80})
		Vertical = Velocity:CreateSlider({Name = 'Vertical', Min = 0, Max = 100, Default = 100})
		Chance = Velocity:CreateSlider({Name = 'Chance', Min = 0, Max = 100, Default = 100})
	end)

	run(function()
		local old

		local function switchBlock(block)
			if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
				local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
				if tool then
					for i, v in store.inventory.hotbar do
						if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
					end
					if hotbarSwitch(slot) then
						if inputService:IsMouseButtonPressed(0) then
							clickEvent:Fire()
						end
						return true
					end
				end
			end
		end

		vapelite:CreateModule({
			Name = 'AutoTool',
			Function = function(callback)
				if callback then
					old = bedwars.BlockBreaker.hitBlock
					bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
						local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
						if switchBlock(block and block.target and block.target.blockInstance or nil) then return end
						return old(self, maid, raycastparams, ...)
					end
				else
					bedwars.BlockBreaker.hitBlock = old
					old = nil
				end
			end,
			Tooltip = 'Automatically selects the correct tool'
		})
	end)

	run(function()
		local FastBreak
		local Time
		local BedCheck
		local currentBlock = nil
		local oldHitBlock = nil
		local bedCache = {}
		local lastCacheClean = 0
		local cacheCleanInterval = 5

		local function getBlockBreaker()
			local bbc = KnitClient.Controllers.BlockBreakController
			return bbc and bbc.blockBreaker
		end

		local function isBed(block)
			if not block then return false end
			local cached = bedCache[block]
			if cached ~= nil then return cached end
			local result = false
			pcall(function()
				if collectionService:HasTag(block, 'bed') or (block.Parent and collectionService:HasTag(block.Parent, 'bed')) then
					result = true
				elseif block.Name:lower():find('bed', 1, true) then
					result = true
				end
			end)
			bedCache[block] = result
			return result
		end

		local lastBreakUpdate = 0
		local breakUpdateCooldown = 0.05

		local function updateBreakSpeed()
			if not FastBreak or not FastBreak.Enabled then return end
			local now = tick()
			if now - lastBreakUpdate < breakUpdateCooldown then return end
			lastBreakUpdate = now
			pcall(function()
				local bb = getBlockBreaker()
				if bb then
					local cooldown = (BedCheck.Enabled and isBed(currentBlock)) and 0.3 or Time.Value
					bb:setCooldown(cooldown)
				end
			end)
		end

		FastBreak = vapelite:CreateModule({
			Name = 'FastBreak',
			Function = function(callback)
				local bb = getBlockBreaker()
				if not bb then return end
				if callback then
					oldHitBlock = bb.hitBlock
					bb.hitBlock = function(self, maid, raycastparams, ...)
						local block = nil
						pcall(function()
							local blockInfo = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
							if blockInfo and blockInfo.target and blockInfo.target.blockInstance then
								block = blockInfo.target.blockInstance
							end
						end)
						if block ~= currentBlock then
							currentBlock = block
							updateBreakSpeed()
						end
						return oldHitBlock(self, maid, raycastparams, ...)
					end
					task.spawn(function()
						while FastBreak.Enabled do
							if tick() - lastCacheClean > cacheCleanInterval then
								lastCacheClean = tick()
								bedCache = {}
							end
							task.wait(0.5)
						end
					end)
				else
					pcall(function()
						local bbreaker = getBlockBreaker()
						if bbreaker then
							if oldHitBlock then bbreaker.hitBlock = oldHitBlock end
							bbreaker:setCooldown(0.3)
						end
					end)
					oldHitBlock = nil
					currentBlock = nil
					bedCache = {}
				end
			end,
			Tooltip = 'decreases block break cooldown'
		})

		Time = FastBreak:CreateSlider({Name = 'break speed', Min = 0, Max = 0.3, Default = 0.25, Decimal = 100, Suffix = 'seconds', Function = function() updateBreakSpeed() end})
		BedCheck = FastBreak:CreateToggle({Name = 'bed check', Default = false, Tooltip = 'normal break speed on beds', Function = function() bedCache = {}; updateBreakSpeed() end})
	end)

	run(function()
		local NoFall
		local Mode
		local DamageAccuracy
		local rand = Random.new()
		local rayParams = RaycastParams.new()
		local groundHit
		local VECTOR_DOWN = Vector3.new(0, -1000, 0)
		local BLOCKCAST_SIZE = Vector3.new(3, 3, 3)

		task.spawn(function()
			repeat task.wait() until bedwars.Client
			pcall(function()
				local remote = bedwars.Client:Get('GroundHit')
				if remote then groundHit = remote.instance end
			end)
		end)

		rayParams.CollisionGroup = 'Default'

		local function runDamageAccuracyMode()
			local tracked = 0
			local extraGravity = 0
			NoFall:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local velocity = root.AssemblyLinearVelocity
					if velocity.Y < -85 then
						rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
						rayParams.CollisionGroup = root.CollisionGroup
						local rootSize = root.Size.Y / 2.5 + entitylib.character.HipHeight
						local checkDistance = Vector3.new(0, (tracked * 0.1) - rootSize, 0)
						local ray = workspace:Blockcast(root.CFrame, BLOCKCAST_SIZE, checkDistance, rayParams)
						if not ray then
							local Failed = rand:NextNumber(0, 100) < DamageAccuracy.Value
							local velo = velocity.Y
							if Failed then
								root.AssemblyLinearVelocity = Vector3.new(velocity.X, velo + 0.5, velocity.Z)
							else
								root.AssemblyLinearVelocity = Vector3.new(velocity.X, -86, velocity.Z)
							end
							root.CFrame = root.CFrame + Vector3.new(0, (Failed and -extraGravity or extraGravity) * dt, 0)
							extraGravity = extraGravity + (Failed and workspace.Gravity or -workspace.Gravity) * dt
							tracked = velo
						else
							tracked = velocity.Y
						end
					else
						extraGravity = 0
						tracked = 0
					end
				end
			end))
		end

		NoFall = vapelite:CreateModule({
			Name = 'NoFall',
			Function = function(callback)
				if callback then runDamageAccuracyMode() end
			end,
			Tooltip = 'no fall damage on god'
		})
		Mode = NoFall:CreateDropdown({Name = 'mode', List = {'Damage Accuracy'}, Default = 'Damage Accuracy'})
		DamageAccuracy = NoFall:CreateSlider({Name = 'damage accuracy', Min = 0, Max = 100, Suffix = '%', Default = 0, Decimal = 5, Tooltip = 'how much fall dmg u take (0% = none, 100% = all)'})
	end)

	run(function()
		local HitFix = vapelite:CreateModule({
			Name = 'HitFix',
			Function = function(callback)
				pcall(function()
					debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, callback and 'raycast' or 'Raycast')
				end)
				pcall(function()
					debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, callback and bedwars.QueryUtil or workspace)
				end)
			end,
			Tooltip = 'fixes raycast for hits, makes em register better'
		})
	end)

	run(function()
		local WhiteHits = vapelite:CreateModule({
			Name = 'WhiteHits',
			Function = function(callback)
				repeat
					for i, v in entitylib.List do
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight then
							highlight.FillTransparency = 1
							if not highlight:GetAttribute('TransparencyHooked') then
								highlight:GetPropertyChangedSignal('FillTransparency'):Connect(function()
									highlight.FillTransparency = 1
								end)
								highlight:SetAttribute('TransparencyHooked', true)
							end
						end
					end
					task.wait(0.1)
				until not WhiteHits.Enabled
			end,
			Tooltip = 'removes the red hit flash on enemies'
		})
	end)

	run(function()
		local HitBoxes_mod
		local Mode
		local Expand
		local AutoToggle
		local Visible
		local VisibleColor
		local NPCs_toggle
		local objects, set = {}, {}
		local lastHoldingSword = false
		local autoToggleConnection = nil
		local manuallyDisabled = false
		local tick = tick
		local vector3new = Vector3.new
		local vector3one = Vector3.one

		local colorList = {
			Red = Color3.fromRGB(255, 0, 0), Blue = Color3.fromRGB(0, 100, 255), Green = Color3.fromRGB(0, 255, 0),
			Yellow = Color3.fromRGB(255, 255, 0), Orange = Color3.fromRGB(255, 140, 0), Purple = Color3.fromRGB(180, 0, 255),
			White = Color3.fromRGB(255, 255, 255), Cyan = Color3.fromRGB(0, 255, 255), Pink = Color3.fromRGB(255, 50, 150), Black = Color3.fromRGB(0, 0, 0)
		}

		local function shouldCreateHitbox(ent)
			if not ent.Targetable then return false end
			if ent.Player then return true end
			if NPCs_toggle and NPCs_toggle.Enabled and not ent.Player then return true end
			return false
		end

		local cachedExpandSize = vector3new(3, 6, 3)
		local lastExpandValue = 0
		local function updateExpandSize(val)
			if val ~= lastExpandValue then
				lastExpandValue = val
				cachedExpandSize = vector3new(3, 6, 3) + vector3one * (val / 5)
			end
		end

		local function createHitbox(ent)
			if shouldCreateHitbox(ent) then
				local hitbox = Instance.new('Part')
				hitbox.Size = cachedExpandSize
				hitbox.Position = ent.RootPart.Position
				hitbox.CanCollide = false
				hitbox.Massless = true
				hitbox.Transparency = Visible and Visible.Enabled and 0.5 or 1
				if Visible and Visible.Enabled and VisibleColor then
					hitbox.Color = colorList[VisibleColor.Value] or colorList.Red
				end
				hitbox.Parent = ent.Character
				local weld = Instance.new('Motor6D')
				weld.Part0 = hitbox
				weld.Part1 = ent.RootPart
				weld.Parent = hitbox
				objects[ent] = hitbox
			end
		end

		local function isSwordInHand()
			if not store.hand or not store.hand.tool then return false end
			return store.hand.toolType == 'sword'
		end

		local lastAutoToggleTime = 0
		local autoToggleCooldown = 0.1
		local function handleAutoToggle()
			if not AutoToggle.Enabled or Mode.Value ~= 'Player' then return end
			local now = tick()
			if now - lastAutoToggleTime < autoToggleCooldown then return end
			local holdingSword = isSwordInHand()
			if holdingSword ~= lastHoldingSword then
				lastHoldingSword = holdingSword
				lastAutoToggleTime = now
				if holdingSword then
					if not HitBoxes_mod.Enabled and not manuallyDisabled then HitBoxes_mod:Toggle() end
				else
					if HitBoxes_mod.Enabled then manuallyDisabled = false HitBoxes_mod:Toggle() end
				end
			end
		end

		local function refreshAllHitboxes()
			for ent, part in pairs(objects) do part:Destroy() end
			table.clear(objects)
			local entityList = entitylib.List
			for i = 1, #entityList do createHitbox(entityList[i]) end
		end

		HitBoxes_mod = vapelite:CreateModule({
			Name = 'HitBoxes',
			Function = function(callback)
				if callback then
					manuallyDisabled = false
					updateExpandSize(Expand.Value)
					if Mode.Value == 'Sword' then
						debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
						set = true
					else
						HitBoxes_mod:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
						HitBoxes_mod:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
							local obj = objects[ent]
							if obj then obj:Destroy() objects[ent] = nil end
						end))
						local entityList = entitylib.List
						for i = 1, #entityList do createHitbox(entityList[i]) end
					end
				else
					if AutoToggle.Enabled and isSwordInHand() then manuallyDisabled = true end
					if set then
						debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
						set = nil
					end
					for _, part in pairs(objects) do part:Destroy() end
					table.clear(objects)
					if not AutoToggle.Enabled then lastHoldingSword = false end
				end
			end,
			Tooltip = 'expands hitboxes so u hit more'
		})

		HitBoxes = HitBoxes_mod

		Mode = HitBoxes_mod:CreateDropdown({
			Name = 'mode', List = {'Sword', 'Player'},
			Function = function(val)
				local isPlayer = val == 'Player'
				if AutoToggle then AutoToggle.Object.Visible = isPlayer end
				if Visible then Visible.Object.Visible = isPlayer end
				if VisibleColor then VisibleColor.Object.Visible = isPlayer and Visible.Enabled end
				if NPCs_toggle then NPCs_toggle.Object.Visible = isPlayer end
				if HitBoxes_mod.Enabled then HitBoxes_mod:Toggle() HitBoxes_mod:Toggle() end
			end
		})

		Expand = HitBoxes_mod:CreateSlider({
			Name = 'expand amount', Min = 0, Max = 14.4, Default = 14.4, Decimal = 10,
			Function = function(val)
				updateExpandSize(val)
				if HitBoxes_mod.Enabled then
					if Mode.Value == 'Sword' then
						debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
					else
						for _, part in pairs(objects) do part.Size = cachedExpandSize end
					end
				end
			end,
			Suffix = function(val) return val == 1 and 'stud' or 'studs' end
		})

		local autoToggleFrameCounter = 0
		AutoToggle = HitBoxes_mod:CreateToggle({
			Name = 'auto toggle', Default = false, Visible = false, Tooltip = 'auto enables hitbox when holding sword',
			Function = function(callback)
				if callback then
					if autoToggleConnection then autoToggleConnection:Disconnect() end
					lastHoldingSword = false
					autoToggleFrameCounter = 0
					autoToggleConnection = runService.Heartbeat:Connect(function()
						autoToggleFrameCounter = autoToggleFrameCounter + 1
						if autoToggleFrameCounter % 5 == 0 then handleAutoToggle() end
					end)
					handleAutoToggle()
				else
					if autoToggleConnection then autoToggleConnection:Disconnect() autoToggleConnection = nil end
					lastHoldingSword = false
				end
			end
		})

		Visible = HitBoxes_mod:CreateToggle({
			Name = 'visible', Default = false, Visible = false, Tooltip = 'makes hitbox visible',
			Function = function(callback)
				if VisibleColor then VisibleColor.Object.Visible = callback end
				if HitBoxes_mod.Enabled and Mode.Value == 'Player' then
					local transparency = callback and 0.5 or 1
					local color = callback and VisibleColor and (colorList[VisibleColor.Value] or colorList.Red) or nil
					for _, part in pairs(objects) do
						part.Transparency = transparency
						if color then part.Color = color end
					end
				end
			end
		})

		VisibleColor = HitBoxes_mod:CreateDropdown({
			Name = 'hitbox color', List = {'Red','Blue','Green','Yellow','Orange','Purple','White','Cyan','Pink','Black'}, Default = 'Red', Visible = false,
			Function = function(val)
				if HitBoxes_mod.Enabled and Mode.Value == 'Player' and Visible.Enabled then
					local color = colorList[val] or colorList.Red
					for _, part in pairs(objects) do part.Color = color end
				end
			end
		})

		NPCs_toggle = HitBoxes_mod:CreateToggle({Name = 'npcs', Default = false, Visible = false, Tooltip = 'apply hitbox to npcs too', Function = function(callback) if HitBoxes_mod.Enabled and Mode.Value == 'Player' then refreshAllHitboxes() end end})
		local Invisible_toggle = HitBoxes_mod:CreateToggle({Name = 'invisible players', Default = false, Visible = false, Tooltip = 'apply hitbox to invisible players', Function = function(callback) if HitBoxes_mod.Enabled and Mode.Value == 'Player' then refreshAllHitboxes() end end})

		task.spawn(function()
			repeat task.wait() until Mode.Value
			local isPlayer = Mode.Value == 'Player'
			AutoToggle.Object.Visible = isPlayer
			Visible.Object.Visible = isPlayer
			NPCs_toggle.Object.Visible = isPlayer
		end)
	end)

	run(function()
		local ESP
		local ESPMethod
		local ESPBoundingBox = {Enabled = true}
		local ESPHealthBar = {Enabled = false}
		local ESPName = {Enabled = true}
		local ESPDisplay = {Enabled = true}
		local ESPBackground = {Enabled = false}
		local ESPFilled = {Enabled = false}
		local ESPTeammates = {Enabled = true}
		local ESPModes = {'2D', '3D', 'Skeleton'}
		local ESPFolder = {}
		local methodused

		local function floorESPPosition(pos) return pos // 1 end

		local function ESPWorldToViewport(pos)
			local newpos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(gameCamera.CFrame:pointToObjectSpace(pos)))
			return Vector2.new(newpos.X, newpos.Y)
		end

		local ESPAdded = {
			Drawing2D = function(ent)
				if ESPTeammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
				local EntityESP = {}
				EntityESP.Main = Drawing.new('Square')
				EntityESP.Main.Transparency = ESPBoundingBox.Enabled and 1 or 0
				EntityESP.Main.ZIndex = 2
				EntityESP.Main.Filled = false
				EntityESP.Main.Thickness = 1
				EntityESP.Main.Color = ent.Player.TeamColor.Color
				EntityESP.Border = Drawing.new('Square')
				EntityESP.Border.Transparency = ESPBoundingBox.Enabled and 0.35 or 0
				EntityESP.Border.ZIndex = 1
				EntityESP.Border.Thickness = 1
				EntityESP.Border.Filled = false
				EntityESP.Border.Color = Color3.new()
				EntityESP.Border2 = Drawing.new('Square')
				EntityESP.Border2.Transparency = ESPBoundingBox.Enabled and 0.35 or 0
				EntityESP.Border2.ZIndex = 1
				EntityESP.Border2.Thickness = 1
				EntityESP.Border2.Filled = ESPFilled.Enabled
				EntityESP.Border2.Color = Color3.new()
				if ESPHealthBar.Enabled then
					EntityESP.HealthLine = Drawing.new('Line')
					EntityESP.HealthLine.Thickness = 1
					EntityESP.HealthLine.ZIndex = 2
					EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					EntityESP.HealthBorder = Drawing.new('Line')
					EntityESP.HealthBorder.Thickness = 3
					EntityESP.HealthBorder.Transparency = 0.35
					EntityESP.HealthBorder.ZIndex = 1
					EntityESP.HealthBorder.Color = Color3.new()
				end
				if ESPName.Enabled then
					if ESPBackground.Enabled then
						EntityESP.TextBKG = Drawing.new('Square')
						EntityESP.TextBKG.Transparency = 0.35
						EntityESP.TextBKG.ZIndex = 0
						EntityESP.TextBKG.Thickness = 1
						EntityESP.TextBKG.Filled = true
						EntityESP.TextBKG.Color = Color3.new()
					end
					EntityESP.Drop = Drawing.new('Text')
					EntityESP.Drop.Color = Color3.new()
					EntityESP.Drop.Text = ent.Player and (ESPDisplay.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
					EntityESP.Drop.ZIndex = 1
					EntityESP.Drop.Center = true
					EntityESP.Drop.Size = 20
					EntityESP.Text = Drawing.new('Text')
					EntityESP.Text.Text = EntityESP.Drop.Text
					EntityESP.Text.ZIndex = 2
					EntityESP.Text.Color = EntityESP.Main.Color
					EntityESP.Text.Center = true
					EntityESP.Text.Size = 20
				end
				ESPFolder[ent] = EntityESP
			end,
			Drawing3D = function(ent)
				if ESPTeammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
				local EntityESP = {}
				EntityESP.Line1 = Drawing.new('Line') EntityESP.Line2 = Drawing.new('Line') EntityESP.Line3 = Drawing.new('Line') EntityESP.Line4 = Drawing.new('Line')
				EntityESP.Line5 = Drawing.new('Line') EntityESP.Line6 = Drawing.new('Line') EntityESP.Line7 = Drawing.new('Line') EntityESP.Line8 = Drawing.new('Line')
				EntityESP.Line9 = Drawing.new('Line') EntityESP.Line10 = Drawing.new('Line') EntityESP.Line11 = Drawing.new('Line') EntityESP.Line12 = Drawing.new('Line')
				local color = ent.Player.TeamColor.Color
				for _, v in EntityESP do v.Thickness = 1 v.Color = color end
				ESPFolder[ent] = EntityESP
			end,
			DrawingSkeleton = function(ent)
				if ESPTeammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
				local EntityESP = {}
				EntityESP.Head = Drawing.new('Line') EntityESP.HeadFacing = Drawing.new('Line') EntityESP.Torso = Drawing.new('Line')
				EntityESP.UpperTorso = Drawing.new('Line') EntityESP.LowerTorso = Drawing.new('Line')
				EntityESP.LeftArm = Drawing.new('Line') EntityESP.RightArm = Drawing.new('Line')
				EntityESP.LeftLeg = Drawing.new('Line') EntityESP.RightLeg = Drawing.new('Line')
				local color = ent.Player.TeamColor.Color
				for _, v in EntityESP do v.Thickness = 2 v.Color = color end
				ESPFolder[ent] = EntityESP
			end
		}

		local ESPRemoved = {
			Drawing2D = function(ent)
				local EntityESP = ESPFolder[ent]
				if EntityESP then
					ESPFolder[ent] = nil
					for _, v in EntityESP do pcall(function() v.Visible = false v:Remove() end) end
				end
			end
		}
		ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
		ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D

		local ESPUpdated = {
			Drawing2D = function(ent)
				local EntityESP = ESPFolder[ent]
				if EntityESP then
					if EntityESP.HealthLine then EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75) end
					if EntityESP.Text then
						EntityESP.Text.Text = ent.Player and (ESPDisplay.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
						EntityESP.Drop.Text = EntityESP.Text.Text
					end
				end
			end
		}

		local ESPLoop = {
			Drawing2D = function()
				for ent, EntityESP in ESPFolder do
					local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
					for _, obj in EntityESP do obj.Visible = rootVis end
					if not rootVis then continue end
					local topPos = gameCamera:WorldToViewportPoint((CFrame.new(ent.RootPart.Position, ent.RootPart.Position + gameCamera.CFrame.LookVector) * CFrame.new(2, ent.HipHeight, 0)).p)
					local bottomPos = gameCamera:WorldToViewportPoint((CFrame.new(ent.RootPart.Position, ent.RootPart.Position + gameCamera.CFrame.LookVector) * CFrame.new(-2, -ent.HipHeight - 1, 0)).p)
					local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
					local posx, posy = (rootPos.X - sizex / 2), ((rootPos.Y - sizey / 2))
					EntityESP.Main.Position = floorESPPosition(Vector2.new(posx, posy))
					EntityESP.Main.Size = floorESPPosition(Vector2.new(sizex, sizey))
					EntityESP.Border.Position = floorESPPosition(Vector2.new(posx - 1, posy + 1))
					EntityESP.Border.Size = floorESPPosition(Vector2.new(sizex + 2, sizey - 2))
					EntityESP.Border2.Position = floorESPPosition(Vector2.new(posx + 1, posy - 1))
					EntityESP.Border2.Size = floorESPPosition(Vector2.new(sizex - 2, sizey + 2))
					if EntityESP.HealthLine then
						local healthposy = sizey * math.clamp(ent.Health / ent.MaxHealth, 0, 1)
						EntityESP.HealthLine.Visible = ent.Health > 0
						EntityESP.HealthLine.From = floorESPPosition(Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))))
						EntityESP.HealthLine.To = floorESPPosition(Vector2.new(posx - 6, posy))
						EntityESP.HealthBorder.From = floorESPPosition(Vector2.new(posx - 6, posy + 1))
						EntityESP.HealthBorder.To = floorESPPosition(Vector2.new(posx - 6, (posy + sizey) - 1))
					end
					if EntityESP.Text then
						EntityESP.Text.Position = floorESPPosition(Vector2.new(posx + (sizex / 2), posy + (sizey - 28)))
						EntityESP.Drop.Position = EntityESP.Text.Position + Vector2.new(1, 1)
						if EntityESP.TextBKG then
							EntityESP.TextBKG.Size = EntityESP.Text.TextBounds + Vector2.new(8, 4)
							EntityESP.TextBKG.Position = EntityESP.Text.Position - Vector2.new(4 + (EntityESP.Text.TextBounds.X / 2), 0)
						end
					end
				end
			end,
			Drawing3D = function()
				for ent, EntityESP in ESPFolder do
					local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
					for _, obj in EntityESP do obj.Visible = rootVis end
					if not rootVis then continue end
					local p1=ESPWorldToViewport(ent.RootPart.Position+Vector3.new(1.5,ent.HipHeight,1.5)) local p2=ESPWorldToViewport(ent.RootPart.Position+Vector3.new(1.5,-ent.HipHeight,1.5))
					local p3=ESPWorldToViewport(ent.RootPart.Position+Vector3.new(-1.5,ent.HipHeight,1.5)) local p4=ESPWorldToViewport(ent.RootPart.Position+Vector3.new(-1.5,-ent.HipHeight,1.5))
					local p5=ESPWorldToViewport(ent.RootPart.Position+Vector3.new(1.5,ent.HipHeight,-1.5)) local p6=ESPWorldToViewport(ent.RootPart.Position+Vector3.new(1.5,-ent.HipHeight,-1.5))
					local p7=ESPWorldToViewport(ent.RootPart.Position+Vector3.new(-1.5,ent.HipHeight,-1.5)) local p8=ESPWorldToViewport(ent.RootPart.Position+Vector3.new(-1.5,-ent.HipHeight,-1.5))
					EntityESP.Line1.From=p1 EntityESP.Line1.To=p2 EntityESP.Line2.From=p3 EntityESP.Line2.To=p4
					EntityESP.Line3.From=p5 EntityESP.Line3.To=p6 EntityESP.Line4.From=p7 EntityESP.Line4.To=p8
					EntityESP.Line5.From=p1 EntityESP.Line5.To=p3 EntityESP.Line6.From=p1 EntityESP.Line6.To=p5
					EntityESP.Line7.From=p5 EntityESP.Line7.To=p7 EntityESP.Line8.From=p7 EntityESP.Line8.To=p3
					EntityESP.Line9.From=p2 EntityESP.Line9.To=p4 EntityESP.Line10.From=p2 EntityESP.Line10.To=p6
					EntityESP.Line11.From=p6 EntityESP.Line11.To=p8 EntityESP.Line12.From=p8 EntityESP.Line12.To=p4
				end
			end,
			DrawingSkeleton = function()
				for ent, EntityESP in ESPFolder do
					local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
							for _, obj in EntityESP do obj.Visible = rootVis end
							if not rootVis then continue end
							local rigcheck = ent.Humanoid.RigType == Enum.HumanoidRigType.R6
							pcall(function() -- kill me
								local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.new()
								local head = ESPWorldToViewport((ent.Head.CFrame).p)
								local headfront = ESPWorldToViewport((ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
								local toplefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
								local toprighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p)
								local toptorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p)
								local bottomtorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p)
								local bottomlefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
								local bottomrighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p)
								local leftarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
								local rightarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
								local leftleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
								local rightleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
								EntityESP.Head.From = toptorso
								EntityESP.Head.To = head
								EntityESP.HeadFacing.From = head
								EntityESP.HeadFacing.To = headfront
								EntityESP.UpperTorso.From = toplefttorso
								EntityESP.UpperTorso.To = toprighttorso
								EntityESP.Torso.From = toptorso
								EntityESP.Torso.To = bottomtorso
								EntityESP.LowerTorso.From = bottomlefttorso
								EntityESP.LowerTorso.To = bottomrighttorso
								EntityESP.LeftArm.From = toplefttorso
								EntityESP.LeftArm.To = leftarm
								EntityESP.RightArm.From = toprighttorso
								EntityESP.RightArm.To = rightarm
								EntityESP.LeftLeg.From = bottomlefttorso
								EntityESP.LeftLeg.To = leftleg
								EntityESP.RightLeg.From = bottomrighttorso
								EntityESP.RightLeg.To = rightleg
							end)
						end
					end
				}

				ESP = vapelite:CreateModule({
					Name = 'ESP',
					Function = function(callback)
						if callback then
							methodused = 'Drawing'..ESPModes[ESPMethod.Value]
							if ESPRemoved[methodused] then
								ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
							end
							if ESPAdded[methodused] then
								for _, v in entitylib.List do
									if ESPFolder[v] then ESPRemoved[methodused](v) end
									ESPAdded[methodused](v)
								end
								ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
									if ESPFolder[ent] then ESPRemoved[methodused](ent) end
									ESPAdded[methodused](ent)
								end))
							end
							if ESPUpdated[methodused] then
								ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
								for _, v in entitylib.List do ESPUpdated[methodused](v) end
							end
							if ESPLoop[methodused] then
								ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
							end
						else
							if ESPRemoved[methodused] then
								for i in ESPFolder do ESPRemoved[methodused](i) end
							end
						end
					end,
					Tooltip = 'Renders an ESP on players.'
				})
				ESPMethod = ESP:CreateSlider({
					Name = 'Mode',
					Min = 1,
					Max = #ESPModes,
					Function = function() if ESP.Enabled then ESP:Toggle() ESP:Toggle() end end
				})
				ESPBoundingBox = ESP:CreateToggle({
					Name = 'Bounding Box',
					Function = function() if ESP.Enabled then ESP:Toggle() ESP:Toggle() end end,
					Default = true
				})
				ESPHealthBar = ESP:CreateToggle({
					Name = 'Health Bar',
					Function = function() if ESP.Enabled then ESP:Toggle() ESP:Toggle() end end
				})
				ESPName = ESP:CreateToggle({
					Name = 'Name',
					Function = function() if ESP.Enabled then ESP:Toggle() ESP:Toggle() end end
				})
				ESPDisplay = ESP:CreateToggle({
					Name = 'Use Displayname',
					Function = function() if ESP.Enabled then ESP:Toggle() ESP:Toggle() end end,
					Default = true
				})
				ESPBackground = ESP:CreateToggle({
					Name = 'Show Background',
					Function = function() if ESP.Enabled then ESP:Toggle() ESP:Toggle() end end
				})
				ESPFilled = ESP:CreateToggle({
					Name = 'Filled',
					Function = function() if ESP.Enabled then ESP:Toggle() ESP:Toggle() end end
				})
				ESPTeammates = ESP:CreateToggle({
					Name = 'Priority Only',
					Function = function() if ESP.Enabled then ESP:Toggle() ESP:Toggle() end end,
					Default = true
				})
			end)

			run(function()
				local NameTags = {Enabled = false}
				local NameTagsBackground = {Value = 5}
				local NameTagsDisplayName = {Enabled = false}
				local NameTagsHealth = {Enabled = false}
				local NameTagsDistance = {Enabled = false}
				local NameTagsScale = {Value = 10}
				local NameTagsFont = {Value = 1}
				local NameTagsTeammates = {Enabled = true}
				local NameTagsStrings = {}
				local NameTagsSizes = {}
				local NameTagsDrawingFolder = {}
				local fontitems = {'Arial'}

				local NameTagAdded = function(ent)
					if NameTagsTeammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
					local EntityNameTag = {}
					EntityNameTag.BG = Drawing.new('Square')
					EntityNameTag.BG.Filled = true
					EntityNameTag.BG.Transparency = 1 - (NameTagsBackground.Value / 10)
					EntityNameTag.BG.Color = Color3.new()
					EntityNameTag.BG.ZIndex = 1
					EntityNameTag.Text = Drawing.new('Text')
					EntityNameTag.Text.Size = 15 * (NameTagsScale.Value / 10)
					EntityNameTag.Text.Font = 1
					EntityNameTag.Text.ZIndex = 2
					NameTagsStrings[ent] = ent.Player and (NameTagsDisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
					if NameTagsHealth.Enabled then
						local color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
						NameTagsStrings[ent] = NameTagsStrings[ent]..' '..math.round(ent.Health)
					end
					if NameTagsDistance.Enabled then
						NameTagsStrings[ent] = '[%s] '..NameTagsStrings[ent]
					end
					EntityNameTag.Text.Text = NameTagsStrings[ent]
					EntityNameTag.Text.Color = ent.Player.TeamColor.Color
					EntityNameTag.BG.Size = Vector2.new(EntityNameTag.Text.TextBounds.X + 8, EntityNameTag.Text.TextBounds.Y + 7)
					NameTagsDrawingFolder[ent] = EntityNameTag
				end


				local NameTagRemoved = function(ent)
					local v = NameTagsDrawingFolder[ent]
					if v then
						NameTagsDrawingFolder[ent] = nil
						NameTagsStrings[ent] = nil
						NameTagsSizes[ent] = nil
						for _, v2 in v do
							pcall(function() v2.Visible = false v2:Remove() end)
						end
					end
				end


				local NameTagUpdated = function(ent)
					local EntityNameTag = NameTagsDrawingFolder[ent]
					if EntityNameTag then
						NameTagsSizes[ent] = nil
						NameTagsStrings[ent] = ent.Player and (NameTagsDisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
						if NameTagsHealth.Enabled then
							NameTagsStrings[ent] = NameTagsStrings[ent]..' '..math.round(ent.Health)
						end
						if NameTagsDistance.Enabled then
							NameTagsStrings[ent] = '[%s] '..NameTagsStrings[ent]
							EntityNameTag.Text.Text = entitylib.isAlive and string.format(NameTagsStrings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or NameTagsStrings[ent]
						else
							EntityNameTag.Text.Text = NameTagsStrings[ent]
						end
						EntityNameTag.BG.Size = Vector2.new(EntityNameTag.Text.TextBounds.X + 8, EntityNameTag.Text.TextBounds.Y + 7)
						EntityNameTag.Text.Color = ent.Player.TeamColor.Color
					end
				end


				local NameTagLoop = function()
					for ent, EntityNameTag in NameTagsDrawingFolder do
						local headPos, headVis = gameCamera:WorldToScreenPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
						EntityNameTag.Text.Visible = headVis
						EntityNameTag.BG.Visible = headVis
						if not headVis then
							continue
						end
						if NameTagsDistance.Enabled and entitylib.isAlive then
							local mag = math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)
							if NameTagsSizes[ent] ~= mag then
								EntityNameTag.Text.Text = string.format(NameTagsStrings[ent], mag)
								EntityNameTag.BG.Size = Vector2.new(EntityNameTag.Text.TextBounds.X + 8, EntityNameTag.Text.TextBounds.Y + 7)
								NameTagsSizes[ent] = mag
							end
						end
						EntityNameTag.BG.Position = Vector2.new(headPos.X - (EntityNameTag.BG.Size.X / 2), headPos.Y + (EntityNameTag.BG.Size.Y / 2))
						EntityNameTag.Text.Position = EntityNameTag.BG.Position + Vector2.new(4, 2.5)
					end
				end


				NameTags = vapelite:CreateModule({
					Name = 'NameTags',
					Function = function(callback)
						if callback then
							NameTags:Clean(entitylib.Events.EntityRemoved:Connect(NameTagRemoved))
							for _, v in entitylib.List do
								if NameTagsDrawingFolder[v] then NameTagRemoved(v) end
								NameTagAdded(v)
								NameTagUpdated(v)
							end
							NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
								if NameTagsDrawingFolder[ent] then NameTagRemoved(ent) end
								NameTagAdded(ent)
							end))
							NameTags:Clean(entitylib.Events.EntityUpdated:Connect(NameTagUpdated))
							NameTags:Clean(runService.RenderStepped:Connect(NameTagLoop))
						else
							for i in NameTagsDrawingFolder do NameTagRemoved(i) end
						end
					end,
					Tooltip = 'Renders nametags on entities through walls.'
				})
				NameTagsFont = NameTags:CreateSlider({
					Name = 'Font',
					Function = function() if NameTags.Enabled then NameTags:Toggle() NameTags:Toggle() end end,
					Min = 1,
					Max = 3
				})
				NameTagsScale = NameTags:CreateSlider({
					Name = 'Scale',
					Function = function() if NameTags.Enabled then NameTags:Toggle() NameTags:Toggle() end end,
					Default = 10,
					Min = 1,
					Max = 15
				})
				NameTagsBackground = NameTags:CreateSlider({
					Name = 'Transparency',
					Function = function() if NameTags.Enabled then NameTags:Toggle() NameTags:Toggle() end end,
					Default = 5,
					Min = 0,
					Max = 10
				})
				NameTagsHealth = NameTags:CreateToggle({
					Name = 'Health',
					Function = function() if NameTags.Enabled then NameTags:Toggle() NameTags:Toggle() end end
				})
				NameTagsDistance = NameTags:CreateToggle({
					Name = 'Distance',
					Function = function() if NameTags.Enabled then NameTags:Toggle() NameTags:Toggle() end end
				})
				NameTagsDisplayName = NameTags:CreateToggle({
					Name = 'Use Displayname',
					Function = function() if NameTags.Enabled then NameTags:Toggle() NameTags:Toggle() end end,
					Default = true
				})
				NameTagsTeammates = NameTags:CreateToggle({
					Name = 'Priority Only',
					Function = function() if NameTags.Enabled then NameTags:Toggle() NameTags:Toggle() end end,
					Default = true
				})
			end)

			run(function()
				local Tracers = {Enabled = false}
				local TracersTransparency = {Value = 0}
				local TracersStartPosition = {Value = 1}
				local TracersEndPosition = {Value = 1}
				local TracersTeammates = {Enabled = true}
				local TracersDistanceColor = {Enabled = false}
				local TracersBehind = {Enabled = true}
				local TracersFolder = {}

				local TracersAdded = function(ent)
					if TracersTeammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
					local EntityTracer = Drawing.new('Line')
					EntityTracer.Thickness = 1
					EntityTracer.Transparency = 1 - (TracersTransparency.Value / 10)
					EntityTracer.Color = ent.Player.TeamColor.Color
					TracersFolder[ent] = EntityTracer
				end

				local TracersRemoved = function(ent)
					local v = TracersFolder[ent]
					if v then
						TracersFolder[ent] = nil
						pcall(function() v.Visible = false v:Remove() end)
					end
				end

				local TracersLoop = function()
					for ent, EntityTracer in TracersFolder do
						local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
						local rootPos, rootVis = gameCamera:WorldToViewportPoint(ent[TracersEndPosition.Value == 2 and 'RootPart' or 'Head'].Position)
						if not rootVis and TracersBehind.Enabled then
							local tempPos = gameCamera.CFrame:pointToObjectSpace(ent[TracersEndPosition.Value == 2 and 'RootPart' or 'Head'].Position)
							tempPos = CFrame.Angles(0, 0, (math.atan2(tempPos.Y, tempPos.X) + math.pi)):vectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):vectorToWorldSpace(Vector3.new(0, 0, -1))));
							rootPos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(tempPos))
							rootVis = true
						end
						local screensize = gameCamera.ViewportSize
						local startVector = TracersStartPosition.Value == 3 and inputService:GetMouseLocation() or Vector2.new(screensize.X / 2, (TracersStartPosition.Value == 1 and screensize.Y / 2 or screensize.Y))
						local endVector = Vector2.new(rootPos.X, rootPos.Y)
						EntityTracer.Visible = rootVis
						EntityTracer.From = startVector
						EntityTracer.To = endVector
						if TracersDistanceColor.Enabled and distance then
							EntityTracer.Color = Color3.fromHSV(math.min((distance / 128) / 2.8, 0.4), 0.89, 0.75)
						end
					end
				end


				Tracers = vapelite:CreateModule({
					Name = 'Tracers',
					Function = function(callback)
						if callback then
							Tracers:Clean(entitylib.Events.EntityRemoved:Connect(TracersRemoved))
							for _, v in entitylib.List do
								if TracersFolder[v] then TracersRemoved(v) end
								TracersAdded(v)
							end
							Tracers:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
								if TracersFolder[ent] then TracersRemoved(ent) end
								TracersAdded(ent)
							end))
							Tracers:Clean(runService.RenderStepped:Connect(TracersLoop))
						else
							for i in TracersFolder do TracersRemoved(i) end
						end
					end,
					Tooltip = 'Renders tracers on players.'
				})
				TracersStartPosition = Tracers:CreateSlider({
					Name = 'Start Position',
					Function = function() if Tracers.Enabled then Tracers:Toggle() Tracers:Toggle() end end,
					Min = 1,
					Max = 3
				})
				TracersEndPosition = Tracers:CreateSlider({
					Name = 'End Position',
					Function = function() if Tracers.Enabled then Tracers:Toggle() Tracers:Toggle() end end,
					Min = 1,
					Max = 2
				})
				TracersTransparency = Tracers:CreateSlider({
					Name = 'Transparency',
					Min = 0,
					Max = 10,
					Function = function(val)
						for ent, EntityTracer in TracersFolder do
							EntityTracer.Transparency = 1 - (val / 10)
						end
					end
				})
				TracersDistanceColor = Tracers:CreateToggle({
					Name = 'Color by distance',
					Function = function() if Tracers.Enabled then Tracers:Toggle() Tracers:Toggle() end end
				})
				TracersBehind = Tracers:CreateToggle({
					Name = 'Behind',
					Default = true
				})
				TracersTeammates = Tracers:CreateToggle({
					Name = 'Priority Only',
					Function = function() if Tracers.Enabled then Tracers:Toggle() Tracers:Toggle() end end,
					Default = true
				})
			end)

			--[[
				Utility
			]]

			run(function()
				local shooting, old = false

				local function getCrossbows()
					local crossbows = {}
					for i, v in store.inventory.hotbar do
						if v.item and v.item.itemType:find('crossbow') and i ~= (store.inventory.hotbarSlot + 1) then table.insert(crossbows, i - 1) end
					end
					return crossbows
				end

				vapelite:CreateModule({
					Name = 'AutoShoot',
					Function = function(callback)
						if callback then
							old = bedwars.ProjectileController.createLocalProjectile
							bedwars.ProjectileController.createLocalProjectile = function(...)
								local source, data, proj = ...
								if source and (proj == 'arrow' or proj == 'fireball') and not shooting then
									task.spawn(function()
										local bows = getCrossbows()
										if #bows > 0 then
											shooting = true
											task.wait(0.15)
											local selected = store.inventory.hotbarSlot
											for _, v in getCrossbows() do
												if hotbarSwitch(v) then
													task.wait(0.05)
													mouse1click()
													task.wait(0.05)
												end
											end
											hotbarSwitch(selected)
											shooting = false
										end
									end)
								end
								return old(...)
							end
						else
							bedwars.ProjectileController.createLocalProjectile = old
						end
					end,
					Tooltip = 'Automatically crossbow macro\'s'
				})
			end)

			run(function()
				local PickupRange
				local Lower

				PickupRange = vapelite:CreateModule({
					Name = 'PickupRange',
					Function = function(callback)
						if callback then
							repeat
								if entitylib.isAlive then
									local localpos = entitylib.character.RootPart.Position
									for i, v in collectionService:GetTagged('ItemDrop') do
										if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end

										if (localpos - v.Position).Magnitude <= 6 then
											if Lower.Enabled and (localpos.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
											task.spawn(function()
												bedwars.Client:Get(bedwars.PickupRemote):CallServerAsync({
													itemDrop = v
												}):andThen(function(suc)
													if suc and bedwars.SoundList then
														bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
														local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
														if sound then
															bedwars.SoundManager:playSound(sound, {
																position = v.Position,
																volumeMultiplier = 0.9
															})
														end
													end
												end)
											end)
										end
									end
								end
								task.wait(0.1)
							until not PickupRange.Enabled
						end
					end,
					Tooltip = 'Picks up items faster'
				})
				Lower = PickupRange:CreateToggle({
					Name = 'Feet Check',
					Default = true
				})
			end)

			--[[
				World
			]]

			run(function()
				local old

				local function switchBlock(block)
					if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
						local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
						if tool then
							for i, v in store.inventory.hotbar do
								if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
							end

							if hotbarSwitch(slot) then
								if inputService:IsMouseButtonPressed(0) then
									clickEvent:Fire()
								end
								return true
							end
						end
					end
				end

				vapelite:CreateModule({
					Name = 'AutoTool',
					Function = function(callback)
						if callback then
							old = bedwars.BlockBreaker.hitBlock
							bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
								local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
								if switchBlock(block and block.target and block.target.blockInstance or nil) then return end
								return old(self, maid, raycastparams, ...)
							end
						else
							bedwars.BlockBreaker.hitBlock = old
							old = nil
						end
					end,
					Tooltip = 'Automatically selects the correct tool'
				})
			end)

			run(function()
				local ChestSteal
				local LootDelay
				local Delays = {}

				local function lootChest(chest)
					chest = chest and chest.Value or nil
					local chestitems = chest and chest:GetChildren() or {}

					if #chestitems > 1 then
						for _, v in chestitems do
							if v:IsA('Accessory') then
								if (Delays[v] or 0) > tick() then continue end
								Delays[v] = tick() + 0.5

								task.spawn(function()
									pcall(function()
										bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
									end)
								end)

								return
							end
						end
					end
				end

				ChestSteal = vapelite:CreateModule({
					Name = 'ChestSteal',
					Function = function(callback)
						if callback then
							repeat
								local open = bedwars.AppController:isAppOpen('ChestApp')
								if open then
									lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
								end
								task.wait(open and LootDelay.Value / 1000 or 0.1)
							until not ChestSteal.Enabled
						end
					end,
					Tooltip = 'Grabs items from near chests.'
				})
				LootDelay = ChestSteal:CreateSlider({
					Name = 'Loot Delay',
					Min = 1,
					Max = 500,
					Default = 250
				})
			end)
		end

		run(function()
			local Sprint
			local old

			Sprint = vapelite:CreateModule({
				Name = 'Sprint',
				Function = function(callback)
					if callback then
						old = bedwars.SprintController.stopSprinting
						bedwars.SprintController.stopSprinting = function(...)
							local call = old(...)
							bedwars.SprintController:startSprinting()
							return call
						end
						if entitylib then
							Sprint:Clean(entitylib.Events.LocalAdded:Connect(function()
								task.delay(0.1, function()
									bedwars.SprintController:stopSprinting()
								end)
							end))
						end
						bedwars.SprintController:stopSprinting()
					else
						bedwars.SprintController.stopSprinting = oldSprintFunction
						bedwars.SprintController:stopSprinting()
					end
				end,
				Tooltip = 'Sets your sprinting to true.'
			})
		end)

		run(function()
			local TextGUI
			local Sort = {Value = 1}
			local Font = {Value = 1}
			local Size = {Value = 16}
			local Shadow = {Enabled = true}
			local Watermark = {Enabled = true}
			local Rainbow = {Enabled = false}
			local VapeLabels = {}
			local VapeShadowLabels = {}
			local VapeLiteLogo = Drawing.new('Image')
			VapeLiteLogo.Data = shared.VapeDeveloper and readfile('VapeLiteLogo.png') or game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/VapeLiteForRoblox/main/VapeLiteLogo.png', true) or ''
			VapeLiteLogo.Size = Vector2.new(140, 64)
			VapeLiteLogo.ZIndex = 2
			VapeLiteLogo.Position = Vector2.new(3, 36)
			VapeLiteLogo.Visible = false
			local VapeLiteLogoShadow = Drawing.new('Image')
			VapeLiteLogoShadow.Data = shared.VapeDeveloper and readfile('VapeLiteLogoShadow.png') or game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/VapeLiteForRoblox/main/VapeLiteLogoShadow.png', true) or ''
			VapeLiteLogoShadow.Size = Vector2.new(140, 64)
			VapeLiteLogoShadow.Position = Vector2.new(5, 38)
			VapeLiteLogoShadow.ZIndex = 1
			VapeLiteLogoShadow.Visible = false

			local function getTextSize(str)
				local obj = Drawing.new('Text')
				obj.Text = str
				obj.Size = Size.Value
				local res = obj.TextBounds
				pcall(function() obj.Visible = false obj:Remove() end)
				return res
			end

			function vapelite:UpdateTextGUI()
				VapeLiteLogo.Visible = TextGUI.Enabled and Watermark.Enabled
				VapeLiteLogoShadow.Visible = TextGUI.Enabled and Watermark.Enabled and Shadow.Enabled
				VapeLiteLogo.Position = Vector2.new(gameCamera.ViewportSize.X - 160, 52 - (Watermark.Enabled and 0 or 64))
				VapeLiteLogoShadow.Position = VapeLiteLogo.Position + Vector2.new(1, 1)

				for _, v in VapeLabels do pcall(function() v.Visible = false v:Remove() end) end
				for _, v in VapeShadowLabels do pcall(function() v.Visible = false v:Remove() end) end

				if TextGUI.Enabled then
					local modulelist = {}
					for i, v in vapelite.Modules do
						if i ~= 'TextGUI' and v.Enabled then table.insert(modulelist, {Text = i, Size = getTextSize(i)}) end
					end

					if Sort.Value == 1 then
						table.sort(modulelist, function(a, b) return a.Size.X > b.Size.X end)
					else
						table.sort(modulelist, function(a, b) return a.Text < b.Text end)
					end

					local start = (VapeLiteLogo.Position + VapeLiteLogo.Size)
					local newY = 0
					for i, v in modulelist do
						local draw = Drawing.new('Text')
						draw.Position = Vector2.new(start.X - v.Size.X, start.Y + newY)
						draw.Color = Rainbow.Enabled and Color3.fromHSV((tick() / 4 + i * -0.05) % 1, 0.89, 1) or Color3.fromRGB(67, 117, 255)
						draw.Text = v.Text
						draw.Size = Size.Value
						draw.Font = math.clamp(Font.Value - 1, 0, 3)
						draw.ZIndex = 2
						draw.Visible = true

						if Shadow.Enabled then
							local drawshadow = Drawing.new('Text')
							drawshadow.Position = draw.Position + Vector2.new(1, 1)
							drawshadow.Color = Color3.fromRGB(22, 37, 81)
							drawshadow.Text = v.Text
							drawshadow.Size = draw.Size
							drawshadow.Font = draw.Font
							drawshadow.ZIndex = 1
							drawshadow.Visible = true
							table.insert(VapeShadowLabels, drawshadow)
						end

						table.insert(VapeLabels, draw)
						newY += v.Size.Y
					end
				end
			end

			TextGUI = vapelite:CreateModule({
				Name = 'TextGUI',
				Function = function(callback)
					if callback then
						TextGUI:Clean(gameCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
							vapelite:UpdateTextGUI()
						end))

						if Rainbow.Enabled then
							repeat
								for i, v in VapeLabels do
									v.Color = Color3.fromHSV((tick() / 4 + i * -0.05) % 1, 0.89, 1)
								end
								task.wait(0.016)
							until not TextGUI.Enabled or not Rainbow.Enabled
						end
					end
					vapelite:UpdateTextGUI()
				end,
				Tooltip = 'Displays enabled modules onscreen'
			})
			Sort = TextGUI:CreateSlider({
				Name = 'Sort',
				Min = 1,
				Max = 2,
				Function = function() vapelite:UpdateTextGUI() end
			})
			Font = TextGUI:CreateSlider({
				Name = 'Font',
				Min = 1,
				Max = 4,
				Function = function() vapelite:UpdateTextGUI() end
			})
			Size = TextGUI:CreateSlider({
				Name = 'Text Size',
				Min = 1,
				Max = 30,
				Default = 20,
				Function = function() vapelite:UpdateTextGUI() end
			})
			Shadow = TextGUI:CreateToggle({
				Name = 'Shadow',
				Function = function()
					vapelite:UpdateTextGUI()
				end,
				Default = true
			})
			Watermark = TextGUI:CreateToggle({
				Name = 'Watermark',
				Function = function()
					vapelite:UpdateTextGUI()
				end,
				Default = true
			})
			Rainbow = TextGUI:CreateToggle({
				Name = 'Rainbow',
				Function = function()
					TextGUI:Toggle()
					TextGUI:Toggle()
				end
			})
		end)
	end
end)

table.insert(vapelite.Connections, web.OnMessage:Connect(vapelite.Receive))
table.insert(vapelite.Connections, web.OnClose:Connect(vapelite.Uninject))
table.insert(vapelite.Connections, lplr.OnTeleport:Connect(function() vapelite.Uninject(true) end))
vapelite:Load()
