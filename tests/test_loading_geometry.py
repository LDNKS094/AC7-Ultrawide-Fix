from pathlib import Path
from lupa import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
writes=0;inViewport=true;class='CampaignMissionLoad_C';suffix='LoadPage'
widget={IsValid=function() return true end,
 GetFullName=function() return class..' /Engine/Transient.'..suffix end,
 IsInViewport=function() return inViewport end,
 SetDesiredSizeInViewport=function(_,v) writes=writes+1;desired=v end,
 SetAlignmentInViewport=function(_,v) writes=writes+1;alignment=v end,
 SetPositionInViewport=function(_,v,removeDpi) writes=writes+1;position=v;dpiFlag=removeDpi end}
FindAllOf=function(c) if c==class then return {widget} end return {} end
''')
factory=lua.execute('return assert(loadfile(...))()',str(root/'mod/AC7UIAspect/Scripts/loading_geometry.lua'))
fix,is_canvas,_=factory(lua.eval('function() end'))
lua.globals().fix=fix
lua.globals().isCanvas=is_canvas
lua.execute(r'''
fix(5120,1440,4/3)
assert(writes==3 and math.abs(desired.X-1920)<0.0001 and desired.Y==1080)
assert(position.X==2560 and position.Y==0 and dpiFlag and alignment.X==0.5 and alignment.Y==0)
assert(math.abs(position.X-desired.X*(4/3)*alignment.X-1280)<0.0001)
fix(5120,1440,4/3);assert(writes==3,'Repeated events must not compound')
inViewport=false;fix(5120,1440,4/3);assert(writes==3,'Embedded/offscreen widgets unchanged')
fix(5120,1440,0);assert(writes==3,'Invalid DPI rejected')
inViewport=true;fix(3440,1440,4/3);assert(writes==6 and position.X==1720 and desired.Y==1080)
fix(2560,1440,4/3);assert(writes==6,'16:9 passthrough')
class='GenericLoad_C';suffix='ExitPage';inViewport=false
fix(5120,1440,4/3,widget);assert(writes==9,'Exit canvas prepared before attachment')
class='SubtitleWidgetBP_C';suffix='Subtitle'
fix(5120,1440,4/3,widget);assert(writes==12,'Subtitle prepared at creation')
class='CampaignRetry_C';suffix='Retry'
assert(isCanvas(widget)==nil);fix(5120,1440,4/3,widget);assert(writes==12,'Retry is not a centered canvas')
widget.GetFullName=function() return 'GenericLoad_C /Game/UI/Template' end
assert(isCanvas(widget)==nil);fix(5120,1440,4/3,widget);assert(writes==12,'Cooked template untouched')
widget.GetFullName=function() return 'GenericLoad_C /Engine/Transient.FailedWrite' end
widget.SetPositionInViewport=function() error('write failure') end
fix(5120,1440,4/3,widget);local failed=writes
fix(5120,1440,4/3,widget);assert(writes>failed,'Failed writes are retried, never cached as successful')
''')
print('PASS: shared target whitelist, native-aspect DPI placement, creation/viewport phases, idempotence, template/retry protection and failed-write retry.')
