-- Center only the two identified filter resources at their native logical size.
return function(log)
    local function safe(fn) local ok,v=pcall(fn);if ok then return v end end
    local function valid(o) return o~=nil and safe(function() return o:IsValid() end)==true end
    local function name(o) return safe(function() return o:GetFullName() end) or "" end
    local function near(a,b,tolerance) return type(a)=="number" and type(b)=="number" and math.abs(a-b)<(tolerance or 0.001) end
    local function filter(resource)
        for _=1,4 do
            if not valid(resource) then return false end
            local path=name(resource)
            if path:find("/Game/MenuFilterAdd.MenuFilterAdd",1,true)
                or path:find("/Game/UI/Menu/CommonWidget/Assets/Background/MenuFilter.MenuFilter",1,true) then return true end
            resource=safe(function() return resource.Parent end)
        end
        return false
    end
    return function()
        local count=0
        for _,image in ipairs(safe(function() return FindAllOf("Image") end) or {}) do
            if valid(image) and name(image):find(" /Engine/Transient.",1,true) and filter(safe(function() return image.Brush.ResourceObject end)) then
                local slot=safe(function() return image.Slot end)
                if valid(slot) then
                    local a=safe(function() return slot:GetAnchors() end)
                    local o=safe(function() return slot:GetOffsets() end)
                    local minX=safe(function() return a.Minimum.X end)
                    local minY=safe(function() return a.Minimum.Y end)
                    local maxX=safe(function() return a.Maximum.X end)
                    local maxY=safe(function() return a.Maximum.Y end)
                    local left=safe(function() return o.Left end)
                    local top=safe(function() return o.Top end)
                    local width=safe(function() return o.Right end)
                    local height=safe(function() return o.Bottom end)
                    local fixed=near(minX,maxX) and near(minY,maxY) and near(width,1920,3) and near(height,1080,3)
                    local centered=fixed and near(minX,0.5) and near(minY,0.5) and near(left,-960) and near(top,-540)
                    local stretched=near(minX,0) and near(minY,0) and near(maxX,1) and near(maxY,1)
                        and near(left,0) and near(top,0) and near(width,0) and near(height,0)
                    if ((fixed and not centered) or stretched) and type(left)=="number" and type(top)=="number" then
                        local ok,err=pcall(function()
                            slot:SetAnchors({Minimum={X=0.5,Y=0.5},Maximum={X=0.5,Y=0.5}})
                            slot:SetOffsets({Left=-960,Top=-540,Right=1920,Bottom=1080})
                        end)
                        if ok then count=count+1;log("Centered native-size filter: "..name(image))
                        else
                            pcall(function()
                                slot:SetAnchors({Minimum={X=minX,Y=minY},Maximum={X=maxX,Y=maxY}})
                                slot:SetOffsets({Left=left,Top=top,Right=width,Bottom=height})
                            end)
                            log("Filter write failed; restore attempted: "..tostring(err))
                        end
                    end
                end
            end
        end
        return count
    end
end
