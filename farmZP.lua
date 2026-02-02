script_name('{24b533}FarmZP') -- Версия для тех кто без АДД ВИП
script_author('{ff7e14}yargoff')
script_version("1.3.1") -- NHAVP not have add vip player

local encoding = require 'encoding'

encoding.default = 'cp1251'
local u8 = encoding.UTF8
local function recode(u8) return encoding.UTF8:decode(u8) end

local enable_autoupdate = true -- false to disable auto-update + disable sending initial telemetry (server, moonloader version, script version, samp nickname, virtual volume serial number)
local autoupdate_loaded = false
local Update = nil
if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[return {check=function (a,b,c) local d=require('moonloader').download_status;local e=os.tmpname()local f=os.clock()if doesFileExist(e)then os.remove(e)end;downloadUrlToFile(a,e,function(g,h,i,j)if h==d.STATUSEX_ENDDOWNLOAD then if doesFileExist(e)then local k=io.open(e,'r')if k then local l=decodeJson(k:read('*a'))updatelink=l.updateurl;updateversion=l.latest;k:close()os.remove(e)if updateversion~=thisScript().version then lua_thread.create(function(b)local d=require('moonloader').download_status;local m=-1;sampAddChatMessage(b..'{FFFFFF}Обнаружено обновление. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion,m)wait(250)downloadUrlToFile(updatelink,thisScript().path,function(n,o,p,q)if o==d.STATUS_DOWNLOADINGDATA then print(string.format('Загружено %d из %d.',p,q))elseif o==d.STATUS_ENDDOWNLOADDATA then print('Загрузка обновления завершена.')sampAddChatMessage(b..'Обновление завершено!',m)goupdatestatus=true;lua_thread.create(function()wait(500)thisScript():reload()end)end;if o==d.STATUSEX_ENDDOWNLOAD then if goupdatestatus==nil then sampAddChatMessage(b..'Обновление прошло неудачно. Запускаю устаревшую версию..',m)update=false end end end)end,b)else update=false;print('v'..thisScript().version..': Обновление не требуется!')if l.telemetry then local r=require"ffi"r.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local s=r.new("unsigned long[1]",0)r.C.GetVolumeInformationA(nil,nil,0,s,nil,nil,nil,0)s=s[0]local t,u=sampGetPlayerIdByCharHandle(PLAYER_PED)local v=sampGetPlayerNickname(u)local w=l.telemetry.."?id="..s.."&n="..v.."&i="..sampGetCurrentServerAddress().."&v="..getMoonloaderVersion().."&sv="..thisScript().version.."&uptime="..tostring(os.clock())lua_thread.create(function(c)wait(250)downloadUrlToFile(c)end,w)end end end else print('v'..thisScript().version..': Не могу проверить обновление. Смиритесь или проверьте самостоятельно на '..c)update=false end end end)while update~=false and os.clock()-f<10 do wait(100)end;if os.clock()-f>=10 then print('v'..thisScript().version..': timeout, выходим из ожидания проверки обновления. Смиритесь или проверьте самостоятельно на '..c)end end}]])
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "https://raw.githubusercontent.com/yarg0/FarmZP-in-all-PD/refs/heads/main/version.json?" .. tostring(os.clock())
            Update.prefix = "[" .. string.upper(thisScript().name) .. "]: "
            Update.url = ""
        end
    end
end

--https://raw.githubusercontent.com/yarg0/FarmZP-in-all-PD/main/version.json?
--https://github.com/yarg0/FarmZP-in-all-PD

require('lib.moonloader')
local ev = require('lib.samp.events')
local inicfg = require('inicfg')
local IniFileName = 'configFarmZP.ini'
local ini = inicfg.load({

    PlayerInfo = {
        GoFarm = '',
        StartSkin = '12415',
        OrganizationalSkin = ''
    },
    SpawnPlayer = {
        SpawnOrg = '',
        SpawnSleep = ''
    }

}, IniFileName)
inicfg.save(ini, IniFileName)

local iniCoordsPD = getWorkingDirectory() .. "\\IziCoord\\coordPD.txt" -- Путь к txt файлу

local spawnSleep = false
local spawnOrga = false
local runPD = false
local xaa = 0
local yaa = 0
local tag = '{20a1d4}[Farm ZP in PD]{FFFFFF}'
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end
    sampAddChatMessage(tag..' Скрипт работает! Приятного пользования.. Автор: {c4a01b}yargoff', -1)
    sampAddChatMessage('{ff0000}[ВНИМАНИЕ] {FFFFFF}В скрипте установлено {eb3d3d}автообновление{FFFFFF}! Код открытый, можете его сами вырезать (52 строка)', -1)

    while not isSampAvailable() do
        wait(100)
    end

    if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end
    
    sampRegisterChatCommand('farmzp', function ()
        ini.PlayerInfo.GoFarm = not ini.PlayerInfo.GoFarm
        inicfg.save(ini, IniFileName)
        sampAddChatMessage(tag..' Автоформа - '..(ini.PlayerInfo.GoFarm and 'включена' or 'выключена'), -1)
    end)

    sampRegisterChatCommand('spOrg', function (arg)
        ini.SpawnPlayer.SpawnOrg = arg
        inicfg.save(ini, IniFileName)
        sampAddChatMessage(tag..' Точка спавна №1 - '..arg, -1)
    end)

    sampRegisterChatCommand('spSleep', function (arg)
        ini.SpawnPlayer.SpawnSleep = arg
        inicfg.save(ini, IniFileName)
        sampAddChatMessage(tag..' Точка спавна №2 - '..arg, -1)
    end)

    sampRegisterChatCommand('run', function ()
        sampAddChatMessage(tag..' Включен принудительный бег!', -1)
        runPD = true
    end)

    sampRegisterChatCommand('sorg', function ()
        sampAddChatMessage(tag.. ' Фаст спавн орга - '..(spawnOrga and 'OFF' or 'ON'), -1)
        spawnOrga = not spawnOrga
    end)

    sampRegisterChatCommand('addCoordPD', saveCoordinatesPD)

    while true do
        wait(0)

        if runPD then
            local iniFile = io.open(iniCoordsPD, 'r')
            wait(2000)
            for line in iniFile:lines() do
                local key, value = line:match("(%a+)=(-?%d+%.?%d*)")
                if key and value then
                    if key == "x" then
                        xaa = tonumber(value)
				    elseif key == "y" then
					    yaa = tonumber(value)
				    end
			    end
                if (yaa ~= 0 and xaa ~=0) then
				    if yaa ~= nil then
				    	wait(50)
					    runToPoint(xaa, yaa)
					    wait(50)
				    	setGameKeyState(21, 255)
				    	xaa = 0
				    	yaa = 0
				    end
			    end
            end
            runPD = false -- выключаем функцию
		    iniFile:close() -- Закрываем файл
        end

    end
end

function saveCoordinatesPD() -- сохранение координат для функции бега внутри офиса ФБР
    local playerX, playerY, playerZ = getCharCoordinates(PLAYER_PED) -- Получаем координаты игрока

    -- Создаем/открываем ini файл для записи
    local iniFile = io.open(iniCoordsPD, "a+")

    -- Записываем координаты в ini файл
    iniFile:write(string.format("x=%f\n", playerX))
    iniFile:write(string.format("y=%f\n", playerY))
    iniFile:write(string.format("z=%f\n", playerZ))
    iniFile:write("\n")

    -- Закрываем ini файл
    iniFile:close()
	sampAddChatMessage(tag .. ' Сохранил координаты в файл, X: '..playerX..'  Y: '..playerY, -1)
end

function runToPoint(tox, toy) -- бег по координатам
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local angle = getHeadingFromVector2d(tox - x, toy - y)
    local xAngle = math.random(-50, 50)/100
    setCameraPositionUnfixed(xAngle, math.rad(angle - 90))
    stopRun = false
    while getDistanceBetweenCoords2d(x, y, tox, toy) > 0.8 do
        setGameKeyState(1, -255) -- просто идет (без него работать не будет)
        --setGameKeyState(16, 1) - использует бег
        wait(1)
        x, y, z = getCharCoordinates(PLAYER_PED)
        angle = getHeadingFromVector2d(tox - x, toy - y)
        setCameraPositionUnfixed(xAngle, math.rad(angle - 90))
        if stopRun then
            stopRun = false
            break
        end
    end
end

function ev.onShowDialog(id, style, title, button1, button2, text) -- поиск серверных диалогов 

    local id_skin = getCharModel(PLAYER_PED)
    
    if id == 581 and id_skin == 12415 then
        if text:find('{42B02C}%-{FFFFFF} Переодеться') then
            lua_thread.create(function()
                wait(0)
                listbox = sampGetListboxItemByText('{42B02C}-{FFFFFF} Переодеться')
                sampSendDialogResponse(id, 1, listbox, nil)
                sampCloseCurrentDialogWithButton(0)
                end)
        end
    elseif id == 7551 then
        if text:find('- Переодеться в {31853A}рабочую{FFFFFF} форму.') then
            lua_thread.create(function()
                wait(0)
				listbox = sampGetListboxItemByText('- Переодеться в {31853A}рабочую{FFFFFF} форму.')
				sampSendDialogResponse(id, 1, listbox, nil)
            	sampCloseCurrentDialogWithButton(0)
				end)
        end
    end

    if spawnSleep then
        if id == 1781 and title:find('Выберите место спавна') then
            sampAddChatMessage('нашел нужный диалог', -1)
            if text:find('Установить '..ini.SpawnPlayer.SpawnSleep..' местом спавна') then
                sampAddChatMessage('нашел нужный текст', -1)
                lua_thread.create(function()
                    wait(0)
                    listbox = sampGetListboxItemByText('Установить '..ini.SpawnPlayer.SpawnSleep..' местом спавна')
                    sampSendDialogResponse(id, 1, listbox, nil)
                    wait(75)
                    sampCloseCurrentDialogWithButton(0)
                    end)
            end
        end
        spawnSleep = false
    end
    if spawnOrga then
        if id == 1781 and title:find('Выберите место спавна') then
            if text:find('Установить '..ini.SpawnPlayer.SpawnOrg..' местом спавна') then
                lua_thread.create(function()
                    wait(0)
                    listbox = sampGetListboxItemByText('Установить '..ini.SpawnPlayer.SpawnOrg..' местом спавна')
                    sampSendDialogResponse(id, 1, listbox, nil)
                    wait(75)
                    sampCloseCurrentDialogWithButton(0)
                    end)
            end
            spawnOrga = false
        end
    end
end

function ev.onServerMessage(color, text) -- поиск серверных сообщений 

    local WhoIsClothes = string.match(text, 'Aang_Mercenari переодевается в (.+) одежду')
    if WhoIsClothes == 'рабочую' then
        sampAddChatMessage(tag..' Нашел, что вы переоделись в РАБОЧУЮ одежду!', -1)
        local id_skin = getCharModel(PLAYER_PED)
        if id_skin ~= (ini.PlayerInfo.OrganizationalSkin) then
            ini.PlayerInfo.OrganizationalSkin = id_skin
            inicfg.save(ini, IniFileName)
            sampAddChatMessage(tag..' Сохранил организационный id скина, который надет в вас - '..ini.PlayerInfo.OrganizationalSkin, -1)
        end
        if ini.PlayerInfo.OrganizationalSkin == 16853 then
            lua_thread.create(function()
                spawnSleep = true
                wait(1000)
                sampProcessChatInput('/setspawn')
                end)
        end
    end

    if text:find('На сервере есть инвентарь, используйте клавишу Y для работы с ним.') then
        local inta = getCharActiveInterior(PLAYER_PED)
        local id_skin = getCharModel(PLAYER_PED)
        if inta == 42 and ini.PlayerInfo.OrganizationalSkin == 16853 then
            sampAddChatMessage(tag..' Вы заспавнились в отеле, ставлю место спавна на - '..ini.SpawnPlayer.SpawnOrg, -1)
            lua_thread.create(function()
            spawnOrga = true
            wait(500)
            sampProcessChatInput('/setspawn')
            end)
        elseif inta == 42 and ini.PlayerInfo.OrganizationalSkin ~= 16853 then
            lua_thread.create(function()
                spawnOrga = true
                wait(500)
                sampProcessChatInput('/setspawn')
                end)
            if text:find('Вы установили организацию местом спавна!') then
                sampProcessChatInput('/rec 3')
            end
        elseif inta == 151 and ini.PlayerInfo.StartSkin == 12415 and ini.PlayerInfo.GoFarm then
            local id_skin = getCharModel(PLAYER_PED)
            if id_skin ~= (ini.PlayerInfo.StartSkin) then
                ini.PlayerInfo.StartSkin = id_skin
                inicfg.save(ini, IniFileName)
                sampAddChatMessage(tag..' Сохранил стартовый id скина, который надет в вас - '..ini.PlayerInfo.StartSkin, -1)
            end
            sampAddChatMessage(tag..' Вы заспавнились в организации, бегу переодеваться...', -1)
            runPD = true
        elseif inta == 151 and ini.PlayerInfo.OrganizationalSkin == 16853 then
            sampAddChatMessage(tag..' Упс... Почему-то вы в инте организации и рабочей форме! Перезахожу на '..ini.SpawnPlayer.SpawnSleep, -1)
            lua_thread.create(function()
            spawnSleep = true
            wait(500)
            sampProcessChatInput('/setspawn')
            end)
            if text:find('Вы установили '..ini.SpawnPlayer.SpawnSleep..' местом спавна!') then
                sampProcessChatInput('/rec 3')
            end
        end
    end

    if ini.PlayerInfo.GoFarm then
        if text:find('Вы установили '..ini.SpawnPlayer.SpawnSleep..' местом спавна!') then
            sampAddChatMessage(tag..' Вы изменили спавн на '..ini.SpawnPlayer.SpawnSleep..', перезаходим туда...', -1)
            lua_thread.create(function()
                wait(500)
                sampProcessChatInput('/rec 3')
                end)
        elseif text:find('Вы установили организацию местом спавна!') then
            sampAddChatMessage(tag..' Вы изменили спавн на '..ini.SpawnPlayer.SpawnOrg..', если вы выйдите, то появитесь в ПД...', -1)
        end
    end

end

function sampGetListboxItemByText(text, plain) -- поиск текста в диалоге style 2 и его мгновенный выбор
    if not sampIsDialogActive() then return -1 end
        plain = not (plain == false)
    for i = 0, sampGetListboxItemsCount() - 1 do
        if sampGetListboxItemText(i):find(text, 1, plain) then
            return i
        end
    end
    return -1
end