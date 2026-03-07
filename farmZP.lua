script_name('{20a1d4}FarmZP by {e38329}yargoff')
script_author('{ff7e14}yargoff')
script_version("1.5.0") 

local log = {

'{c4a549}[18.01.26] {FFFFFF}1.0 - Простой скриптик для бега по кордам',
'{FFFFFF}ver. 1.1 - Переделан скрипт под автопереодевание формы и перезахода на другое место спавна для АФК фарма ЗП',
'{FFFFFF}ver. 1.2 - Добавлен inicfg для более удобного взаимодействия',
'{FFFFFF}ver. 1.3 - Доработан скрипт до нужного результата, чуть исправлен код',
'{c4a549}[01.02.26] {FFFFFF}ver. 1.3.1 - Добавлено автообновление, но работает коряво, выдает timeout по кд',
'{FFFFFF}ver. 1.3.1.1 - Вырезано автообновление ( возможно когда-то верну, когда освою по нормальному его )',
'{FFFFFF}ver. 1.3.2 - Исправление кода, его адаптация',
'{FFFFFF}ver. 1.3.3 - Добавлена проверка статистики игрока на наличие организации, а так же команда для указания наличия/отсутствия add vip (по умолчанию: отсутствует)',
'{FFFFFF}ver. 1.3.3.1 - Исправлен баг с выбором спавна после переодевания в форму ПДшника',
'{c4a549}[03.02.26] {FFFFFF}ver. 1.4 - Добавлено mimgui', 
'{c4a549}[04.02.26] {FFFFFF}ver. 1.4.0.1 - Отредактированы некоторые задержки, добавил открытие/закрытие меню :)', 
'{c4a549}[05.02.26] {FFFFFF}ver. 1.4.0.2 - Незначительные изменения кода // Добавление картинок из fAwesome6 // Задел под взаимодействие с Телеграммом',
'{c4a549}[06.02.26] {FFFFFF}ver. 1.4.5 - Отказался от inicfg в пользу JSON таблиц с использованием IO. Переделал немного меню под работу с JSON.',
'Переработал схему спавна как для тех кто имеет AddVip, так и не имеющих это дополнение.',
'[Работу с AddVip не проверял, потому что не имею её на том аккаунте на котором нахожусь в этот момент]',
'{c4a549}[08.02.26] {FFFFFF}ver. 1.4.6 - Добавил пункт с льготой',
'{c4a549}[15.02.26 - 16.02.26] {FFFFFF}ver. 1.5.0 - Добавил запись ника. Доделал работу скрипта, если у пользователя имеется AddVip [Все работает ;)] '

}

--https://raw.githubusercontent.com/yarg0/FarmZP-in-all-PD/main/version.json?
--https://github.com/yarg0/FarmZP-in-all-PD

require('lib.moonloader')
local ev = require('samp.events')
local imgui = require('mimgui')
local ffi = require('ffi')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local faicons = require('fAwesome6')

local tag = '{20a1d4}[ФАРМ ЗП]{FFFFFF}'

local function generate_path(p)
    return getWorkingDirectory() .. '/' .. p
end

do
    local function jsoncfg_save(data, path)
        if doesFileExist(path) then os.remove(path) end
        if type(data) ~= 'table' then return end
        local f = io.open(path, 'a+')
        f:write(encodeJson(data))
        f:close()
    end
    local function jsoncfg_load(data, path)
        if doesFileExist(path) then
            local f = io.open(path, 'r')
            local d = decodeJson(f:read('*a'))
            f:close()
            return d
        else
            jsoncfg_save(data, path)
            return data
        end
    end
    jsoncfg = {
        save = jsoncfg_save,
        load = jsoncfg_load
    }
end


local yargoffConfig = jsoncfg.load({
    status = false,
    addvip = false,
    OrganizationalSkin = 0,          -- ID скина (число)
    Organization = "",               -- имя организации
    nickname = "",                   -- Ник пользователя скрипта
    prioritySetSpawn = {},           -- приоритет спавна через /setspawn [кто не имеет AddVip] (массив)
    priorityAddVip = {},             -- приоритет спавна для тех у кого есть AddVip (массив)
    SpawnOrg = {},                   -- Cпавн орагнизационный (массив)
    dialog_setspawn = {},            -- пункты диалога (массив строк)
    dialog_setspawnAddVip = {},      -- пункты диалога add vip (массив строк)
    interior_org = 0,                -- id интерьера фракции
    interior_afk = 0,                -- id интерьера места для АФК
    TG_iduser = "",
    TG_keyBot = ""
}, generate_path('config/yargoffConfig.json'))

local function save_settings()
    jsoncfg.save(yargoffConfig, generate_path('config/yargoffConfig.json'))
end

-- Гарантируем, что нужные поля существуют
yargoffConfig.prioritySetSpawn = yargoffConfig.prioritySetSpawn or {}
yargoffConfig.priorityAddVip = yargoffConfig.priorityAddVip or {}
yargoffConfig.SpawnOrg = yargoffConfig.SpawnOrg or {}
yargoffConfig.dialog_setspawn = yargoffConfig.dialog_setspawn or {}
yargoffConfig.dialog_setspawnAddVip = yargoffConfig.dialog_setspawnAddVip or {}

local iniCoordsPD = getWorkingDirectory() .. "\\IziCoord\\coordPD.txt" -- Путь к txt файлу

local statsRetryCount = 0 -- Повторение попыток узнать в какой организации игрок
local maxRetries = 3 -- Кол-во попыток

local maxAttempts = 10
local attempts = 0
local fastObject = false

local spawnOrgAddVip = true
local checkOrganization = false
local spawnSleep = false
local spawnOrga = false
local runPD = false
local xaa = 0
local yaa = 0

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14, config, iconRanges) -- solid - тип иконок, так же есть thin, regular, light и duotone
    theme()
end)

local inputField_idOrganizationalSkin = imgui.new.char[256]() -- Вписывание чего-либо в строчку

local clickbutton = imgui.new.bool(yargoffConfig.status)
local have_addvip = imgui.new.bool(yargoffConfig.addvip)

local color = imgui.new.float[4](1, 1, 1, 1) -- Настройка цвета

local tab = 0 -- выбирать между логом и командами скрипта в mimgui

local WinState = imgui.new.bool(false) -- Открытие/Закрытие основного окна

-- Синхронизация с сохранённым приоритетом спавна в Организации
if #yargoffConfig.SpawnOrg > 0 then
    selected_name_SpawnOrg = yargoffConfig.SpawnOrg[1]
    -- Найдём индекс в списке
    for i, name in ipairs(yargoffConfig.dialog_setspawn) do
        if name == selected_name_SpawnOrg then
            selected_idx_SpawnOrg = i
            break
        end
    end
else
    selected_name_SpawnOrg = "Выберите место организационного спавна"
    selected_idx_SpawnOrg = 1  -- по умолчанию
end

-- Синхронизация с сохранённым приоритетом АФК спавна [кто имеет add vip]
if #yargoffConfig.prioritySetSpawn > 0 then
    selected_name_HaveAddVip = yargoffConfig.prioritySetSpawn[1]
    -- Найдём индекс в списке
    for i, name in ipairs(yargoffConfig.dialog_setspawn) do
        if name == selected_name_HaveAddVip then
            selected_idx_HaveAddVip = i
            break
        end
    end
else
    selected_name_HaveAddVip = "Выберите место спавна"
    selected_idx_HaveAddVip = 1  -- по умолчанию
end

-- Синхронизация с сохранённым приоритетом АФК спавна [кто не имеет add vip]
if #yargoffConfig.prioritySetSpawn > 0 then
    selected_name_notAddVip = yargoffConfig.prioritySetSpawn[1]
    -- Найдём индекс в списке
    for i, name in ipairs(yargoffConfig.dialog_setspawn) do
        if name == selected_name_notAddVip then
            selected_idx_notAddVip = i
            break
        end
    end
else
    selected_name_notAddVip = "Выберите место спавна"
    selected_idx_notAddVip = 1  -- по умолчанию
end

imgui.OnFrame(
function () return WinState[0] end,
function (this)

    local size, res = imgui.ImVec2(600, 270), imgui.ImVec2(getScreenResolution())
    imgui.SetNextWindowSize(size, imgui.Cond.FirstUseEver)
    --imgui.SetNextWindowPos(imgui.ImVec2(res.x / 2, res.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowPos(imgui.ImVec2(320, 625), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    if (imgui.Begin(faicons('id_card')..u8'  Фарм ЗП  '..(faicons('id_card')), WinState)) then

        if imgui.BeginTabBar('Tabs') then -- задаём начало вкладок

            if imgui.BeginTabItem(faicons('house')..u8' Основное меню') then -- первая вкладка
            
                imgui.CenterText(faicons('id_badge')..u8' Основные настройки скрипта '..faicons('id_badge'))

                imgui.TextColoredRGB('Ваш ник - '..yargoffConfig.nickname)

                if imgui.Checkbox(faicons('jedi')..u8(' АФК ЗП'), clickbutton) then
                    yargoffConfig.status = clickbutton[0]
                    save_settings()
                    sampAddChatMessage(tag..' АФК ЗП - '..(yargoffConfig.status and '{3fc441}Включено' or '{e82c39}Выключено'), -1)
                end

                imgui.SameLine()
                imgui.TextColoredRGB('- '..(yargoffConfig.status and '{3fc441}Включено' or '{e82c39}Выключено'))
                if yargoffConfig.status then
                    imgui.SameLine()
                    imgui.Text(faicons('check'))
                else
                    imgui.SameLine()
                    imgui.Text(faicons('Xmark'))
                end
                if imgui.Checkbox(faicons('chess_king')..u8' ADD VIP', have_addvip) then
                    yargoffConfig.addvip = have_addvip[0]
                    save_settings()
                    sampAddChatMessage(tag..' Вы установили, что '..(yargoffConfig.addvip and '{3fc441}имеете' or '{e82c39}не имеете')..' {FFFFFF}Add Vip, теперь скрипт будет работать по другому методу', -1)
                end
                
                imgui.SameLine()
                imgui.TextColoredRGB('- '..(yargoffConfig.addvip and '{3fc441}Имеется' or '{e82c39}Отсутствует'))
                if yargoffConfig.addvip then
                    imgui.SameLine()
                    imgui.Text(faicons('check'))
                else
                    imgui.SameLine()
                    imgui.Text(faicons('Xmark'))
                end
                imgui.Separator()

                imgui.CenterText(faicons('helmet_safety')..u8' ID организационного скина '..faicons('helmet_safety'))
                imgui.PushItemWidth(215)
                imgui.InputTextWithHint(u8'На данный момент в CFG внесен id скина - '..(yargoffConfig.OrganizationalSkin), u8'Введите организационный id скина', inputField_idOrganizationalSkin, 256)
                imgui.PopItemWidth()
                if imgui.Button(faicons('pen'), imgui.ImVec2(25, 25)) then
                    text = u8:decode(ffi.string(inputField_idOrganizationalSkin))
                    text = tonumber(text)

                    if not text then
                        sampAddChatMessage(tag..' Сработала защита от дебила, это должно быть число/цифра!', -1)
                        return
                    end

                    if text ~= '' then
                        local oldOrg = yargoffConfig.OrganizationalSkin or "Отсутствует"
                        -- Если отличается — обновляем
                        if text ~= oldOrg then
                            yargoffConfig.OrganizationalSkin = text
                            save_settings()
                            sampAddChatMessage(tag .. " Внесен вручную новый id организационного скина - "..text, -1)
                            sampAddChatMessage(tag .. " Заменено в CFG (До этого был id: " .. oldOrg .. ")", -1)
                        else
                            sampAddChatMessage(tag .. " ID организационного скина уже записан - " .. text, -1)
                        end
                    else
                        sampAddChatMessage(tag .. " Вы ничего не написали в поле..", -1)
                    end

                    if imgui.IsItemHovered() then
                        imgui.BeginTooltip()
                        imgui.Text(u8'Вы навелись на кнопку')
                        imgui.EndTooltip()
                    end

                end
                imgui.Hint('hintSecret', faicons('circle_exclamation')..u8' Подсказка:\nКнопка для ручного добавления ID скина.')

                imgui.SameLine()
                if imgui.Button(u8'Внести автоматически', imgui.ImVec2(140, 25)) then
                    local id_skin = getCharModel(PLAYER_PED)
                    local oldOrg = yargoffConfig.OrganizationalSkin or "Отсутствует"
                    -- Если отличается — обновляем
                    if id_skin ~= oldOrg then
                        yargoffConfig.OrganizationalSkin = id_skin
                        save_settings()
                        sampAddChatMessage(tag .. " Записываю новый id организационного скина - "..id_skin, -1)
                        sampAddChatMessage(tag .. " Заменено в CFG (До этого был id: " .. oldOrg .. ")", -1)
                    else
                        sampAddChatMessage(tag .. " ID организационного скина уже записан - " .. id_skin, -1)
                    end
                end
                imgui.Separator()

                imgui.CenterText(faicons('hamsa')..u8' Наименование вашей организации '..faicons('hamsa'))
                imgui.CenterText(u8(yargoffConfig.Organization))
                imgui.SetCursorPos(imgui.ImVec2(260, 235))
                if imgui.Button(u8'Определить', imgui.ImVec2(80, 25)) then
                    checkOrganization = true
                    sampProcessChatInput('/stats')
                end

                imgui.EndTabItem() -- конец вкладки
            end
            if imgui.BeginTabItem(faicons('bed')..u8' Настройки АФК') then -- вторая вкладка
            
                if imgui.BeginTabBar('Tabs') then -- задаём начало вкладок
                
                    if imgui.BeginTabItem(faicons('Angles_Right')..u8' Меню спавна') then -- первая вкладка
                        if yargoffConfig.addvip then
                            imgui.TextColoredRGB('                                                  {FFFFFF}У вас {3fc441}присутствует {FFFFFF}ADD VIP')

                            -- Получаем текущий приоритет (первый элемент, если есть)
                            local current_prioritySpawnOrg = "не выбрано"
                            if #yargoffConfig.SpawnOrg > 0 then
                                current_prioritySpawnOrg = yargoffConfig.SpawnOrg[1]
                            end

                            -- Отображаем текст "Приоритет: ..."
                            imgui.Text(u8"Организационный спавн: " .. u8(current_prioritySpawnOrg))

                            -- Защита: если список пуст
                            if #yargoffConfig.dialog_setspawnAddVip == 0 then
                                imgui.TextColoredRGB('{e82c39}Список мест спавна пуст. Подгрузите список перезайдя на сервер')
                            else
                                -- Выпадающий список
                                if imgui.BeginCombo(u8"##Пункты диалога для ОРГ спавна", u8(selected_name_SpawnOrg or "Выберите место")) then
                                    for i, name in ipairs(yargoffConfig.dialog_setspawnAddVip) do
                                        -- ?? is_selected ДОЛЖЕН быть true/false, НЕ nil
                                        local is_selected = (selected_idx_SpawnOrg == i)

                                        -- Защита от nil в name
                                        if name and type(name) == "string" then
                                            if imgui.Selectable(u8(name), is_selected) then
                                                selected_idx_SpawnOrg = i
                                                selected_name_SpawnOrg = name
                                                yargoffConfig.SpawnOrg = { name }
                                                save_settings()
                                            end

                                            -- Подсветка выбранного элемента
                                            if is_selected then
                                                imgui.SetItemDefaultFocus()
                                            end
                                        end
                                    end
                                    imgui.EndCombo()
                                end
                            end

                            -- Получаем текущий приоритет (первый элемент, если есть)
                            local current_priority = "не выбрано"
                            if #yargoffConfig.priorityAddVip > 0 then
                                current_priority = yargoffConfig.priorityAddVip[1]
                            end

                            -- Отображаем текст "Приоритет: ..."
                            imgui.Text(u8"Приоритетный спавн для АФК: " .. u8(current_priority))

                            -- Защита: если список пуст
                            if #yargoffConfig.dialog_setspawnAddVip == 0 then
                                imgui.TextColoredRGB('{e82c39}Список мест спавна пуст. Подгрузите список перезайдя на сервер')
                            else
                                -- Выпадающий список
                                if imgui.BeginCombo(u8"##Пункты диалога", u8(selected_name_HaveAddVip or "Выберите место")) then
                                    for i, name in ipairs(yargoffConfig.dialog_setspawnAddVip) do
                                        -- ?? is_selected ДОЛЖЕН быть true/false, НЕ nil
                                        local is_selected = (selected_idx_HaveAddVip == i)

                                        -- Защита от nil в name
                                        if name and type(name) == "string" then
                                            if imgui.Selectable(u8(name), is_selected) then
                                                selected_idx_HaveAddVip = i
                                                selected_name_HaveAddVip = name
                                                yargoffConfig.priorityAddVip = { name }
                                                save_settings()
                                            end

                                            -- Подсветка выбранного элемента
                                            if is_selected then
                                                imgui.SetItemDefaultFocus()
                                            end
                                        end
                                    end
                                    imgui.EndCombo()
                                end
                            end
                        else
                            imgui.TextColoredRGB('                                                   {FFFFFF}У вас {e82c39}отсутствует {FFFFFF}ADD VIP')
                            
                            -- Получаем текущий приоритет (первый элемент, если есть)
                            local current_priority = "не выбрано"
                            if #yargoffConfig.prioritySetSpawn > 0 then
                                current_priority = yargoffConfig.prioritySetSpawn[1]
                            end

                            -- Отображаем текст "Приоритет: ..."
                            imgui.Text(u8"Приоритетный спавн для АФК: " .. u8(current_priority))

                            -- Защита: если список пуст
                            if #yargoffConfig.dialog_setspawn == 0 then
                                imgui.TextColoredRGB('{e82c39}Список мест спавна пуст. Подгрузите список через /setspawn.')
                            else
                                -- Выпадающий список
                                if imgui.BeginCombo(u8"##Пункты диалога", u8(selected_name_notAddVip or "Выберите место")) then
                                    for i, name in ipairs(yargoffConfig.dialog_setspawn) do
                                        -- ?? is_selected ДОЛЖЕН быть true/false, НЕ nil
                                        local is_selected = (selected_idx_notAddVip == i)

                                        -- Защита от nil в name
                                        if name and type(name) == "string" then
                                            if imgui.Selectable(u8(name), is_selected) then
                                                selected_idx_notAddVip = i
                                                selected_name_notAddVip = name
                                                yargoffConfig.prioritySetSpawn = { name }
                                                save_settings()
                                            end

                                            -- Подсветка выбранного элемента
                                            if is_selected then
                                                imgui.SetItemDefaultFocus()
                                            end
                                        end
                                    end
                                    imgui.EndCombo()
                                end
                            end
                        end
                        imgui.EndTabItem() -- конец вкладки
                    end
                    if imgui.BeginTabItem(faicons('Angles_Right')..u8' ID интерьеров') then -- первая вкладка
                        imgui.Text(u8'ID интерьера фракции - '..yargoffConfig.interior_org)
                        if imgui.Button(u8'Определить ID интерьера фракции') then
                            local id_int_org = getActiveInterior()
                            if id_int_org ~= yargoffConfig.interior_org then
                                sampAddChatMessage(tag..' Определил ID интерьра вашей фракции, внес данные...', -1)
                                sampAddChatMessage(tag..' Новый ID интерьера фракции - {e39144}'..id_int_org..'. {FFFFFF}ID прошлого - {e39144}'..yargoffConfig.interior_org, -1)
                                yargoffConfig.interior_org = id_int_org
                                save_settings()
                            else
                                sampAddChatMessage(tag..' ID интерьера фракции не изменился, он аналогичен текущему...', -1)
                            end
                        end
                        imgui.Text(u8'ID интерьера места вашего АФК пребывания - '..yargoffConfig.interior_afk)
                        if imgui.Button(u8'Определить ID интерьера места для АФК') then
                            local id_int_afk = getActiveInterior()
                            if id_int_afk ~= yargoffConfig.interior_afk then
                                sampAddChatMessage(tag..' Определил ID интерьра вашей фракции, внес данные...', -1)
                                sampAddChatMessage(tag..' Новый ID интерьера фракции - {e39144}'..id_int_afk..'. {FFFFFF}ID прошлого - {e39144}'..yargoffConfig.interior_afk, -1)
                                yargoffConfig.interior_afk = id_int_afk
                                save_settings()
                            else
                                sampAddChatMessage(tag..' ID интерьера фракции не изменился, он аналогичен текущему...', -1)
                            end
                        end
                        imgui.EndTabItem() -- конец вкладки
                    end
                    if imgui.BeginTabItem(faicons('building')..u8' Льгота') then -- третья вкладка
                        imgui.TextColoredRGB('{f02e2e}[ВНИМАНИЕ]: {FFFFFF}Данный пункт предназанчен только для сотрудников ПД/ФБР (возможно временно)')
                    
                        if imgui.Button(u8'Пропуск ФБР', imgui.ImVec2(100, 25)) then
                            lua_thread.create(function ()
                                wait(500)
                                gticket()
                            end)
                        end
                        imgui.SameLine()
                        if imgui.Button(u8'Мегафон', imgui.ImVec2(100,25)) then
                            lua_thread.create(function ()
                                megafon()
                            end)
                        end
                        imgui.SameLine()
                        if imgui.Button(u8'Метка (/bk)', imgui.ImVec2(100,25)) then
                            sampProcessChatInput('/bk !')
                            sampProcessChatInput('/rb !')
                        end
                        imgui.SameLine()
                        if imgui.Button(u8'Поставить объекты', imgui.ImVec2(125,25)) then
                            fastObject = true
                            sampProcessChatInput('/putobject')
                        end
                    
                        imgui.EndTabItem() -- конец вкладки
                    end
                    imgui.EndTabBar() -- конец всех вкладок
                end
            
                imgui.EndTabItem() -- конец вкладки
            end
            if imgui.BeginTabItem(faicons('location_arrow')..u8' Телеграмм') then -- четвертая вкладка
                
                imgui.EndTabItem() -- конец вкладки
            end

            if imgui.BeginTabItem(faicons('screwdriver_wrench')..u8' Информация о скрипте') then -- пятая вкладка
        
                imgui.TextColoredRGB('{FFFFFF}Автор: {dea940}yargoff')
                imgui.Text(u8'Связь:')
                imgui.SameLine()
                imgui.Link('https://t.me/yarg0ff','Telegram') -- просто откроет ссылку, имя гиперссылки будет VK

                imgui.Text('')
                imgui.TextWrapped(u8'Предыстория: \nЖыл был фармила и ему надо было автоматически переодеваться после кика/отключения/рестарта, но не было достойных скриптов! Один только двигался к пикапу переодевания и больше ничего не делал, другой был совершенным, но к сожалению, автора скрипта не стала и вместе с ним и поддержки на случай каких-то изменений в коде АРЗ (царство небесное JustFedot). И вот нашелся смельчак (я), который изучив то и сё, посмотрев принцип работы скриптиков создал свой ФАРМ ЗП!')
                imgui.Text('')

                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.76, 0.16, 0.16, 1.00))
                imgui.SetNextItemWidth(imgui.GetWindowContentRegionWidth())
                if imgui.Button(u8'Лог изменений') then tab = 1 end -- это первая кнопка, которая будет отвечать за переключение на раздел 1
                imgui.SameLine()
                if imgui.Button(u8'Команды скрипта') then tab = 2 end -- это вторая кнопка, которая будет отвечать за переключение на раздел 2
                if tab == 1 then
                    for i, update_log in ipairs(log) do
                        imgui.TextColoredRGB(update_log)
                    end
                elseif tab == 2 then
                    imgui.TextWrapped(u8'/menuZP - Открыть/Закрыть меню скрипта\n/farmzp - Включить/Выключить АФК ЗП\n/orgSkin - Автоопределение организационного скина\n/addvip - Указать наличие/отсутсвие ADD VIP\n/addCoordPD - Записать координаты куда будет идти персонаж')
                end

                imgui.EndTabItem() -- конец вкладки
            end
            imgui.EndTabBar() -- конец всех вкладок
            end


        imgui.End()
    end
end)

function imgui.CenterText(text) -- Функция центрования текста mimgui
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end

function imgui.TextColoredRGB(text) -- функция окрашивания текста внутри mimgui
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4
    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end
    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r/255, g/255, b/255, a/255)
    end
    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else imgui.Text(u8(w)) end
        end
    end
    render_text(text)
end

function imgui.Link(link, text) -- Текст перенаправляющий на встроенную ссылку
    text = text or link
    local tSize = imgui.CalcTextSize(text)
    local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local col = { 0xFFFF7700, 0xFFFF9900 }
    if imgui.InvisibleButton("##" .. link, tSize) then os.execute("explorer " .. link) end
    local color = imgui.IsItemHovered() and col[1] or col[2]
    DL:AddText(p, color, text)
    DL:AddLine(imgui.ImVec2(p.x, p.y + tSize.y), imgui.ImVec2(p.x + tSize.x, p.y + tSize.y), color)
end

function imgui.Hint(str_id, hint, delay) -- Подсказка на кнопку/текст в mimgui
    local hovered = imgui.IsItemHovered()
    local animTime = 0.2
    local delay = delay or 0.00
    local show = true

    if not allHints then allHints = {} end
    if not allHints[str_id] then
        allHints[str_id] = {
            status = false,
            timer = 0
        }
    end

    if hovered then
        for k, v in pairs(allHints) do
            if k ~= str_id and os.clock() - v.timer <= animTime  then
                show = false
            end
        end
    end

    if show and allHints[str_id].status ~= hovered then
        allHints[str_id].status = hovered
        allHints[str_id].timer = os.clock() + delay
    end

    if show then
        local between = os.clock() - allHints[str_id].timer
        if between <= animTime then
            local s = function(f)
                return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
            end
            local alpha = hovered and s(between / animTime) or s(1.00 - between / animTime)
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
            imgui.SetTooltip(hint)
            imgui.PopStyleVar()
        elseif hovered then
            imgui.SetTooltip(hint)
        end
    end
end



function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end
    sampAddChatMessage(tag..' Скрипт работает! Приятного пользования.. Автор: {c4a01b}yargoff', -1)

    sampRegisterChatCommand('menuZP', function ()
        WinState[0] = not WinState[0]
    end)

    sampRegisterChatCommand('farmzp', function ()
        yargoffConfig.status = not yargoffConfig.status
        save_settings()
        clickbutton[0] = yargoffConfig.status
        sampAddChatMessage(tag..' Автоформа - '..(yargoffConfig.status and 'включена' or 'выключена'), -1)
    end)

    sampRegisterChatCommand('orgSkin', function ()
        local id_skin = getCharModel(PLAYER_PED)
        local oldOrg = yargoffConfig.OrganizationalSkin or "Отсутствует"
        -- Если отличается — обновляем
        if id_skin ~= oldOrg then
            yargoffConfig.OrganizationalSkin = id_skin
            save_settings()
            sampAddChatMessage(tag .. " Записываю новый id организационного скина - "..id_skin, -1)
            sampAddChatMessage(tag .. " Заменено в CFG (До этого был id: " .. oldOrg .. ")", -1)
        else
            sampAddChatMessage(tag .. " ID организационного скина уже записан - " .. id_skin, -1)
        end
    end)

    sampRegisterChatCommand('addvip', function ()
        yargoffConfig.addvip = not yargoffConfig.addvip
        save_settings()
        have_addvip[0] = yargoffConfig.addvip
        sampAddChatMessage(tag..' Вы установили, что '..(yargoffConfig.addvip and '{3fc441}имеете' or '{e82c39}не имеете')..' {FFFFFF}Add Vip, теперь скрипт будет работать по другому методу', -1)
    end)

    sampRegisterChatCommand('run', function ()
        sampAddChatMessage(tag..' {d94545}[TEST FUNCTION]{FFFFFF} Включен принудительный бег!', -1)
        runPD = true
    end)

    sampRegisterChatCommand('ssleep', function ()
        sampAddChatMessage(tag.. ' {d94545}[TEST FUNCTION]{FFFFFF} Фаст спавн орга - '..(spawnSleep and 'OFF' or 'ON'), -1)
        spawnSleep = not spawnSleep
    end)

    sampRegisterChatCommand('sorg', function ()
        sampAddChatMessage(tag.. ' {d94545}[TEST FUNCTION]{FFFFFF} Фаст спавн орга - '..(spawnOrga and 'OFF' or 'ON'), -1)
        spawnOrga = not spawnOrga
    end)

    sampRegisterChatCommand('checkorg', function ()
        sampAddChatMessage(tag.. ' {d94545}[TEST FUNCTION]{FFFFFF} Фаст спавн орга - '..(checkOrganization and 'OFF' or 'ON'), -1)
        checkOrganization = not checkOrganization
    end)

    sampRegisterChatCommand('mySkin', function ()
        local id_skin = getCharModel(PLAYER_PED)
        sampAddChatMessage(tag..'{d94545}[TEST FUNCTION]{FFFFFF} Твой id скина сейчас '..id_skin, -1)
    end)

    sampRegisterChatCommand('addCoordPD', saveCoordinatesPD)

    local _, idplayer = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local nickname = sampGetPlayerNickname(idplayer)
    yargoffConfig.nickname = nickname
    save_settings()

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

function saveCoordinatesPD() -- сохранение координат для функции бега
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

    local id_skin = getCharModel(PLAYER_PED) -- Получаем id скина на персонаже
    
    if checkOrganization then -- Автоопределение организации игрока
        if id == 235 and title:match('{BFBBBA}Основная статистика') then
            -- Перебираем строки
            for line in text:gmatch("[^\r\n]+") do
                -- Ищем и извлекаем организацию
                local org = line:match("Организация:%s*%{B83434%}%[(.+)%]")
                if org then
                    org = org:match("^%s*(.-)%s*$")  -- обрезаем пробелы
                    -- Получаем старое значение из ini
                    local oldOrg = yargoffConfig.Organization or "Отсутствует"
                    -- Если отличается — обновляем
                    if org ~= oldOrg then
                        yargoffConfig.Organization = org
                        save_settings()
                        sampAddChatMessage(tag .. " Обнаружена новая организация: " .. org, -1)
                        sampAddChatMessage(tag .. " Заменено в CFG (было: " .. oldOrg .. ")", -1)
                    else
                        sampAddChatMessage(tag .. " Организация уже известна: " .. org, -1)
                    end

                    -- Закрываем диалог и выключаем checkOrganization
                    lua_thread.create(function ()
                        wait(75)
                        sampCloseCurrentDialogWithButton(0)
                    end)
                    checkOrganization = false
                    return false
                end
            end

            -- Если организация не найдена в диалоге
            statsRetryCount = statsRetryCount + 1
            if statsRetryCount < maxRetries then
                lua_thread.create(function ()
                    sampAddChatMessage(tag .. " Организация не найдена. Повторяем запрос...", -1)
                    wait(1000)  -- небольшая задержка
                    sampProcessChatInput("/stats")
                    end)
            else
                sampAddChatMessage(tag .. " Не удалось получить организацию после 3 попыток.", -1)
                checkOrganization = false
            end
        end
    end

    if id == 581 and id_skin == 12415 then -- Автопереодевания в ОРГ скин [1]
        if text:find('{42B02C}%-{FFFFFF} Переодеться') then
            lua_thread.create(function()
                wait(0)
                listbox = sampGetListboxItemByText('{42B02C}-{FFFFFF} Переодеться')
                sampSendDialogResponse(id, 1, listbox, nil)
                sampCloseCurrentDialogWithButton(0)
                end)
        end
    elseif id == 7551 then -- Автопереодевания в ОРГ скин [2]
        if text:find('- Переодеться в {31853A}рабочую{FFFFFF} форму.') then
            lua_thread.create(function()
                wait(0)
				listbox = sampGetListboxItemByText('- Переодеться в {31853A}рабочую{FFFFFF} форму.')
				sampSendDialogResponse(id, 1, listbox, nil)
            	sampCloseCurrentDialogWithButton(0)
				end)
        end
    end

    if id == 25527 or title:find('Выбор места спавна') then
        local parsed = {}

        for n in text:gmatch('[^\r\n]+') do  -- читаем по строкам
            -- Шаблон 1: "Установить ... местом спавна"
            local line = n:match('%[%d+%] %{ffffff%}%s*(.+)')
            if line then
                table.insert(parsed, line)  -- например: "квартиру №5"
            else
                table.insert(parsed, '')
            end
        end
        yargoffConfig.dialog_setspawnAddVip = parsed
        save_settings()

        if yargoffConfig.addvip == true then -- Выбор спавна персонажа [Метод выбора зависит от наличия/отсутсвия ADD VIP]
            if spawnOrgAddVip then
                for _, pri in ipairs(yargoffConfig.SpawnOrg) do
                    for idx, line in ipairs(parsed) do
                        if line == pri then
                            -- Отправляем ответ и ВЫХОДИМ из функции
                            lua_thread.create(function()
                                wait(50)  -- небольшая пауза для стабильности
                                listbox = sampGetListboxItemByText(line)
                                sampSendDialogResponse(id, 1, listbox, '')
                                sampCloseCurrentDialogWithButton(0)
                                sampAddChatMessage('Автовыбор: '..pri, -1)
                            end)
                            spawnOrgAddVip = false
                            return true
                        end
                    end
                end
            else
                for _, pri in ipairs(yargoffConfig.priorityAddVip) do
                    for idx, line in ipairs(parsed) do
                        if line == pri then
                            -- Отправляем ответ и ВЫХОДИМ из функции
                            lua_thread.create(function()
                                wait(50)  -- небольшая пауза для стабильности
                                listbox = sampGetListboxItemByText(line)
                                sampSendDialogResponse(id, 1, listbox, '')
                                sampCloseCurrentDialogWithButton(0)
                                sampAddChatMessage('Автовыбор: '..pri, -1)
                            end)
                        end
                    end
                end
            end
        end
    end

    if id == 1781 and title:find('Выберите место спавна') then -- чекер /setspawn
        local parsed = {}

        for line in text:gmatch('[^\r\n]+') do  -- читаем по строкам
            -- Шаблон 1: "Установить ... местом спавна"
            local custom_spawn = line:match('Установить (.+) местом спавна')
            if custom_spawn then
                table.insert(parsed, custom_spawn)  -- например: "квартиру №5"
                goto continue
            end

            -- Шаблон 2: "Установить семейную квартиру спавном"
            if line:find('Установить семейную квартиру спавном') then
                table.insert(parsed, 'семейную квартиру')
                goto continue
            end

            -- Шаблон 3: "Сохраненные точки спавна"
            if line:find('Сохраненные точки спавна') then
                table.insert(parsed, 'Сохраненные точки спавна')
                goto continue
            end

            -- Можно добавить другие шаблоны сюда

            ::continue::
        end
        yargoffConfig.dialog_setspawn = parsed
        save_settings()

        if yargoffConfig.addvip == false then -- Выбор спавна персонажа [Метод выбора зависит от наличия/отсутсвия ADD VIP]
            if spawnSleep then -- Автовыбор спавна на ту точку, которую установил пользователь у которого нет ADD VIP
                for _, pri in ipairs(yargoffConfig.prioritySetSpawn) do
                    for idx, line in ipairs(parsed) do
                        if line == pri then
                            -- Отправляем ответ и ВЫХОДИМ из функции
                            lua_thread.create(function()
                                wait(50)  -- небольшая пауза для стабильности
                                listbox = sampGetListboxItemByText(line)
                                sampSendDialogResponse(id, 1, listbox, '')
                                sampCloseCurrentDialogWithButton(0)
                                sampAddChatMessage('Автовыбор: '..pri, -1)
                            end)
                            spawnSleep = false
                            return true
                        end
                    end
                end
            end
            if spawnOrga then -- Автовыбор спавна организации у пользователя который не имеет ADD VIP
                if id == 1781 and title:find('Выберите место спавна') then
                    if text:find('Установить организацию местом спавна') then
                        lua_thread.create(function()
                            wait(0)
                            listbox = sampGetListboxItemByText('Установить организацию местом спавна')
                            sampSendDialogResponse(id, 1, listbox, nil)
                            wait(100)
                            sampCloseCurrentDialogWithButton(0)
                            end)
                    end
                    spawnOrga = false
                end
            end
        end
    end

    if fastObject then
        attempts = attempts + 1
        lua_thread.create(function ()
            wait(950)
            sampProcessChatInput('/putobject')
        end)
        if id == 399 then
            if title:match('{BFBBBA}{FFFFFF}Осталось: {94B0C1}10{FFFFFF} объектов.') then
                sampAddChatMessage('нашел нужный диалог', -1)
                if text:find('Желтая лента') then  -- тут ЭКРАНИРУЕМ
                    sampAddChatMessage('нашел нужный текст', -1)
                    lua_thread.create(function()
                    wait(0)
                    listbox = sampGetListboxItemByText('Желтая лента') -- тут НЕ ЭКРАНИРУЕМ
                    sampSendDialogResponse(id, 1, listbox, nil)
                    sampCloseCurrentDialogWithButton(0)
                    sampAddChatMessage('выбрал '..listbox, -1)
                    end)
                end
            elseif title:match('{BFBBBA}{FFFFFF}Осталось: {94B0C1}9{FFFFFF} объектов.') then
                sampAddChatMessage('нашел нужный диалог', -1)
                if text:find('%{FF6347%}Убрать объект') then  -- тут ЭКРАНИРУЕМ
                    sampAddChatMessage('нашел нужный текст', -1)
                    lua_thread.create(function()
                    wait(0)
                    listbox = sampGetListboxItemByText('{FF6347}Убрать объект') -- тут НЕ ЭКРАНИРУЕМ
                    sampSendDialogResponse(id, 1, listbox, nil)
                    sampCloseCurrentDialogWithButton(0)
                    sampAddChatMessage('выбрал '..listbox, -1)
                    end)
                end
            end
        end
        if attempts >= maxAttempts then
            fastObject = false
            sampAddChatMessage("Готово: выполнено " .. maxAttempts .. " действий.", -1)
        end
    end
    

end

function ev.onServerMessage(color, text) -- поиск серверных сообщений
    
    local inta = getCharActiveInterior(PLAYER_PED)
    local id_skin = getCharModel(PLAYER_PED)

    local WhoIsClothes = string.match(text, yargoffConfig.nickname..' переодевается в (.+) одежду.') -- {C2A2DA}Aang_Mercenari переодевается в рабочую одежду.
    if WhoIsClothes == 'рабочую' then --  Автоматический перезаход на точку АФК спавна
        if yargoffConfig.status then
            if yargoffConfig.addvip == true then
                sampAddChatMessage(tag..' Нашел, что вы переоделись в РАБОЧУЮ одежду!', -1)
                lua_thread.create(function ()
                    wait(10)
                    local id_skin = getCharModel(PLAYER_PED)
                    if id_skin == (yargoffConfig.OrganizationalSkin) then
                        spawnOrgAddVip = false
                        wait(1000)
                        sampProcessChatInput('/rec 3')
                    end
                end)
            else
                sampAddChatMessage(tag..' Нашел, что вы переоделись в РАБОЧУЮ одежду!', -1)
                lua_thread.create(function ()
                    wait(10)
                    local id_skin = getCharModel(PLAYER_PED)
                    if id_skin == (yargoffConfig.OrganizationalSkin) then
                        spawnSleep = true
                        wait(1000) -- Тут стоит именно такая задержка из-за того, что скрипт на успевает заменить способ спавна
                        sampProcessChatInput('/setspawn')
                    end
                end)
            end
        end
    end

    if text:find('На сервере есть инвентарь, используйте клавишу Y для работы с ним.') then -- Узнать какая организация если пользователь впервые загрузил скрипт

        if not yargoffConfig.Organization or yargoffConfig.Organization == "" then
            lua_thread.create(function ()
                checkOrganization = true
                statsRetryCount = 0
                sampAddChatMessage(tag .. " Организация неизвестна. Запрашиваю статистику...", -1)
                wait(500)
                sampProcessChatInput("/stats")
            end)
        end

        if yargoffConfig.status then
            if yargoffConfig.addvip then
                    if inta == yargoffConfig.interior_afk then
                        if id_skin == (yargoffConfig.OrganizationalSkin) then
                            sampAddChatMessage(tag..' Вы заспавнились нужном месте для АФК, если вас не будет в игре 5+ минут, вы перезайдете на орг. спавн', -1)
                        elseif id_skin ~= (yargoffConfig.OrganizationalSkin) then
                            sampAddChatMessage(tag.. ' Вы в нужной инте, но не в нужном скине. Перезаходим...', -1)
                            spawnOrgAddVip = true
                            sampProcessChatInput('/rec 3')
                        end
                    elseif inta == yargoffConfig.interior_org then
                        if id_skin ~= (yargoffConfig.OrganizationalSkin) then
                            sampAddChatMessage(tag..' Вы заспавнились в организации, бегу переодеваться...', -1)
                            runPD = true
                        elseif id_skin == (yargoffConfig.OrganizationalSkin) then
                            sampAddChatMessage(tag..' Упс... Почему-то вы в инте организации и рабочей форме! Перезахожу...', -1)
                            spawnOrgAddVip = false
                            sampProcessChatInput('/rec 3')
                        end
                    end
            else
                    if inta == yargoffConfig.interior_afk then
                        if id_skin == (yargoffConfig.OrganizationalSkin) then
                            sampAddChatMessage(tag..' Вы заспавнились в отеле, ставлю место спавна на - организацию', -1)
                            lua_thread.create(function()
                                spawnOrga = true
                                wait(500)
                                sampProcessChatInput('/setspawn')
                                end)
                        elseif id_skin ~= (yargoffConfig.OrganizationalSkin) then
                            sampAddChatMessage(tag.. ' Вы в нужной инте, но не в нужном скине. Перезаходим...', -1)
                            lua_thread.create(function()
                                spawnOrga = true
                                wait(500)
                                sampProcessChatInput('/setspawn')
                                end)
                        end
                    elseif inta == yargoffConfig.interior_org then
                        if id_skin ~= (yargoffConfig.OrganizationalSkin) then
                            sampAddChatMessage(tag..' Вы заспавнились в организации, бегу переодеваться...', -1)
                            runPD = true
                        elseif id_skin == (yargoffConfig.OrganizationalSkin) then
                            sampAddChatMessage(tag..' Упс... Почему-то вы в инте организации и рабочей форме! Перезахожу...', -1)
                            lua_thread.create(function()
                                spawnSleep = true
                                wait(500)
                                sampProcessChatInput('/setspawn')
                                end)
                        end
                    end
            end
        end
    end

    if yargoffConfig.status then -- Установить место АФК спавна [Для тех у кого нет ADD VIP]
        if yargoffConfig.addvip == false then

            local prioritySetSpawn = "не выбрано"
            if #yargoffConfig.prioritySetSpawn > 0 then
                prioritySetSpawn = yargoffConfig.prioritySetSpawn[1]
            end

            if text:find('Вы установили '..prioritySetSpawn..' местом спавна!') then
                if id_skin == (yargoffConfig.OrganizationalSkin) then
                sampAddChatMessage(tag..' Вы изменили спавн на '..prioritySetSpawn..', перезаходим туда...', -1)
                lua_thread.create(function()
                    wait(500)
                    sampProcessChatInput('/rec 3')
                    end)
                end
            elseif text:find('Вы установили организацию местом спавна!') then
                if id_skin ~= (yargoffConfig.OrganizationalSkin) then
                    sampProcessChatInput('/rec 3')
                else
                    sampAddChatMessage(tag..' Вы изменили спавн на организацию, если вы выйдите, то появитесь в '..yargoffConfig.Organization, -1)
                end
            end
        end
    end
end

function gticket()
   local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED) -- получить свой ид
	if result then
		sampAddChatMessage(tag..' Твой ID определен: {e31717}'..id..'{FFFFFF}. Вписываю его в команду!', -1)
		sampSendChat('/giveticket '..id)
		wait(500)
		sampAddChatMessage(tag..' Пропуск выдан, очищаю инвентарь от говна', -1)
		sampSendChat('/taketicket '..id)
	else
		sampAddChatMessage(tag..' Не удалось получить ID фармилы', -1)
	end 
end

function megafon()
    for i = 1,5 do
		sampSendChat('/m .')
		wait(1100)
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

function theme() -- Стиль mimgui
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2

    style.WindowPadding = imgui.ImVec2(8, 8)
    style.WindowRounding = 6
    style.ChildRounding = 5
    style.FramePadding = imgui.ImVec2(5, 3)
    style.FrameRounding = 3.0
    style.ItemSpacing = imgui.ImVec2(5, 4)
    style.ItemInnerSpacing = imgui.ImVec2(4, 4)
    style.IndentSpacing = 21
    style.ScrollbarSize = 10.0
    style.ScrollbarRounding = 13
    style.GrabMinSize = 8
    style.GrabRounding = 1
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    colors[clr.Text]                   = ImVec4(0.95, 0.96, 0.98, 1.00);
    colors[clr.TextDisabled]           = ImVec4(0.29, 0.29, 0.29, 1.00);
    colors[clr.WindowBg]               = ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[clr.ChildBg]                = ImVec4(0.12, 0.12, 0.12, 1.00);
    colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94);
    colors[clr.Border]                 = ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[clr.BorderShadow]           = ImVec4(1.00, 1.00, 1.00, 0.10);
    colors[clr.FrameBg]                = ImVec4(0.22, 0.22, 0.22, 1.00);
    colors[clr.FrameBgHovered]         = ImVec4(0.18, 0.18, 0.18, 1.00);
    colors[clr.FrameBgActive]          = ImVec4(0.09, 0.12, 0.14, 1.00);
    colors[clr.TitleBg]                = ImVec4(0.14, 0.14, 0.14, 0.81);
    colors[clr.TitleBgActive]          = ImVec4(0.14, 0.14, 0.14, 1.00);
    colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51);
    colors[clr.MenuBarBg]              = ImVec4(0.20, 0.20, 0.20, 1.00);
    colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.39);
    colors[clr.ScrollbarGrab]          = ImVec4(0.36, 0.36, 0.36, 1.00);
    colors[clr.ScrollbarGrabHovered]   = ImVec4(0.18, 0.22, 0.25, 1.00);
    colors[clr.ScrollbarGrabActive]    = ImVec4(0.24, 0.24, 0.24, 1.00);
    colors[clr.CheckMark]              = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.SliderGrab]             = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.SliderGrabActive]       = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.Button]                 = ImVec4(0.76, 0.16, 0.16, 1.00);
    colors[clr.ButtonHovered]          = ImVec4(1.00, 0.39, 0.39, 1.00);
    colors[clr.ButtonActive]           = ImVec4(1.00, 0.21, 0.21, 1.00);
    colors[clr.Header]                 = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.HeaderHovered]          = ImVec4(1.00, 0.39, 0.39, 1.00);
    colors[clr.HeaderActive]           = ImVec4(1.00, 0.21, 0.21, 1.00);
    colors[clr.ResizeGrip]             = ImVec4(1.00, 0.28, 0.28, 1.00);
    colors[clr.ResizeGripHovered]      = ImVec4(1.00, 0.39, 0.39, 1.00);
    colors[clr.ResizeGripActive]       = ImVec4(1.00, 0.19, 0.19, 1.00);
    colors[clr.Tab]                    = ImVec4(0.09, 0.09, 0.09, 1.00);
    colors[clr.TabHovered]             = ImVec4(0.58, 0.23, 0.23, 1.00);
    colors[clr.TabActive]              = ImVec4(0.76, 0.16, 0.16, 1.00);
    colors[clr.Button]                 = ImVec4(0.40, 0.39, 0.38, 0.16);
    colors[clr.ButtonHovered]          = ImVec4(0.40, 0.39, 0.38, 0.39);
    colors[clr.ButtonActive]           = ImVec4(0.40, 0.39, 0.38, 1.00);
    colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00);
    colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00);
    colors[clr.PlotHistogram]          = ImVec4(1.00, 0.21, 0.21, 1.00);
    colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.18, 0.18, 1.00);
    colors[clr.TextSelectedBg]         = ImVec4(1.00, 0.32, 0.32, 1.00);
    colors[clr.ModalWindowDimBg]   = ImVec4(0.26, 0.26, 0.26, 0.60);
end