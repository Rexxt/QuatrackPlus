local gc=love.graphics

local min=math.min
local ins=table.insert

local listBox=WIDGET.new{type='listBox',x=60,y=80,w=1160,h=480,lineHeight=40,drawFunc=function(v,_,sel)
    if sel then
        gc.setColor(COLOR.X)
        gc.rectangle('fill',0,0,1160,40)
    end
    gc.setColor(1,1,1)
    gc.draw(v.mapName,10,-1,nil,min(690/v.mapName:getWidth(),1),1)
    gc.setColor(COLOR.Z)
    gc.draw(v.mapAuth,930,-1,nil,min(230/v.mapAuth:getWidth(),1),1,v.mapAuth:getWidth(),0)

    FONT.set(30,'mono')
    gc.setColor(v.difficultyColor)
    gc.draw(v.difficulty,1050-v.difficulty:getWidth(),2)
    gc.setColor(COLOR.lS)
    GC.mStr(v.tracks,1105,0)
end}

local mapLoaded=false
local lastFreshTime=0

local mapList
local function _freshSongList()
    mapLoaded=true
    lastFreshTime=love.timer.getTime()
    mapList={}
    for source,path in next,{game='assets/level',outside='songs'} do
        for _,dirName in next,love.filesystem.getDirectoryItems(path) do
            local dirPath=path..'/'..dirName
            local info=love.filesystem.getInfo(dirPath)
            if info and info.type=='directory' then
                for _,itemName in next,love.filesystem.getDirectoryItems(dirPath) do
                    if itemName:sub(-4)=='.qbp' then
                        local fullPath=dirPath..'/'..itemName
                        local file=love.filesystem.newFile(fullPath)
                        local iterator=file:lines()
                        local metaData=TABLE.copy(mapTemplate)
                        while true do
                            local line=iterator()
                            if not line then break end
                            line=line:trim()
                            if line~='' and line:sub(1,1)~='#' then
                                if line:sub(1,1)~='$' then break end
                                local key,value=line:match('^%$(.-)=(.+)')
                                if key and value and mapMetaKeyMap[key] then
                                    metaData[key]=value
                                end
                            end
                        end
                        file:close()
                        local color=source=='game' and COLOR.Z or source=='outside' and COLOR.lY or COLOR.lD
                        local dText=metaData.mapDifficulty
                        local difficultyNum=(
                            dText:sub(1,4)=='Easy' and '0' or
                            dText:sub(1,4)=='Norm' and '1' or
                            dText:sub(1,4)=='Hard' and '2' or
                            dText:sub(1,4)=='Luna' and '3' or
                            dText:sub(1,4)=='Over' and '4' or
                            '5')..metaData.mapDifficulty:sub(-1)
                        ins(mapList,{
                            path=fullPath,
                            source=source,
                            mapName=gc.newText(FONT.get(30),{color,metaData.mapName,COLOR.dH," - "..metaData.musicAuth}),
                            mapAuth=gc.newText(FONT.get(30),metaData.mapAuth),
                            difficulty=gc.newText(FONT.get(25),dText),
                            difficultyColor=
                                dText:sub(1,4)=='Easy' and COLOR.lG or
                                dText:sub(1,4)=='Norm' and COLOR.lY or
                                dText:sub(1,4)=='Hard' and COLOR.lR or
                                dText:sub(1,4)=='Luna' and COLOR.lM or
                                dText:sub(1,4)=='Over' and COLOR.lH or
                                COLOR.lX,
                            tracks=metaData.realTracks and metaData.realTracks~=metaData.tracks and(('$1($2)'):repD(metaData.realTracks,metaData.tracks)) or metaData.tracks,
                            sortName=(source=='outside' and '0' or '1')..(metaData.realTracks or metaData.tracks)..difficultyNum..metaData.mapName
                        })
                    end
                end
            end
        end
    end
    table.sort(mapList,function(a,b) return a.sortName<b.sortName end)
    listBox:setList(mapList)
end

local scene={}

function scene.enter()
    if not mapLoaded then _freshSongList() end
    BG.set()
    BGM.play()
end

function scene.keyDown(key)
    if key=='return' then
        local map,errmsg=loadBeatmap(listBox:getSel().path)
        if map then
            SFX.play('enter')
            SCN.go('game',nil,map)
        else
            MES.new('error',errmsg)
        end
    elseif key=='up' or key=='down' then
        if key=='up' and listBox.selected==1 then
            listBox:select(listBox:getLen())
        elseif key=='down' and listBox.selected==listBox:getLen() then
            listBox:select(1)
        else
            listBox:arrowKey(key)
        end
    elseif key=='escape' then
        SCN.back()
    end
end

scene.widgetList={
    listBox,
    WIDGET.new{type='button_fill',x=160,y=640,w=200,h=80,  sound='button',text=CHAR.icon.import,color='lV',fontSize=60,
        code=function()
            if SYSTEM=="Windows" or SYSTEM=="Linux" then
                love.system.openURL(love.filesystem.getSaveDirectory()..'/songs')
            else
                MES.new('info',love.filesystem.getSaveDirectory())
            end
        end
    },
    WIDGET.new{type='button_fill',x=320,y=640,w=80,        sound='button',text=CHAR.icon.retry_spin,color='lB',fontSize=50,code=_freshSongList,visibleFunc=function() return love.timer.getTime()-lastFreshTime>2.6 end},
    WIDGET.new{type='button_fill',x=640,y=640,w=140,h=80,  sound='button',text=CHAR.icon.play,color='lG',fontSize=60,code=WIDGET.c_pressKey'return'},
    WIDGET.new{type='button_fill',x=1140,y=640,w=170,h=80, sound='back',fontSize=60,text=CHAR.icon.back,code=WIDGET.c_backScn},
}
return scene