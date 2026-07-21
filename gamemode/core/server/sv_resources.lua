local contentRoot = "gamemodes/foundfootage/content"

local function addDirectory(relativePath)
    local searchPath = contentRoot .. "/" .. relativePath
    local files, directories = file.Find(searchPath .. "/*", "GAME")

    for _, name in ipairs(files) do
        resource.AddFile(relativePath .. "/" .. name)
    end

    for _, name in ipairs(directories) do
        addDirectory(relativePath .. "/" .. name)
    end
end

for _, directory in ipairs({ "sound", "materials", "models", "particles", "resource", "shaders" }) do
    addDirectory(directory)
end

local backgroundRoot = "gamemodes/foundfootage/backgrounds"
local backgroundFiles = file.Find(backgroundRoot .. "/*", "GAME")

for _, name in ipairs(backgroundFiles) do
    resource.AddFile(backgroundRoot .. "/" .. name)
end
