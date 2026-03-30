local httpService = game:GetService("HttpService")

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	-- In-memory storage to avoid exploit-only APIs
	SaveManager.Memory = {}

	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) return { type = "Toggle", idx = idx, value = object.Value } end,
			Load = function(idx, data) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(data.value) end end,
		},
		Slider = {
			Save = function(idx, object) return { type = "Slider", idx = idx, value = tostring(object.Value) } end,
			Load = function(idx, data) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(data.value) end end,
		},
		Dropdown = {
			Save = function(idx, object) return { type = "Dropdown", idx = idx, value = object.Value, multi = object.Multi } end,
			Load = function(idx, data) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValue(data.value) end end,
		},
		Colorpicker = {
			Save = function(idx, object) return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency } end,
			Load = function(idx, data) if SaveManager.Options[idx] then SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency) end end,
		},
		Keybind = {
			Save = function(idx, object) return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value, toggled = object.Toggled } end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					if data.toggled ~= nil then SaveManager.Options[idx].Toggled = data.toggled end
					SaveManager.Options[idx]:SetValue(data.key, data.mode)
				end
			end,
		},
		Input = {
			Save = function(idx, object) return { type = "Input", idx = idx, text = object.Value } end,
			Load = function(idx, data) if SaveManager.Options[idx] and type(data.text) == "string" then SaveManager.Options[idx]:SetValue(data.text) end end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do self.Ignore[key] = true end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self.Memory = self.Memory or {}
	end

	function SaveManager:Save(name)
		if not name then return false, "no config file is selected" end

		local data = { objects = {} }
		for idx, option in next, (SaveManager.Options or {}) do
			if self.Parser[option.Type] and not self.Ignore[idx] then
				table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
			end
		end

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then return false, "failed to encode data" end

		self.Memory = self.Memory or {}
		self.Memory[name] = encoded
		return true
	end

	function SaveManager:Load(name)
		if not name then return false, "no config file is selected" end
		self.Memory = self.Memory or {}
		local raw = self.Memory[name]
		if not raw then return false, "Create Config Save File" end
		local success, decoded = pcall(httpService.JSONDecode, httpService, raw)
		if not success then return false, "decode error" end

		for _, option in next, (decoded.objects or {}) do
			if self.Parser[option.type] and not self.Ignore[option.idx] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end)
			end
		end

		if self.Library then self.Library.SettingLoaded = true end
		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ "InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind" })
	end

	function SaveManager:BuildFolderTree()
		-- No filesystem in use; initialize memory bucket
		self.Memory = self.Memory or {}
	end

	function SaveManager:RefreshConfigList()
		self.Memory = self.Memory or {}
		local out = {}
		for name, _ in pairs(self.Memory) do
			if type(name) == "string" and name ~= "options" and name ~= "__autoload" then
				table.insert(out, name)
			end
		end
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Options = library.Options
	end

	function SaveManager:LoadAutoloadConfig()
		self.Memory = self.Memory or {}
		local name = self.Memory.__autoload
		if name and type(name) == "string" then
			local success, err = self:Load(name)
			if not success and self.Library and type(self.Library.Notify) == "function" then
				self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = "Failed to load autoload config: " .. err, Duration = 7 })
			end
			if self.Library and type(self.Library.Notify) == "function" then
				self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = string.format("Auto loaded config %q", name), Duration = 7 })
			end
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Must set SaveManager.Library")
		local section = tab:AddSection("Configuration", "settings")

		section:AddInput("SaveManager_ConfigName", { Title = "Config name" })
		section:AddDropdown("SaveManager_ConfigList", { Title = "Config list", Values = self:RefreshConfigList(), AllowNull = true })

		section:AddButton({ Title = "Create config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigName.Value
			if name:gsub(" ", "") == "" then
				return self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = "Invalid config name (empty)", Duration = 7 })
			end
			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = "Failed to save config: " .. err, Duration = 7 })
			end
			self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = string.format("Created config %q", name), Duration = 7 })
			SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
		end })

		section:AddButton({ Title = "Load config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value
			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = "Failed to load config: " .. err, Duration = 7 })
			end
			self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = string.format("Loaded config %q", name), Duration = 7 })
		end })

		section:AddButton({ Title = "Save config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value
			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = "Failed to overwrite config: " .. err, Duration = 7 })
			end
			self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = string.format("Overwrote config %q", name), Duration = 7 })
		end })

		section:AddButton({ Title = "Refresh list", Callback = function()
			SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
		end })

		local AutoloadButton
		AutoloadButton = section:AddButton({ Title = "Set as autoload", Description = "Current autoload config: none", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value
			self.Memory = self.Memory or {}
			self.Memory.__autoload = name
			AutoloadButton:SetDesc("Current autoload config: " .. tostring(name))
			self.Library:Notify({ Title = "Interface", Content = "Config loader", SubContent = string.format("Set %q to auto load", name), Duration = 7 })
		end })

		self.Memory = self.Memory or {}
		if self.Memory.__autoload then AutoloadButton:SetDesc("Current autoload config: " .. tostring(self.Memory.__autoload)) end

		SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
