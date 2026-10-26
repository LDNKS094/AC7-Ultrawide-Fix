-- Correct final UI canvases at creation, with bounded retries for unfinished widget trees.
local UEHelpers=require("UEHelpers")
local pending=false
local function safe(fn) local ok,value=pcall(fn);if ok then return value end end
local function valid(o) return o~=nil and safe(function() return o:IsValid() end)==true end
local function log(s) print("[AC7UIAspect] "..tostring(s).."\n") end
local sourceDir=assert(debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])"))
local fixOverlay=function() end
local overlayOk,overlayFactory=pcall(function() return assert(loadfile(sourceDir.."overlay_geometry.lua"))() end)
if overlayOk then fixOverlay=overlayFactory(log) else log("Overlay helper unavailable: "..tostring(overlayFactory)) end
local fixLoading,isCanvas,canvasClasses=function() end,function() end,{}
local loadingOk,loadingFactory=pcall(function() return assert(loadfile(sourceDir.."loading_geometry.lua"))() end)
if loadingOk then fixLoading,isCanvas,canvasClasses=loadingFactory(log) else log("Canvas helper unavailable: "..tostring(loadingFactory)) end
local lastGeometry
local function geometry(context)
    local pc=safe(function() return UEHelpers.GetPlayerController() end)
    if not valid(pc) then pc=context end
    local layout=safe(function() return StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary") end)
    if valid(pc) and valid(layout) then
        local size=safe(function() return layout:GetViewportSize(pc) end)
        local w=safe(function() return size.X end)
        local h=safe(function() return size.Y end)
        local dpi=safe(function() return layout:GetViewportScale(pc) end)
        if type(w)=="number" and type(h)=="number" and w>0 and h>0 then
            if type(dpi)=="number" and dpi>0 then lastGeometry={w,h,dpi} end
            return w,h,dpi
        end
    end
    if lastGeometry then return table.unpack(lastGeometry) end
end
local function apply()
    local w,h,dpi=geometry()
    if type(w)~="number" or type(h)~="number" or h<=0 or w/h<=16/9+0.01 then return end
    local left=(1-(16/9)/(w/h))*0.5
    fixOverlay()
    fixLoading(w,h,dpi)
    for _,screen in ipairs(safe(function() return FindAllOf("UIFrontScreenWidget") end) or {}) do
        local slot=safe(function() return screen.UMGFrontWindow.Slot end)
        if valid(slot) then
            local anchors=safe(function() return slot:GetAnchors() end)
            local minX=safe(function() return anchors.Minimum.X end)
            local maxX=safe(function() return anchors.Maximum.X end)
            local minY=safe(function() return anchors.Minimum.Y end)
            local maxY=safe(function() return anchors.Maximum.Y end)
            if type(minX)=="number" and type(maxX)=="number" and type(minY)=="number" and type(maxY)=="number"
                and math.abs(minX)<0.001 and math.abs(maxX-1)<0.001 then
                local ok,err=pcall(function() slot:SetAnchors({Minimum={X=left,Y=minY},Maximum={X=1-left,Y=maxY}}) end)
                if ok then log("Centered final front-window layer") else log("Anchor write failed: "..tostring(err)) end
            end
        end
    end
end
local function request()
    if pending then return end
    pending=true
    for _,delay in ipairs({100,500,1500}) do
        -- Keep Lua callbacks on the game thread; async timers share UE4SS's Lua heap with object hooks.
        ExecuteInGameThreadWithDelay(delay,function()
            local ok,err=pcall(apply)
            if not ok then log("Layout setup failed: "..tostring(err)) end
            if delay==1500 then pending=false end
        end)
    end
end
local function initializeCanvas(widget)
    if not isCanvas(widget) then return end
    local w,h,dpi=geometry(widget)
    local ok,err=pcall(function() fixLoading(w,h,dpi,widget) end)
    if not ok then log("Canvas initialization failed: "..tostring(err)) end
    request()
end
for _,classPath in pairs(canvasClasses) do
    local prepared,prepareError=pcall(function() NotifyOnNewObject(classPath,initializeCanvas) end)
    if not prepared then log("Canvas initializer unavailable for "..classPath..": "..tostring(prepareError)) end
end
local observed,observeError=pcall(function() NotifyOnNewObject("/Script/Nimbus.UIFrontScreenWidget",request) end)
if not observed then log("Front-screen observer unavailable: "..tostring(observeError)) end
local hooked,hookError=pcall(function()
    RegisterHook("/Script/Nimbus.UIManagerActor:OnSetCurrentUIManagerActor",function() end,request)
end)
if not hooked then log("UI-manager hook unavailable: "..tostring(hookError)) end
request()
log("Loaded: automatic canvas correction")
