-- Initialize only verified top-level canvases; leave source text and embedded widgets alone.
return function(log)
    local function safe(fn) local ok,v=pcall(fn);if ok then return v end end
    local classes={
        CampaignMissionLoad_C="/Game/UI/Menu/Campaign/CampaignMissionLoad.CampaignMissionLoad_C",
        GenericLoad_C="/Game/UI/Menu/Boot/GenericLoad.GenericLoad_C",
        SubtitleWidgetBP_C="/Script/Nimbus.SubtitleWidget"
    }
    local configured={}
    local function canvasName(widget)
        if not widget or safe(function() return widget:IsValid() end)~=true then return end
        local name=safe(function() return widget:GetFullName() end) or ""
        if name:find(" /Engine/Transient.",1,true) and classes[name:match("^(%S+) ")] then return name end
    end
    local function center(widget,width,height,dpi,preparing)
        local name=canvasName(widget)
        if not name or (not preparing and safe(function() return widget:IsInViewport() end)~=true) then return end
        local signature=(preparing and "prepared:" or "viewport:")..width..":"..height..":"..dpi
        if configured[name]==signature then return end
        local vh=height/dpi
        local ok,err=pcall(function()
            widget:SetDesiredSizeInViewport({X=vh*16/9,Y=vh})
            widget:SetAlignmentInViewport({X=0.5,Y=0})
            widget:SetPositionInViewport({X=width*0.5,Y=0},true)
        end)
        if ok then
            configured[name]=signature
            log("Centered 2D viewport canvas"..(preparing and " before attachment: " or ": ")..name)
        else log("Viewport correction failed: "..tostring(err)) end
    end
    local function apply(width,height,dpi,target)
        if type(dpi)~="number" or dpi<=0 or type(width)~="number" or type(height)~="number" or height<=0 or width/height<=16/9+0.01 then return end
        if target then center(target,width,height,dpi,true);return end
        for class in pairs(classes) do
            for _,widget in ipairs(safe(function() return FindAllOf(class) end) or {}) do center(widget,width,height,dpi,false) end
        end
    end
    return apply,canvasName,classes
end
