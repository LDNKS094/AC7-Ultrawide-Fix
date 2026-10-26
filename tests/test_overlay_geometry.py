"""Narrow resource-qualified effect-image correction; source UI/templates stay untouched."""
from pathlib import Path
from lupa import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
function object(n,fields)
 fields=fields or {};fields.IsValid=function() return true end;fields.GetFullName=function() return n end;return fields
end
function image(n,resource,anchor)
 local offsets={Left=anchor==0.5 and -960 or 0,Top=anchor==0.5 and -540 or 0,Right=1920,Bottom=1080}
 local anchors={Minimum={X=anchor,Y=anchor},Maximum={X=anchor,Y=anchor}}
 local writes=0
 local slot=object('slot',{
 GetAnchors=function() return anchors end,GetOffsets=function() return offsets end,
 SetAnchors=function(_,a) writes=writes+1;anchors=a end,
 SetOffsets=function(_,o) if failOffsets then error('simulated write failure') end writes=writes+1;offsets=o end})
 return object(n,{Brush={ResourceObject=resource},Slot=slot}),function() return anchors,offsets,writes end
end
local material=object('Material /Game/MenuFilterAdd.MenuFilterAdd')
local texture=object('Texture2D /Game/UI/Menu/CommonWidget/Assets/Background/MenuFilter.MenuFilter')
local unrelated=object('Material /Game/UI/Other.Other')
menu,menuState=image('Image /Engine/Transient.Menu.WidgetTree.ScreemFilter',material,0)
loading,loadingState=image('Image /Engine/Transient.Load.WidgetTree.Filter',texture,0.5)
template,templateState=image('Image /Game/UI/Menu.Template:WidgetTree.Filter',texture,0)
other,otherState=image('Image /Engine/Transient.Menu.WidgetTree.TextBackground',unrelated,0)
FindAllOf=function(c) assert(c=='Image');return {menu,loading,template,other} end
''')
factory=lua.execute('return assert(loadfile(...))()',str(root/'mod/AC7UIAspect/Scripts/overlay_geometry.lua'))
lua.globals().fix=factory(lua.eval('function() end'))
lua.execute(r'''
assert(fix()==1)
for _,state in ipairs({menuState,loadingState}) do
 local a,o=state();assert(a.Minimum.X==0.5 and a.Maximum.X==0.5 and a.Minimum.Y==0.5 and a.Maximum.Y==0.5)
 assert(o.Left==-960 and o.Top==-540 and o.Right==1920 and o.Bottom==1080)
end
local _,_,loadingWrites=loadingState();assert(loadingWrites==0,'Already-centered loading filter stays unchanged')
menu.Slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
menu.Slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
assert(fix()==1,'Previous fullscreen-fill geometry migrates back to centered native size')
assert(fix()==0,'Correction must be idempotent')
local _,_,writes=templateState();assert(writes==0,'Cooked templates must not be modified')
local _,_,writes=otherState();assert(writes==0,'Other brushes must not be modified')
failOffsets=true
local resource=object('Material /Game/MenuFilterAdd.MenuFilterAdd')
local damaged,state=image('Image /Engine/Transient.Damaged.WidgetTree.Filter',resource,0)
FindAllOf=function() return {damaged} end
assert(fix()==0)
local a=state();assert(a.Minimum.X==a.Maximum.X,'Anchor restoration attempted after failure')
''')
print('PASS: filters centered at native 1920x1080, loading canvas not shrunk twice, fullscreen-fill migration, template/other-UI protection, idempotence and failed-write rollback.')
