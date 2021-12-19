local gc=love.graphics
local gc_setColor=gc.setColor
local gc_rectangle=gc.rectangle
local gc_printf=gc.printf
local gc_replaceTransform=gc.replaceTransform

local kbIsDown=love.keyboard.isDown

local setFont=setFont
local mStr=mStr

local unpack=unpack
local max,min=math.max,math.min
local int,abs=math.floor,math.abs
local ins=table.insert

local hitColors={
    [-1]=COLOR.dRed,
    [0]=COLOR.dRed,
    COLOR.lWine,
    COLOR.lBlue,
    COLOR.lGreen,
    COLOR.lOrange,
    COLOR.lH,
}
local hitTexts={
    [-1]="MISS",
    [0]="BAD",
    'OK',
    'GOOD',
    'GREAT',
    'PERF',
    'MARV'
}
local hitAccList={
    -5, --OK
    2,  --GOOD
    6,  --GREAT
    10, --PERF
    10, --MARV
}
local hitLVOffsets={--Only for deviation drawing
    [0]={0,.02},
    {.02,.04},
    {.04,.07},
    {.07,.10},
    {.10,.14},
    {.14,.20},
}
local function _getHitLV(div)
    div=abs(div)
    return
    div<=.02 and 5 or
    div<=.04 and 4 or
    div<=.07 and 3 or
    div<=.10 and 2 or
    div<=.14 and 1 or
    0
end

local playSongTime

local map,tracks
local hitLV--Hit level (-1~5)
local hitTextTime--Time stamp, for hitText fading-out animation

local isSongPlaying
local time,songLength
local hitOffests
local curAcc,fullAcc,accText
local combo,maxCombo,score,score0
local hits={}

local function _updateAcc()
    accText=("%.2f%%"):format(100*max(curAcc,0)/max(fullAcc,1))
end

local function _tryGoResult()
    for i=1,#tracks do
        if tracks[i].notes[1]then return end
    end
    SCN.swapTo('result',nil,{
        map=map,
        score=score0,
        maxCombo=maxCombo,
        accText=accText,
        hits={
            [-1]=hits[-1],
            [0]=hits[0],
            [1]=hits[1],
            [2]=hits[2],
            [3]=hits[3],
            [4]=hits[4],
            [5]=hits[5],
        }
    })
end

local scene={}

function scene.sceneInit()
    map=SCN.args[1]

    playSongTime=map.songOffset+(SETTING.musicDelay-260)/1000
    songLength=map.songLength

    BGM.stop()
    BG.set('none')

    isSongPlaying=false
    time=-3.6
    hitOffests={}
    curAcc,fullAcc=0,0
    _updateAcc()
    combo,maxCombo,score,score0=0,0,0,0
    for i=-1,5 do hits[i]=0 end

    hitLV,hitTextTime=false,1e-99

    tracks={}
    for id=1,map.tracks do
        tracks[id]=require'parts.track'.new(id)
        tracks[id]:setDefaultPosition(580-60*map.tracks+120*id,680)
        tracks[id]:setPosition(nil,nil,true)
    end
end

function scene.sceneBack()
    BGM.stop()
end

local function _trigNote(deviateTime,noTailHold)
    hitTextTime=TIME()
    fullAcc=fullAcc+10
    hitLV=_getHitLV(deviateTime)
    if hitLV>0 and noTailHold then hitLV=5 end
    hits[hitLV]=hits[hitLV]+1
    if hitLV>0 then
        curAcc=curAcc+hitAccList[hitLV]
        score0=score0+int(hitLV*(10000+combo)^.5)
        combo=combo+1
        if combo>maxCombo then
            maxCombo=combo
        end
        if not noTailHold then
            SFX.play('hit')
        end
    else
        if combo>=10 then SFX.play('combobreak')end
        combo=0
    end
    _updateAcc()
    if not noTailHold then
        if abs(deviateTime)>.2 then deviateTime=deviateTime>0 and .2 or -.2 end
        ins(hitOffests,1,deviateTime)
        hitOffests[27]=nil
    end
end
function scene.keyDown(key,isRep)
    if isRep then return end
    local k=KEY_MAP[map.tracks][key]
    if k then
        if type(k)=='number'then
            local deviateTime=tracks[k]:press()
            if deviateTime then _trigNote(deviateTime)end
        elseif k=='skip'then
            if map.finished then
                _tryGoResult()
            end
        elseif k=='restart'then
            local m,errmsg=loadBeatmap(map.qbpFilePath)
            if m then
                SCN.args[1]=m
                BGM.stop('-s')
                scene.sceneInit()
            else
                MES.new('error',errmsg)
            end
        end
    elseif key=='escape'then
        SCN.back()
    end
end
function scene.keyUp(key)
    local k=KEY_MAP[map.tracks][key]
    if k then
        if type(k)=='number'then
            local deviateTime,noTailHold=tracks[k]:release()
            if deviateTime then _trigNote(deviateTime,noTailHold)end
        end
    end
end

-- function scene.touchDown(x,y,id)
--     --?
-- end

function scene.update(dt)
    if kbIsDown'lctrl'and kbIsDown('9','0','-','=')then
        dt=dt*(kbIsDown'9'and .4 or kbIsDown'0'and .75 or kbIsDown'-'and 6 or 32)
        if time-dt-playSongTime>0 then
            BGM.seek(time-dt-playSongTime)
        end
    end
    --Try play bgm
    if not isSongPlaying then
        if time<=playSongTime and time+dt>playSongTime then
            if love.filesystem.getInfo('parts/levels/'..map.songFile..'.ogg')then
                BGM.load(map.songFile,'parts/levels/'..map.songFile..'.ogg')
            elseif love.filesystem.getInfo('songs/'..map.songFile..'.ogg')then
                BGM.load(map.songFile,'songs/'..map.songFile..'.ogg')
            end
            BGM.play(map.songFile,'-sdin -noloop')
            BGM.seek(time+dt-playSongTime)
            isSongPlaying=true
        end
    else
        if not BGM.isPlaying()and map.finished then
            _tryGoResult()
        end
    end

    --Update notes
    time=time+dt
    map:updateTime(time)
    while true do
        local n=map:poll('note')
        if not n then break end
        tracks[n.track]:addNote(n)
    end
    while true do
        local n=map:poll('event')
        if not n then break end
        if n.type=='setTrack'then
            local t=tracks[n.track]
            t[n.operation](t,unpack(n.args))
        end
    end

    --Update tracks (check too-late miss)
    for i=1,map.tracks do
        tracks[i]:update(dt)
        local missCount,marvCount=tracks[i]:updateLogic(time)
        if marvCount>0 then
            for _=1,marvCount do
                _trigNote(0,true)
            end
        end
        if missCount>0 then
            hitTextTime=TIME()
            hitLV=-1
            fullAcc=fullAcc+10*missCount
            _updateAcc()
            if combo>=10 then SFX.play('combobreak')end
            combo=0
            hits[-1]=hits[-1]+missCount
        end
    end

    --Update score animation
    if score<score0 then
        score=int(score*.7+score0*.3)
        if score<score0 then score=score+1 end
    end
end

local comboTextColor1={.1,.05,0,.8}
local comboTextColor2={.86,.92,1,.8}
function scene.draw()
    --Draw tracks
    for i=1,map.tracks do
        tracks[i]:draw()
    end

    --Draw hit text
    if TIME()-hitTextTime<.26 then
        local c=hitColors[hitLV]
        setFont(80,'mono')
        gc_setColor(c[1],c[2],c[3],2.6-(TIME()-hitTextTime)*10)
        mStr(hitTexts[hitLV],640,245)
    end

    --Draw combo
    if combo>1 then
        setFont(50,'mono')
        gc_setColor(hitColors[hitLV])
        mStr(combo,640,356)
        GC.shadedPrint(combo,640,360,'center',2,comboTextColor1,comboTextColor2)
    end

    --Draw deviate indicator
    gc_setColor(1,1,1)gc_rectangle('fill',640-1,350-15,2,34)
    for i=0,5 do
        local c=hitColors[i]
        local d=hitLVOffsets[5-i]
        gc_setColor(c[1]*.8+.3,c[2]*.8+.3,c[3]*.8+.3,.626)
        gc_rectangle('fill',640-d[1]*626,350,(d[1]-d[2])*626,4)
        gc_rectangle('fill',640+d[1]*626,350,(d[2]-d[1])*626,4)
    end

    --Draw deviate times
    for i=1,#hitOffests do
        local c=hitColors[_getHitLV(hitOffests[i])]
        gc_setColor(c[1],c[2],c[3],.4)
        gc_rectangle('fill',640-hitOffests[i]*626-1,350-8,3,20)
    end

    --Draw map info at start
    if time<0 then
        local a=3.6-2*abs(time+1.8)
        setFont(80)
        gc_setColor(1,1,1,a)
        mStr(map.mapName,640,100)
        gc_setColor(.7,.7,.7,a)
        setFont(40)
        mStr(map.musicAuth,640,200)
        mStr(map.mapAuth,640,240)
    end

    gc_replaceTransform(SCR.xOy_ur)
        --Draw score & accuracy
        gc_setColor(1,1,1)
        setFont(40)
        gc_printf(score,-1010,5,1000,'right')
        setFont(30)
        gc_printf(accText,-1010,50,1000,'right')
    gc_replaceTransform(SCR.xOy_dr)
        --Draw map info
        gc_printf(map.mapName,-1010,-55,1000,'right')
        gc_printf(map.mapDifficulty,-1010,-90,1000,'right')
    gc_replaceTransform(SCR.xOy_dl)
        --Draw progress bar
        if time>0 then
            gc_setColor(COLOR.rainbow_light(TIME()*12.6,.8))
            gc_rectangle('fill',0,-10,SCR.w*time/songLength,6)
            local d=time-songLength
            if d>0 then
                gc_setColor(.92,.86,0,min(d,1))
                gc_rectangle('fill',0,-10,SCR.w,6)
            end
        end
    gc_replaceTransform(SCR.xOy)
end

scene.widgetList={
    WIDGET.newKey{name="pause", x=40,y=60,w=50,fText="| |",code=backScene},
}
return scene
