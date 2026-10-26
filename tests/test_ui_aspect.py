"""Verify first-paint initialization and the remaining UI lifecycle events."""
from pathlib import Path
from lupa import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
logs={};queue={};writes=0;hooks={};observers={};pages={}
print=function(s) logs[#logs+1]=s end
local function valid() return true end
local pc={IsValid=valid}
package.preload.UEHelpers=function() return {GetPlayerController=function() return pc end} end
width=5120;height=1440;layoutAvailable=true
StaticFindObject=function()
 if layoutAvailable then return {IsValid=valid,GetViewportSize=function() return {X=width,Y=height} end,GetViewportScale=function() return 4/3 end} end
end
anchors={Minimum={X=0,Y=0.1},Maximum={X=1,Y=0.9}}
slot={IsValid=valid,GetAnchors=function() return anchors end,SetAnchors=function(_,v) writes=writes+1;anchors=v end}
screens={}
FindAllOf=function(c) if c=='UIFrontScreenWidget' then return screens end return pages[c] or {} end
NotifyOnNewObject=function(path,fn) observers[path]=fn end
RegisterHook=function(path,pre,post) hooks[path]={pre=pre,post=post} end
RegisterKeyBind=function() error('Automatic UI correction must not register hotkeys') end
ExecuteWithDelay=function() error('Async timers must not enter the Lua heap alongside object hooks') end
ExecuteInGameThread=function() error('Use the native delayed game-thread scheduler') end
ExecuteInGameThreadWithDelay=function(ms,fn) queue[#queue+1]={ms=ms,fn=fn} end
function drain() local tasks=queue;queue={};for _,t in ipairs(tasks) do t.fn() end end
function reapply() hooks['/Script/Nimbus.UIManagerActor:OnSetCurrentUIManagerActor'].post();drain() end
''')
lua.execute('assert(loadfile(...))()',str(root/'mod/AC7UIAspect/Scripts/main.lua'))
lua.execute(r'''
assert(#queue==3 and writes==0)
assert(observers['/Script/UMG.UserWidget']==nil,'Never construct Lua wrappers for unrelated/off-thread UserWidgets')
assert(observers['/Script/Nimbus.SubtitleWidget']~=nil)
assert(observers['/Game/UI/Menu/Boot/GenericLoad.GenericLoad_C']~=nil)
drain();assert(writes==0)
screens={{UMGFrontWindow={Slot=slot}}}
observers['/Script/Nimbus.UIFrontScreenWidget']()
hooks['/Script/Nimbus.UIManagerActor:OnSetCurrentUIManagerActor'].post()
assert(#queue==3,'Creation bursts must be coalesced')
drain()
assert(writes==1 and anchors.Minimum.X==0.25 and anchors.Maximum.X==0.75)
assert(anchors.Minimum.Y==0.1 and anchors.Maximum.Y==0.9,'Vertical anchors preserved')
reapply();assert(writes==1,'Already centered layouts stay unchanged')
anchors={Minimum={X=0.1,Y=0},Maximum={X=0.9,Y=1}}
reapply();assert(writes==1,'Custom layout preserved')
width=2560;reapply();assert(writes==1,'16:9 passthrough')
width=3440;anchors={Minimum={X=0,Y=0},Maximum={X=1,Y=1}}
reapply();assert(writes==2 and math.abs(anchors.Minimum.X-440/3440)<0.000001,'Not tied to 5120px')
assert(hooks['/Script/UMG.UserWidget:AddToViewport']==nil and hooks['/Script/UMG.UserWidget:Construct']==nil)
width=5120;screens={};earlyWrites=0;earlyAttached=false
local page={IsValid=function() return true end,
 GetFullName=function() return 'CampaignMissionLoad_C /Engine/Transient.EarlyPage' end,
 IsInViewport=function() return earlyAttached end,
 SetDesiredSizeInViewport=function(_,v) earlyWrites=earlyWrites+1;earlySize=v end,
 SetAlignmentInViewport=function() earlyWrites=earlyWrites+1 end,
 SetPositionInViewport=function(_,v,dpi) earlyWrites=earlyWrites+1;earlyPosition=v;assert(dpi) end}
local created=observers['/Game/UI/Menu/Campaign/CampaignMissionLoad.CampaignMissionLoad_C']
created(page)
assert(earlyWrites==3 and earlySize.X==1920 and earlyPosition.X==2560,'Prepared before native C++ viewport attachment')
created(page);assert(earlyWrites==3,'Duplicate creation is idempotent')
earlyAttached=true;earlyPosition={X=0,Y=0};pages.CampaignMissionLoad_C={page}
drain();assert(earlyWrites==6 and earlyPosition.X==2560,'Bounded post-attachment retry preserves the correction')
pages={};earlyAttached=false
created=observers['/Game/UI/Menu/Boot/GenericLoad.GenericLoad_C']
page.GetFullName=function() return 'GenericLoad_C /Engine/Transient.ExitLoadingPage' end
created(page);assert(earlyWrites==9,'Exit loading page prepared before attachment')
layoutAvailable=false
page.GetFullName=function() return 'GenericLoad_C /Engine/Transient.ExitLoadingPage2' end
created(page);assert(earlyWrites==12 and earlyPosition.X==2560,'Cached viewport survives map transitions')
page.GetFullName=function() return 'CampaignRetry_C /Engine/Transient.Retry' end
created(page);assert(earlyWrites==12,'Retry keeps its original lower-left placement')
''')
print('PASS: game-thread-only delayed callbacks, narrow creation hooks, first-paint initialization, bounded retries, DPI/cache, custom/16:9/21:9 layouts and untouched retry UI.')
