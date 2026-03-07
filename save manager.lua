local httpService = game:GetService("HttpService")

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				local value = false
				if object and object.Value ~= nil then
					value = object.Value
				end
				return { type = "Toggle", idx = idx, value = value } 
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					local option = SaveManager.Options[idx]
					if type(option.SetValue) == "function" then
						pcall(function() option:SetValue(data.value) end)
					end
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				local value = "0"
				if object and object.Value ~= nil then
					value = tostring(object.Value)
				end
				return { type = "Slider", idx = idx, value = value }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					local option = SaveManager.Options[idx]
					if type(option.SetValue) == "function" then
						pcall(function() option:SetValue(tonumber(data.value) or 0) end)
					end
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				local value = nil
				local multi = false
				if object then
					if object.Value ~= nil then value = object.Value end
					if object.Multi ~= nil then multi = object.Multi end
				end
				return { type = "Dropdown", idx = idx, value = value, multi = multi }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					local option = SaveManager.Options[idx]
					if type(option.SetValue) == "function" then
						pcall(function() option:SetValue(data.value) end)
					end
				end
			end,
		},
		Colorpicker = {
			Save = function(idx, object)
				local hexValue = "#FFFFFF"
				if object and object.Value then
					local success, result = pcall(function()
						local r = math.floor(object.Value.R * 255)
						local g = math.floor(object.Value.G * 255)
						local b = math.floor(object.Value.B * 255)
						return string.format("%02x%02x%02x", r, g, b)
					end)
					if success and result then hexValue = "#" .. result end
				end
				return { type = "Colorpicker", idx = idx, value = hexValue, transparency = (object and object.Transparency) or 0 }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					local option = SaveManager.Options[idx]
					if type(option.SetValueRGB) == "function" then
						local color3Value = Color3.new(1, 1, 1)
						if type(data.value) == "string" and string.sub(data.value, 1, 1) == "#" then
							local hexStr = string.sub(data.value, 2)
							if #hexStr == 6 then
								local r = tonumber(string.sub(hexStr, 1, 2), 16) or 255
								local g = tonumber(string.sub(hexStr, 3, 4), 16) or 255
								local b = tonumber(string.sub(hexStr, 5, 6), 16) or 255
								color3Value = Color3.fromRGB(r, g, b)
							end
						end
						pcall(function() option:SetValueRGB(color3Value, data.transparency or 0) end)
					elseif type(option.SetValue) == "function" then
						pcall(function() option:SetValue(data.value) end)
					end
				end
			end,
		},
		Keybind = {
			Save = function(idx, object)
				local mode = "None"
				local key = Enum.KeyCode.Unknown
				if object then
					if type(object.Mode) == "string" then mode = object.Mode end
					if object.Value then key = object.Value end
				end
				return { type = "Keybind", idx = idx, mode = mode, key = tostring(key) }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then
					local option = SaveManager.Options[idx]
					if type(option.SetValue) == "function" then
						pcall(function() option:SetValue(data.key, data.mode) end)
					end
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				local text = ""
				if object and object.Value then
					text = tostring(object.Value)
				end
				return { type = "Input", idx = idx, text = text }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and type(data.text) == "string" then
					local option = SaveManager.Options[idx]
					if type(option.SetValue) == "function" then
						pcall(function() option:SetValue(data.text) end)
					end
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, "no config file is selected"
		end

		local fullPath = self.Folder .. "/settings/" .. name .. ".json"

		local data = {
			objects = {}
		}

		for idx, option in next, SaveManager.Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			if type(self.Parser[option.Type].Save) == "function" then
				local success, saved_data = pcall(function() return self.Parser[option.Type].Save(idx, option) end)
				if success and saved_data then
					table.insert(data.objects, saved_data)
				end
			end
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "failed to encode data"
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, "no config file is selected"
		end
		
		local file = self.Folder .. "/settings/" .. name .. ".json"
		if not isfile(file) then return false, "invalid file" end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, "decode error" end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] and type(self.Parser[option.type].Load) == "function" then
				task.spawn(function() 
					pcall(function() self.Parser[option.type].Load(option.idx, option) end)
				end)
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. "/settings"
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. "/settings")

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local pos = file:find(".json", 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= "/" and char ~= "\\" and char ~= "" do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == "/" or char == "\\" then
					local name = file:sub(pos + 1, start - 1)
					if name ~= "options" then
						table.insert(out, name)
					end
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
        self.Options = library.Options
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. "/settings/autoload.txt") then
			local name = readfile(self.Folder .. "/settings/autoload.txt")

			local success, err = self:Load(name)
			if not success then
				if self.Library and type(self.Library.Notify) == "function" then
					self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to load autoload config: " .. err,
						Duration = 7
					})
				end
				return
			end

			if self.Library and type(self.Library.Notify) == "function" then
				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Auto loaded config %q", name),
					Duration = 7
				})
			end
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Must set SaveManager.Library")

		if not tab or type(tab) ~= "table" or type(tab.AddSection) ~= "function" then
			warn("[SaveManager] Invalid tab object provided")
			return
		end

		local section = tab:AddSection("Configuration")
		
		if not section or type(section) ~= "table" then
			warn("[SaveManager] Failed to create Configuration section")
			return
		end

		if type(section.AddInput) == "function" then
			section:AddInput("SaveManager_ConfigName",    { Title = "Config name" })
		end
		
		if type(section.AddDropdown) == "function" then
			section:AddDropdown("SaveManager_ConfigList", { Title = "Config list", Values = self:RefreshConfigList(), AllowNull = true })
		end

		if type(section.AddButton) == "function" then
			section:AddButton({
	            Title = "Create config",
	            Callback = function()
	                local configNameObj = SaveManager.Options and SaveManager.Options.SaveManager_ConfigName
	                local name = configNameObj and configNameObj.Value or ""

	                if not name or name:gsub(" ", "") == "" then 
	                    if self.Library and type(self.Library.Notify) == "function" then
							pcall(function() self.Library:Notify({
								Title = "Interface",
								Content = "Config loader",
								SubContent = "Invalid config name (empty)",
								Duration = 7
							}) end)
						end
	                    return
	                end

	                local success, err = self:Save(name)
	                if not success then
	                    if self.Library and type(self.Library.Notify) == "function" then
							pcall(function() self.Library:Notify({
								Title = "Interface",
								Content = "Config loader",
								SubContent = "Failed to save config: " .. tostring(err),
								Duration = 7
							}) end)
						end
	                    return
	                end

					if self.Library and type(self.Library.Notify) == "function" then
						pcall(function() self.Library:Notify({
							Title = "Interface",
							Content = "Config loader",
							SubContent = string.format("Created config %q", name),
							Duration = 7
						}) end)
					end

	                local configListObj = SaveManager.Options and SaveManager.Options.SaveManager_ConfigList
	                if configListObj and type(configListObj.SetValues) == "function" and type(configListObj.SetValue) == "function" then
	                	pcall(function() configListObj:SetValues(self:RefreshConfigList()) end)
	                	pcall(function() configListObj:SetValue(nil) end)
	                end
	            end
	        })

	        section:AddButton({
	        	Title = "Load config", 
	        	Callback = function()
					local configListObj = SaveManager.Options and SaveManager.Options.SaveManager_ConfigList
					local name = configListObj and configListObj.Value or nil

					if not name then
						if self.Library and type(self.Library.Notify) == "function" then
							pcall(function() self.Library:Notify({
								Title = "Interface",
								Content = "Config loader",
								SubContent = "No config selected",
								Duration = 7
							}) end)
						end
						return
					end

					local success, err = self:Load(name)
					if not success then
						if self.Library and type(self.Library.Notify) == "function" then
							pcall(function() self.Library:Notify({
								Title = "Interface",
								Content = "Config loader",
								SubContent = "Failed to load config: " .. tostring(err),
								Duration = 7
							}) end)
						end
						return
					end

					if self.Library and type(self.Library.Notify) == "function" then
						pcall(function() self.Library:Notify({
							Title = "Interface",
							Content = "Config loader",
							SubContent = string.format("Loaded config %q", name),
							Duration = 7
						}) end)
					end
				end
			})

			section:AddButton({
				Title = "Overwrite config",
				Callback = function()
					local configListObj = SaveManager.Options and SaveManager.Options.SaveManager_ConfigList
					local name = configListObj and configListObj.Value or nil

					if not name then
						if self.Library and type(self.Library.Notify) == "function" then
							pcall(function() self.Library:Notify({
								Title = "Interface",
								Content = "Config loader",
								SubContent = "No config selected",
								Duration = 7
							}) end)
						end
						return
					end

					local success, err = self:Save(name)
					if not success then
						if self.Library and type(self.Library.Notify) == "function" then
							pcall(function() self.Library:Notify({
								Title = "Interface",
								Content = "Config loader",
								SubContent = "Failed to overwrite config: " .. tostring(err),
								Duration = 7
							}) end)
						end
						return
					end

					if self.Library and type(self.Library.Notify) == "function" then
						pcall(function() self.Library:Notify({
							Title = "Interface",
							Content = "Config loader",
							SubContent = string.format("Overwrote config %q", name),
							Duration = 7
						}) end)
					end
				end
			})

			section:AddButton({
				Title = "Refresh list",
				Callback = function()
					local configListObj = SaveManager.Options and SaveManager.Options.SaveManager_ConfigList
					if configListObj and type(configListObj.SetValues) == "function" and type(configListObj.SetValue) == "function" then
						pcall(function() configListObj:SetValues(self:RefreshConfigList()) end)
						pcall(function() configListObj:SetValue(nil) end)
					end
				end
			})

			local AutoloadButton = section:AddButton({
				Title = "Set as autoload",
				Description = "Current autoload config: none",
				Callback = function()
					local configListObj = SaveManager.Options and SaveManager.Options.SaveManager_ConfigList
					local name = configListObj and configListObj.Value or nil

					if not name then
						if self.Library and type(self.Library.Notify) == "function" then
							pcall(function() self.Library:Notify({
								Title = "Interface",
								Content = "Config loader",
								SubContent = "No config selected",
								Duration = 7
							}) end)
						end
						return
					end

					if type(AutoloadButton.SetDesc) == "function" then
						pcall(function() 
							writefile(self.Folder .. "/settings/autoload.txt", name)
							AutoloadButton:SetDesc("Current autoload config: " .. name)
						end)
					else
						pcall(function()
							writefile(self.Folder .. "/settings/autoload.txt", name)
						end)
					end

					if self.Library and type(self.Library.Notify) == "function" then
						pcall(function() self.Library:Notify({
							Title = "Interface",
							Content = "Config loader",
							SubContent = string.format("Set %q to auto load", name),
							Duration = 7
						}) end)
					end
				end
			})

			if isfile(self.Folder .. "/settings/autoload.txt") then
				local autoloadName = readfile(self.Folder .. "/settings/autoload.txt")
				if AutoloadButton and type(AutoloadButton.SetDesc) == "function" then
					pcall(function() AutoloadButton:SetDesc("Current autoload config: " .. (autoloadName or "unknown")) end)
				end
			end
		end

		SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
