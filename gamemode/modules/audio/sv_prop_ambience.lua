local config = FF_CONFIG.Audio.PropAmbience
if not config.Enabled then return end

local categories = {
    {
        keys = { "tree", "foliage", "oak_" },
        sounds = {
            "dynamic_prop_sounds/tree_leaves-01.ogg",
            "dynamic_prop_sounds/tree_leaves-02.ogg",
            "dynamic_prop_sounds/tree_creak-03.ogg",
            "dynamic_prop_sounds/tree_creak-07.ogg",
            "dynamic_prop_sounds/treewind2.ogg",
        },
    },
    {
        keys = { "vent", "duct", "shaft" },
        sounds = {
            "dynamic_prop_sounds/vent-01.ogg",
            "dynamic_prop_sounds/vent-03.ogg",
            "dynamic_prop_sounds/shaft_noise-02.ogg",
            "dynamic_prop_sounds/shaft_rattle-04.ogg",
        },
    },
    {
        keys = { "computer", "monitor", "server", "harddrive", "console" },
        sounds = {
            "dynamic_prop_sounds/computer_idle-01.ogg",
            "dynamic_prop_sounds/computer_loop-02.ogg",
            "dynamic_prop_sounds/server_bip-03.ogg",
            "dynamic_prop_sounds/server_activity-04.ogg",
        },
    },
    {
        keys = { "fridge", "refrigerator", "vending", "freezer" },
        sounds = {
            "dynamic_prop_sounds/fridge_hum-01.ogg",
            "dynamic_prop_sounds/fridge_hum-03.ogg",
            "dynamic_prop_sounds/fridge_hum-05.ogg",
        },
    },
    {
        keys = { "radio", "receiver", "transmitter" },
        sounds = {
            "dynamic_prop_sounds/radio_tuning-01.ogg",
            "dynamic_prop_sounds/radio_distort-02.ogg",
            "dynamic_prop_sounds/generic_radio-03.ogg",
            "dynamic_prop_sounds/radio_voices-04.ogg",
        },
    },
    {
        keys = { "fluorescent", "light", "lamp" },
        sounds = {
            "dynamic_prop_sounds/flourescent_buzz-01.ogg",
            "dynamic_prop_sounds/flourescent_buzz-03.ogg",
            "dynamic_prop_sounds/light_flicker-02.ogg",
        },
    },
    {
        keys = { "fence", "chainlink", "gate" },
        sounds = {
            "dynamic_prop_sounds/fence_rattle-02.ogg",
            "dynamic_prop_sounds/fence_chainlink_rattle-03.ogg",
            "dynamic_prop_sounds/fence_chainlink_rattle-06.ogg",
        },
    },
    {
        keys = { "pipe", "radiator", "boiler" },
        sounds = {
            "dynamic_prop_sounds/pipe_hit-02.ogg",
            "dynamic_prop_sounds/pipe_hit-05.ogg",
            "dynamic_prop_sounds/radiator-03.ogg",
        },
    },
    {
        keys = { "washer", "washingmachine", "dryer" },
        sounds = {
            "dynamic_prop_sounds/washer_run-02.ogg",
            "dynamic_prop_sounds/dryer_run-01.ogg",
            "dynamic_prop_sounds/dryer_run-03.ogg",
        },
    },
    {
        keys = { "buoy", "boat", "dock" },
        sounds = {
            "dynamic_prop_sounds/buoy_bell-01.ogg",
            "dynamic_prop_sounds/buoy_ring-03.ogg",
            "dynamic_prop_sounds/boat_creak-02.ogg",
            "dynamic_prop_sounds/wood_creak-04.ogg",
        },
    },
    {
        keys = { "wood", "table", "cabinet", "shelf", "crate" },
        sounds = {
            "dynamic_prop_sounds/wood_int_creak-02.ogg",
            "dynamic_prop_sounds/wood_int_creak-07.ogg",
            "dynamic_prop_sounds/wood_light_creak-04.ogg",
        },
    },
    {
        keys = { "transformer", "generator", "power" },
        sounds = {
            "dynamic_prop_sounds/transformer_hum-01.ogg",
            "dynamic_prop_sounds/transformer_hum-04.ogg",
            "dynamic_prop_sounds/power_machine-02.ogg",
        },
    },
    {
        keys = { "acunit", "air_conditioner", "airconditioner" },
        sounds = {
            "dynamic_prop_sounds/air_conditioner-01.ogg",
            "dynamic_prop_sounds/air_conditioner-03.ogg",
        },
    },
}

local activeCount = 0
local tracked = setmetatable({}, { __mode = "k" })

local function findCategory(model)
    model = string.lower(model or "")
    if model == "" then return nil end

    for _, category in ipairs(categories) do
        for _, key in ipairs(category.keys) do
            if string.find(model, key, 1, true) then
                return category
            end
        end
    end
end

local function timerName(entity)
    return "FF_PropAmbience_" .. entity:EntIndex() .. "_" .. entity:GetCreationID()
end

local function schedule(entity, category)
    if not IsValid(entity) then return end

    local name = timerName(entity)
    timer.Create(name, math.Rand(config.MinimumDelay, config.MaximumDelay), 1, function()
        if not IsValid(entity) then
            activeCount = math.max(0, activeCount - 1)
            return
        end

        entity:EmitSound(
            table.Random(category.sounds),
            config.SoundLevel,
            math.random(94, 106),
            config.Volume,
            CHAN_STATIC
        )
        schedule(entity, category)
    end)
end

local function consider(entity)
    if activeCount >= config.MaximumActiveProps then return end
    if not IsValid(entity) or tracked[entity] then return end

    local model = entity:GetModel()
    local category = findCategory(model)
    if not category then return end

    tracked[entity] = true
    activeCount = activeCount + 1
    schedule(entity, category)
end

hook.Add("OnEntityCreated", "FF_TrackAmbientProps", function(entity)
    timer.Simple(0, function()
        consider(entity)
    end)
end)

hook.Add("EntityRemoved", "FF_CleanupAmbientProp", function(entity)
    if not tracked[entity] then return end
    timer.Remove(timerName(entity))
    tracked[entity] = nil
    activeCount = math.max(0, activeCount - 1)
end)

timer.Create("FF_ScanAmbientProps", config.ScanInterval, 0, function()
    if activeCount >= config.MaximumActiveProps then return end

    for _, entity in ipairs(ents.GetAll()) do
        consider(entity)
        if activeCount >= config.MaximumActiveProps then break end
    end
end)
