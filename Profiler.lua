-------------------------------------------------------------------------------
--  /aucx perf [seconds]: finds which addons cost frame time while a tooltip is
--  open. Samples every loaded addon's CPU time each frame (C_AddOnProfiler,
--  LastTime metric) for a few seconds, split by whether GameTooltip was shown,
--  then prints the addons whose cost rises the most with the tooltip open.
--  Move the mouse on and off items while it runs, so both cases get frames.
--  Sampling itself costs a little, and that cost is billed to this addon.
-------------------------------------------------------------------------------
local _, ns = ...

local DEFAULT_SECONDS = 8
local TOP = 10

local function Supported()
    return C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric
        and Enum.AddOnProfilerMetric.LastTime and C_AddOns and C_AddOns.GetNumAddOns
end

local running

local function Report(names, sums, frames, overall)
    local rows = {}
    for i, name in ipairs(names) do
        local shown = frames.shown > 0 and sums.shown[i] / frames.shown or 0
        local hidden = frames.hidden > 0 and sums.hidden[i] / frames.hidden or 0
        rows[#rows + 1] = { name = name, shown = shown, hidden = hidden, delta = shown - hidden }
    end
    table.sort(rows, function(a, b) return a.delta > b.delta end)

    ns.Print(string.format("frames with tooltip: %d, without: %d. Average ms per frame (with / without tooltip):",
        frames.shown, frames.hidden))
    if overall then
        local s = frames.shown > 0 and overall.shown / frames.shown or 0
        local h = frames.hidden > 0 and overall.hidden / frames.hidden or 0
        print(string.format("  |cffffd100All addons|r  %.3f / %.3f  (+%.3f)", s, h, s - h))
    end
    for i = 1, math.min(TOP, #rows) do
        local r = rows[i]
        print(string.format("  %s  %.3f / %.3f  (%+.3f)", r.name, r.shown, r.hidden, r.delta))
    end
    if frames.shown == 0 or frames.hidden == 0 then
        ns.Print("hover items (and move off them) while it measures, so both columns get frames.")
    end
end

local function Start(seconds)
    if running then ns.Print("already measuring.") return end
    if not Supported() then ns.Print("this client has no addon profiler (C_AddOnProfiler).") return end
    if C_AddOnProfiler.IsEnabled and not C_AddOnProfiler.IsEnabled() then
        ns.Print("the addon profiler is disabled in this client.") return
    end

    local names = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(name) then names[#names + 1] = name end
    end
    local metric = Enum.AddOnProfilerMetric.LastTime
    local sums = { shown = {}, hidden = {} }
    for i = 1, #names do sums.shown[i], sums.hidden[i] = 0, 0 end
    local frames = { shown = 0, hidden = 0 }
    local overall = C_AddOnProfiler.GetOverallMetric and { shown = 0, hidden = 0 } or nil

    running = CreateFrame("Frame")
    local endTime = GetTime() + seconds
    running:SetScript("OnUpdate", function(self)
        local key = GameTooltip:IsShown() and "shown" or "hidden"
        frames[key] = frames[key] + 1
        local bucket = sums[key]
        for i = 1, #names do
            bucket[i] = bucket[i] + (C_AddOnProfiler.GetAddOnMetric(names[i], metric) or 0)
        end
        if overall then overall[key] = overall[key] + (C_AddOnProfiler.GetOverallMetric(metric) or 0) end
        if GetTime() >= endTime then
            self:SetScript("OnUpdate", nil)
            running = nil
            Report(names, sums, frames, overall)
        end
    end)
    ns.Print(string.format("measuring for %d s: hover items and move off them...", seconds))
end

ns.RegisterSlash("perf", function(rest)
    local seconds = tonumber(rest) or DEFAULT_SECONDS
    Start(math.max(2, math.min(60, seconds)))
end)
