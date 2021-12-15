local langList={
    zh="中文",
    zh2="全中文",
    en="English",
    fr="Français",
    es="Español",
    pt="Português",

    grass="机翻",
    yygq="就这?",
    symbol="?????",
}

local scene={}

function scene.sceneBack()
    saveSettings()
end

local function _setLang(lid)
    SETTING.locale=lid
    applyLanguage()
    TEXT.clear()
    TEXT.show(langList[lid],640,360,100,'appear',.626)
    collectgarbage()
end
scene.widgetList={
    WIDGET.newButton{x=200,y=100,w=200,h=120,fText=langList.zh,    color='R', font=35,code=function()_setLang('zh')end},
    WIDGET.newButton{x=640,y=100,w=200,h=120,fText=langList.en,    color='N', font=35,code=function()_setLang('en')end},
    WIDGET.newButton{name="back",x=1140,y=640,w=170,h=80,font=60,fText=CHAR.icon.back,code=backScene},
}

return scene