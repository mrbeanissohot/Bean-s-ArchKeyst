local CONFIG = [==[
{
  "replacement_rules": [
    { "name": "keyst body", "replace_ids": [13236207101], "mode": "cdn", "enabled": true,
      "cdn_url": "https://github.com/mrbeanissohot/Bean-s-ArchKeyst/raw/refs/heads/main/keyst_body.mesh", "scale": 2, "texture": "arch" },
    { "name": "remove", "replace_ids": [13236207177, 14653273948, 13236206962], "mode": "id", "enabled": true },
    { "name": "keyst mag", "replace_ids": [13236206914], "mode": "cdn", "enabled": true,
      "cdn_url": "https://github.com/mrbeanissohot/Bean-s-ArchKeyst/raw/refs/heads/main/keyst_mag.mesh", "scale": 2, "texture": "arch" },
    { "name": "keyst equip animation", "replace_ids": [13204376695], "mode": "id", "enabled": true, "with_id": 105402901613987 },
    { "name": "keyst idle animation", "replace_ids": [13204384262], "mode": "id", "enabled": true, "with_id": 93156459127482 },
    { "name": "keyst sprint animation", "replace_ids": [13204420463], "mode": "id", "enabled": true, "with_id": 123663852199231 },
    { "name": "keyst inspect animation", "replace_ids": [13204401654], "mode": "id", "enabled": true, "with_id": 130335149853469 },
    { "name": "keyst shot animation 1", "replace_ids": [13204428113], "mode": "id", "enabled": true, "with_id": 93585501212722 },
    { "name": "keyst reload animation", "replace_ids": [13204413250], "mode": "id", "enabled": true, "with_id": 73026124060302 },
    { "name": "keyst inspect / reload sound", "replace_ids": [13236549929, 13236549962], "mode": "id", "enabled": true, "with_id": 118906938239363 },
    { "name": "asset replace (icon)", "replace_ids": [17160801983], "mode": "local", "enabled": false, "local_path": "ArchKeyst/gun_yellow_256_v2.png" },
    { "name": "Profile 12 (shoot sound)", "replace_ids": [13087362838], "mode": "cdn", "enabled": true,
      "cdn_url": "https://github.com/rythmplayzyt/so-meshed-up/raw/refs/heads/main/BONECLAWSHOOT.oga" },
    { "name": "Profile 13 (last part)", "replace_ids": [13236207230], "mode": "local", "enabled": false, "local_path": "ArchKeyst/last_part.mesh", "scale": 2, "texture": "arch" }
  ]
}
]==]

local FOLDER = "ArchKeyst"
local CDN_FOLDER = "ArchKeyst/cache"
local MESH_METHOD = "both"  -- "both", "direct" or "apply" (try another if meshes don't show)
local REFRESH = false       -- true = delete cached downloads and download everything again

local TEX_URLS = {
	arch = "https://github.com/mrbeanissohot/Bean-s-ArchKeyst/raw/refs/heads/main/arch_green_black.png",
}

---------------------------------------------------------------------
-- environment check
---------------------------------------------------------------------
local missing = {}
for _, p in ipairs({
	{ "isfile", isfile }, { "writefile", writefile },
	{ "getcustomasset", getcustomasset }, { "makefolder", makefolder }, { "isfolder", isfolder },
}) do
	if type(p[2]) ~= "function" then missing[#missing + 1] = p[1] end
end
if #missing > 0 then
	warn("[ArchKeyst] Delta is missing: " .. table.concat(missing, ", ") .. " - cannot run")
	return
end

if not isfolder(FOLDER) then pcall(makefolder, FOLDER) end
if not isfolder(CDN_FOLDER) then pcall(makefolder, CDN_FOLDER) end

if REFRESH and listfiles and delfile then
	for _, f in ipairs(listfiles(CDN_FOLDER)) do pcall(delfile, f) end
	print("[ArchKeyst] cache cleared")
end

---------------------------------------------------------------------
-- asset loading (local files + GitHub downloads)
---------------------------------------------------------------------
local function hashStr(s)
	local h = 5381
	for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
	return string.format("%08x", h)
end

local function download(url)
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and type(res) == "string" and #res > 0 then return res end
	local req = request or http_request or (syn and syn.request)
	if req then
		local ok2, r = pcall(req, { Url = url, Method = "GET" })
		if ok2 and r and r.StatusCode == 200 and type(r.Body) == "string" and #r.Body > 0 then
			return r.Body
		end
	end
	return nil
end

local stats = { cached = 0, downloaded = 0, failed = 0 }
local failedList = {}
local cdnAssets = {}
local cache = {}

-- retry: first load of a file can fail
local function loadAsset(path)
	if cache[path] then return cache[path] end
	if not isfile(path) then return nil, "file not found" end
	for _ = 1, 5 do
		local ok, asset = pcall(getcustomasset, path)
		if ok and asset then
			cache[path] = asset
			return asset
		end
		task.wait(0.3)
	end
	return nil, "getcustomasset failed"
end

local function loadCdn(url)
	if cdnAssets[url] then return cdnAssets[url] end

	local clean = (url:gsub("%?.*$", "")) -- ignore ?raw=true etc.
	local name = (clean:match("[^/]+$") or clean):gsub("%%20", " ")
	local ext = (clean:match("%.(%w+)$") or "bin"):lower()
	if ext == "oga" then ext = "ogg" end -- Roblox recognizes .ogg
	local path = CDN_FOLDER .. "/" .. hashStr(url) .. "." .. ext

	local function fail(reason)
		stats.failed += 1
		failedList[#failedList + 1] = name .. " (" .. reason .. ")"
		return nil
	end

	if isfile(path) then
		stats.cached += 1
	else
		print("[ArchKeyst] downloading " .. name)
		local data = download(url)
		if not data then return fail("download failed") end
		-- GitHub returns a tiny "404: Not Found" text for bad links
		if #data < 200 and data:find("404") then return fail("404 not found") end
		-- catch accidental HTML pages (e.g. /blob/ links instead of /raw/)
		if data:sub(1, 15):lower():find("<!doctype") or data:sub(1, 6):lower():find("<html") then
			return fail("got HTML, use a raw link")
		end
		if not pcall(writefile, path, data) then return fail("could not save") end
		stats.downloaded += 1
	end

	local asset, err = loadAsset(path)
	if not asset then return fail(err) end
	cdnAssets[url] = asset
	return asset
end

---------------------------------------------------------------------
-- rules
---------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local rules = HttpService:JSONDecode(CONFIG).replacement_rules
local lookup, meshCache = {}, {}
local scaleById, textureById = {}, {}
local registered, swapped = 0, 0

local function parseId(v)
	return tonumber(tostring(v):match("(%d+)"))
end

local function resolve(rule)
	if rule.mode == "local" then
		local asset, err = loadAsset(rule.local_path)
		if not asset then
			stats.failed += 1
			failedList[#failedList + 1] = rule.local_path .. " (" .. err .. ")"
		end
		return asset
	elseif rule.mode == "cdn" then
		return loadCdn(rule.cdn_url)
	end
	if rule.with_id then return "rbxassetid://" .. rule.with_id end
	return ""
end

local function register(rule)
	if rule.type == "group" then
		for _, c in ipairs(rule.children or {}) do register(c) end
	elseif rule.enabled then
		local target = resolve(rule)
		if target == nil then return end
		registered += 1
		for _, id in ipairs(rule.replace_ids) do
			local n = parseId(id)
			if n then
				lookup[n] = target
				if rule.scale then scaleById[n] = rule.scale end
				if rule.texture then textureById[n] = rule.texture end
			end
		end
	end
end

for _, r in ipairs(rules) do register(r) end

local TEXTURES = {
	arch = loadCdn(TEX_URLS.arch),
}
if not TEXTURES.arch then
	warn("[ArchKeyst] texture not loaded")
end

print(("[ArchKeyst] rules ready: %d | cached: %d | downloaded: %d | failed: %d"):format(
	registered, stats.cached, stats.downloaded, stats.failed))
for _, f in ipairs(failedList) do warn("[ArchKeyst] FAILED: " .. f) end

---------------------------------------------------------------------
-- apply to the game
---------------------------------------------------------------------
local PROPS = {
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	Sound = { "SoundId" },
	Animation = { "AnimationId" },
	Decal = { "Texture" },
	Texture = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image" },
	SurfaceAppearance = { "ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap" },
}

local seen = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local lastScaled = setmetatable({}, { __mode = "k" })

-- multiply size by mult once (won't stack on re-applies)
local function scaleMesh(inst, mult)
	pcall(function()
		if inst:IsA("MeshPart") then
			local last = lastScaled[inst]
			if last and (inst.Size - last).Magnitude < 0.001 then return end
			local target = inst.Size * mult
			inst.Size = target
			lastScaled[inst] = target
		elseif inst:IsA("SpecialMesh") then
			local last = lastScaled[inst]
			if last and (inst.Scale - last).Magnitude < 0.001 then return end
			local target = inst.Scale * mult
			inst.Scale = target
			lastScaled[inst] = target
		end
	end)
end

-- put the green/black texture on a swapped mesh and keep it there
local function applyTexture(inst, kind)
	local tex = TEXTURES[kind]
	if not tex then return end
	local prop = inst:IsA("MeshPart") and "TextureID" or "TextureId"
	pcall(function() inst[prop] = tex end)
	for _, c in ipairs(inst:GetChildren()) do
		if c:IsA("SurfaceAppearance") then c:Destroy() end
	end
	if not watched[inst] then
		watched[inst] = true
		inst.ChildAdded:Connect(function(c)
			if c:IsA("SurfaceAppearance") then
				task.defer(function() pcall(function() c:Destroy() end) end)
			end
		end)
		pcall(function()
			inst:GetPropertyChangedSignal(prop):Connect(function()
				if inst[prop] ~= tex then
					pcall(function() inst[prop] = tex end)
				end
			end)
		end)
	end
end

local function hideMesh(inst)
	pcall(function()
		if inst:IsA("MeshPart") then
			inst.Transparency = 1
		elseif inst:IsA("SpecialMesh") then
			inst.Scale = Vector3.new(0, 0, 0)
		end
	end)
end

local function applyMesh(inst, asset)
	if not inst:IsA("MeshPart") then
		pcall(function() inst.MeshId = asset end)
		return
	end
	if MESH_METHOD ~= "apply" then
		pcall(function() inst.MeshId = asset end)
	end
	if MESH_METHOD ~= "direct" then
		local ok, err = pcall(function()
			local mp = meshCache[asset]
			if not mp then
				mp = AssetService:CreateMeshPartAsync(asset)
				meshCache[asset] = mp
			end
			inst:ApplyMesh(mp)
		end)
		if not ok then warn("[ArchKeyst] ApplyMesh failed: " .. tostring(err)) end
	end
end

local function handle(inst, p)
	local ok, cur = pcall(function() return inst[p] end)
	if not ok then return end
	local id = parseId(cur)
	local new = id and lookup[id]
	if new == nil then return end

	swapped += 1
	if swapped <= 15 then
		print("[ArchKeyst] swapped " .. inst.ClassName .. "." .. p .. " (" .. tostring(id) .. ")")
	end

	if p == "MeshId" then
		if new == "" then
			hideMesh(inst)
		else
			applyMesh(inst, new)
			if scaleById[id] then scaleMesh(inst, scaleById[id]) end
			if textureById[id] then applyTexture(inst, textureById[id]) end
		end
	else
		pcall(function() inst[p] = new end)
	end
end

local function apply(inst)
	local props = PROPS[inst.ClassName]
	if not props or seen[inst] then return end
	seen[inst] = true
	for _, p in ipairs(props) do
		handle(inst, p)
		pcall(function()
			inst:GetPropertyChangedSignal(p):Connect(function()
				handle(inst, p)
			end)
		end)
	end
end

local function scan()
	local n = 0
	for _, d in ipairs(game:GetDescendants()) do
		apply(d)
		n += 1
		if n % 2000 == 0 then task.wait() end
	end
end

scan()
game.DescendantAdded:Connect(apply)

-- catch parts that load late
task.spawn(function()
	while true do
		task.wait(5)
		scan()
	end
end)

print("[ArchKeyst] loaded")
