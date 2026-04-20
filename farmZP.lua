script_name('{20a1d4}FarmZP by {e38329}yargoff')
script_author('{ff7e14}yargoff')
script_version("1.6a")

require('lib.moonloader')
local ev = require('samp.events')
local imgui = require('mimgui')
local ffi = require('ffi')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local faicons = require('fAwesome6')

local log = {

'{c4a549}[18.01.26] {FFFFFF}0.1b - Простой скриптик для бега по кордам',
'{FFFFFF}ver. 0.5b - Переделан скрипт под автопереодевание формы и перезахода на другое место спавна для АФК фарма ЗП',
'{FFFFFF}ver. 0.5.1b - Добавлен inicfg для более удобного взаимодействия',
'{FFFFFF}ver. pre 1a - Доработан скрипт до нужного результата, чуть исправлен код',
'{FFFFFF}ver. 1.1a - Исправление кода, оптимизация',
'{FFFFFF}ver. 1.3a - Добавлена проверка статистики игрока на наличие организации, а так же команда для указания наличия/отсутствия add vip (по умолчанию: отсутствует)',
'{FFFFFF}ver. 1.3.1a - Исправлен баг с выбором спавна после переодевания в форму ПДшника',
'{c4a549}[03.02.26] {FFFFFF}ver. 1.4a - Добавлено mimgui', 
'{c4a549}[04.02.26] {FFFFFF}ver. 1.4.1a - Отредактированы некоторые задержки, добавил открытие/закрытие меню :)', 
'{c4a549}[05.02.26] {FFFFFF}ver. 1.4.2a - Незначительные изменения кода // Добавление картинок из fAwesome6 // Задел под взаимодействие с Телеграммом',
'{c4a549}[06.02.26] {FFFFFF}ver. 1.5a - Отказался от inicfg в пользу JSON таблиц с использованием IO. Переделал немного меню под работу с JSON.',
'Переработал схему спавна как для тех кто имеет AddVip, так и не имеющих это дополнение.',
'[Работу с AddVip не проверял, потому что не имею её на том аккаунте на котором нахожусь в этот момент]',
'{c4a549}[08.02.26] {FFFFFF}ver. 1.5.2a - Добавил пункт с льготой',
'{c4a549}[15.02.26 - 16.02.26] {FFFFFF}ver. 1.5.5a - Добавил запись ника. Доделал работу скрипта, если у пользователя имеется AddVip [Все работает ;)] ',
'{c4a549}[08.04.26 - 09.04.26] {FFFFFF}ver. 1.6a - После некоторого затишься возвращаюсь к работе.',
'Из нового: 1. Парс wbook с автопополнением льготы (в будущем буду делать, чтобы пользователь сам все настраивал под себя),',
'2. Пока только для FBI отображнение кнопок для быстрого выполнения заданий и их окрас (зеленый/красный), обозначающий выполнено/не выполнено,',
'3. Автопополнение льготы с наступлением нового дня (После пользователь сам будет менять когда проверять уровень льготы)',
'4. Отказ от идеи с взаимодействием через Телеграмм',
'{c4a549}[12.04.26 - 13.04.26] {FFFFFF}ver. 1.8a - В связи с выходном новой обновы теперь: 1. Автопополнения льготы - нет;', 
'2. Для тех у кого нет ADD VIP работать не будет (функционал вырезан);', 
'3. Переработан автовход в игру (Работает теперь только на новом виде авторизации)'

}

local command = {
    '/menuzp - Открыть меню',
    '/addcoord - добавить координаты'
}

local tag = '{20a1d4}[ФАРМ ЗП]{FFFFFF}'
local base_color = 0x29c2ff

function json(filePath)
    local filePath = getWorkingDirectory()..'\\config\\'..(filePath:find('(.+).json') and filePath or filePath..'.json')
    local class = {}
    if not doesDirectoryExist(getWorkingDirectory()..'\\config') then
        createDirectory(getWorkingDirectory()..'\\config')
    end
    
    function class:Save(tbl)
        if tbl then
            local F = io.open(filePath, 'w')
            F:write(encodeJson(tbl) or {})
            F:close()
            return true, 'ok'
        end
        return false, 'table = nil'
    end

    function class:Load(defaultTable)
        if not doesFileExist(filePath) then
            class:Save(defaultTable or {})
        end
        local F = io.open(filePath, 'r+')
        local TABLE = decodeJson(F:read() or {})
        F:close()
        for def_k, def_v in next, defaultTable do
            if TABLE[def_k] == nil then
                TABLE[def_k] = def_v
            end
        end
        return TABLE
    end

    return class
end

local name_file = 'FarmZP.json'
local settings = json(name_file):Load({
    status = false,
    runStripuha = false,             -- Автобег в стрипухе
    OrganizationalSkin = 0,          -- ID скина (число)
    Organization = "",               -- имя организации
    nickname = "",                   -- Ник пользователя скрипта
    priorityAddVip = {},             -- приоритет спавна для тех у кого есть AddVip (массив)
    SpawnOrg = {},                   -- Cпавн организационный (массив)
    dialog_setspawnAddVip = {        -- пункты диалога add vip (массив строк)
        id = '',
        name = ''
    },
    interior_org = 0,                -- id интерьера фракции
    interior_afk = 0,                -- id интерьера места для АФК
})

local function save_settings()
    json(name_file):Save(settings)
end

local function message(text)
    if not text or text == '' then
        return
    end
    sampAddChatMessage(tag..' '..text, base_color)
end

-- Гарантируем, что нужные поля существуют
settings.prioritySetSpawn = settings.prioritySetSpawn or {}
settings.priorityAddVip = settings.priorityAddVip or {}
settings.SpawnOrg = settings.SpawnOrg or {}
settings.dialog_setspawnAddVip = settings.dialog_setspawnAddVip or {}

local iniCoordsPD = getWorkingDirectory() .. "\\config\\coordPD.txt" -- Путь к txt файлу
local iniCoordsStripuha = getWorkingDirectory() .. "\\config\\coordStripuha.txt" -- Путь к txt файлу

---------------------------------------------------------- ПЕРЕМЕННЫЕ ----------------------------------------------------------

local fastpass = false
local fastobisk = false
local oneUse = false
local findplayer = false; local seekplayer = nil
local spawnOrgAddVip = true
local runPD = false
local runStrip = false
local xaa = 0
local yaa = 0
local autoAFKn = 0
local autoAFK = false

local inputField_idOrganizationalSkin = imgui.new.char[256]() -- Вписывание чего-либо в строчку
local clickbutton = imgui.new.bool(settings.status)
local runStripuha = imgui.new.bool(settings.runStripuha)
local tab = 0 -- выбирать между логом и командами скрипта в mimgui

local WinState = imgui.new.bool(false) -- Открытие/Закрытие основного окна

----------------------------------------------------------------------------------------------------------------------------------

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14, config, iconRanges) -- solid - тип иконок, так же есть thin, regular, light и duotone
    theme()
end)

-- Синхронизация с сохранённым приоритетом спавна в Организации
if #settings.SpawnOrg > 0 then
    selected_name_SpawnOrg = settings.SpawnOrg[1]
    -- Найдём индекс в списке
    for i, name in ipairs(settings.dialog_setspawnAddVip) do
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
if #settings.prioritySetSpawn > 0 then
    selected_name_HaveAddVip = settings.prioritySetSpawn[1]
    -- Найдём индекс в списке
    for i, name in ipairs(settings.dialog_setspawnAddVip) do
        if name == selected_name_HaveAddVip then
            selected_idx_HaveAddVip = i
            break
        end
    end
else
    selected_name_HaveAddVip = "Выберите место спавна"
    selected_idx_HaveAddVip = 1  -- по умолчанию
end

local function getSortedSpawnList()
    local list = {}

    -- Проверяем существование и тип settings.dialog_setspawnAddVip
    if not settings or not settings.dialog_setspawnAddVip or type(settings.dialog_setspawnAddVip) ~= "table" then
        return list
    end

    for _, v in pairs(settings.dialog_setspawnAddVip) do
        -- Проверяем наличие полей name и id
        if v and v.name and v.id ~= nil then
            -- Преобразуем id из строки в число, если это возможно
            local idNum = tonumber(v.id)
            if idNum ~= nil then
                -- Создаём копию элемента с числовым id для корректной сортировки
                table.insert(list, {
                    name = v.name,
            id = idNum
                })
            end
        end
    end

    -- Сортируем по числовому id по возрастанию
    table.sort(list, function(a, b)
        return a.id < b.id
    end)

    return list
end

imgui.OnFrame(
function () return WinState[0] end,
function (this)

    local size, res = imgui.ImVec2(350, 260), imgui.ImVec2(getScreenResolution())
    imgui.SetNextWindowSize(size, imgui.Cond.FirstUseEver)
    --imgui.SetNextWindowPos(imgui.ImVec2(res.x / 2, res.y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowPos(imgui.ImVec2(320, 625), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    if (imgui.Begin(faicons('id_card')..u8'  Фарм ЗП  '..(faicons('id_card')), WinState)) then

        if imgui.BeginTabBar('Tabs') then -- задаём начало вкладок

            if imgui.BeginTabItem(faicons('house')..u8' Основное меню') then -- первая вкладка
             
                imgui.CenterText(faicons('id_badge')..u8' Основные настройки скрипта '..faicons('id_badge'))

                if imgui.Checkbox(faicons('jedi')..u8(' АФК ЗП'), clickbutton) then
                    settings.status = clickbutton[0]
                    save_settings()
                end
                imgui.Separator()
                imgui.CenterText(faicons('helmet_safety')..u8' ID организационного скина '..faicons('helmet_safety'))
                imgui.Text(u8('На данный момент в CFG внесен id скина - '..(settings.OrganizationalSkin)))
                imgui.PushItemWidth(215)
                imgui.InputTextWithHint(u8'##323124124214', u8'Введите организационный id скина', inputField_idOrganizationalSkin, 256)
                imgui.PopItemWidth()
                if imgui.Button(faicons('pen'), imgui.ImVec2(25, 25)) then
                    text = u8:decode(ffi.string(inputField_idOrganizationalSkin))
                    text = tonumber(text)

                    if not text then
                        sampAddChatMessage(tag..' Сработала защита от дебила, это должно быть число/цифра!', -1)
                        return
                    end

                    if text ~= '' then
                        local oldOrg = settings.OrganizationalSkin or "Отсутствует"
                        -- Если отличается — обновляем
                        if text ~= oldOrg then
                            settings.OrganizationalSkin = text
                            save_settings()
                            sampAddChatMessage(tag .. " Внесен вручную новый id организационного скина - " .. text, base_color)
                            sampAddChatMessage(tag .. " Заменено в CFG (До этого был id: " .. oldOrg .. ")", base_color)
                        else
                            sampAddChatMessage(tag .. " ID организационного скина уже записан - " .. text, base_color)
                        end
                    else
                        sampAddChatMessage(tag .. " Вы ничего не написали в поле..", base_color)
                    end
                end
                if imgui.IsItemHovered() then
                    imgui.BeginTooltip()
                    imgui.Text(u8'Ввести ID скина вручную')
                    imgui.EndTooltip()
                end

                imgui.SameLine()
                if imgui.Button(u8'Внести автоматически', imgui.ImVec2(140, 25)) then
                    local id_skin = getCharModel(PLAYER_PED)
                    local oldOrg = settings.OrganizationalSkin or "Отсутствует"
                    -- Если отличается — обновляем
                    if id_skin ~= oldOrg then
                        settings.OrganizationalSkin = id_skin
                        save_settings()
                        sampAddChatMessage(tag .. " Записываю новый id организационного скина - " .. id_skin, base_color)
                        sampAddChatMessage(tag .. " Заменено в CFG (До этого был id: " .. oldOrg .. ")", base_color)
                    else
                        sampAddChatMessage(tag .. " ID организационного скина уже записан - " .. id_skin, base_color)
                    end
                end

                imgui.EndTabItem() -- конец вкладки
            end
            if imgui.BeginTabItem(faicons('bed')..u8' Настройки АФК') then -- вторая вкладка
            
                if imgui.BeginTabBar('Tabs') then -- задаём начало вкладок
                
                    if imgui.BeginTabItem(faicons('Angles_Right')..u8' Меню спавна') then -- первая вкладка
                    
                        if imgui.Checkbox(u8'Автострипуха', runStripuha) then
                            settings.runStripuha = runStripuha[0]
                            save_settings()
                        end
                    
                        -- Получаем текущий приоритет (первый элемент, если есть)
                        local current_prioritySpawnOrg = "не выбрано"
                        if #settings.SpawnOrg > 0 then
                            current_prioritySpawnOrg = settings.SpawnOrg[1]
                        end

                        -- Отображаем текст "Приоритет: ..."
                        imgui.Text(u8"Организационный спавн: " .. u8(current_prioritySpawnOrg))

                        local sortedList = getSortedSpawnList()

                        if #sortedList == 0 then
                            imgui.TextColoredRGB('{e82c39}Список мест спавна пуст. Подгрузите список перезайдя на сервер')
                        else
                            if imgui.BeginCombo(u8"##Пункты диалога для ОРГ спавна", u8(selected_name_SpawnOrg or "Выберите место")) then
                                
                                for _, v in ipairs(sortedList) do
                                    local is_selected = (selected_name_SpawnOrg == v.name)

                                    if imgui.Selectable(u8(v.name), is_selected) then
                                        selected_name_SpawnOrg = v.name
                                        settings.SpawnOrg = { v.name }
                                        save_settings()
                                    end

                                    if is_selected then
                                        imgui.SetItemDefaultFocus()
                                    end
                                end

                                imgui.EndCombo()
                            end
                        end

                        -- Получаем текущий приоритет (первый элемент, если есть)
                        local current_priority = "не выбрано"
                        if #settings.priorityAddVip > 0 then
                            current_priority = settings.priorityAddVip[1]
                        end

                        -- Отображаем текст "Приоритет: ..."
                        imgui.Text(u8"Приоритетный спавн для АФК: " .. u8(current_priority))

                        local sortedList = getSortedSpawnList()

                        if #sortedList == 0 then
                            imgui.TextColoredRGB('{e82c39}Список мест спавна пуст. Подгрузите список перезайдя на сервер')
                        else
                            if imgui.BeginCombo(u8"##Пункты диалогаADDVIP", u8(selected_name_HaveAddVip or "Выберите место спавна")) then
                                
                                for _, v in ipairs(sortedList) do
                                    local is_selected = (selected_name_HaveAddVip == v.name)

                                    if imgui.Selectable(u8(v.name), is_selected) then
                                        selected_name_HaveAddVip = v.name
                                        settings.priorityAddVip = { v.name }
                                        save_settings()
                                    end

                                    if is_selected then
                                        imgui.SetItemDefaultFocus()
                                    end
                                end

                                imgui.EndCombo()
                            end
                        end
                        imgui.EndTabItem() -- конец вкладки
                    end
                    if imgui.BeginTabItem(faicons('Angles_Right')..u8' ID интерьеров') then -- первая вкладка
                        imgui.Text(u8'ID интерьера фракции - '..settings.interior_org)
                        if imgui.Button(u8'Определить ID интерьера фракции') then
                            local id_int_org = getActiveInterior()
                            if id_int_org ~= settings.interior_org then
                                sampAddChatMessage(tag..' Определил ID интерьра вашей фракции, внес данные...', -1)
                                sampAddChatMessage(tag..' Новый ID интерьера фракции - {e39144}'..id_int_org..'{FFFFFF}. ID прошлого - {e39144}'..settings.interior_org, -1)
                                settings.interior_org = id_int_org
                                save_settings()
                            else
                                sampAddChatMessage(tag..' ID интерьера фракции не изменился, он аналогичен текущему...', -1)
                            end
                        end
                        imgui.Text(u8'ID интерьера места вашего АФК пребывания - '..settings.interior_afk)
                        local int = {
                            ['Улица'] = 0, ['Стрипуха'] = 255, ['Трейлер'] = 141, ['Космо-КВ'] = 23
                        }

                        for i, v in pairs(int) do
                            if imgui.Button(u8(i)) then
                                sampAddChatMessage(tag..' Установил ID интерьера - '..v, -1)
                                settings.interior_afk = v
                                save_settings()
                            end
                        end
                        
                        if imgui.Button(u8'Определить ID интерьера места для АФК') then
                            local id_int_afk = getActiveInterior()
                            if id_int_afk ~= settings.interior_afk then
                                sampAddChatMessage(tag..' Определил ID интерьра для АФК, внес данные...', -1)
                                sampAddChatMessage(tag..' Новый ID интерьера для АФК - {e39144}'..id_int_afk..'{FFFFFF}. ID прошлого - {e39144}'..settings.interior_afk, -1)
                                settings.interior_afk = id_int_afk
                                save_settings()
                            else
                                sampAddChatMessage(tag..' ID интерьера для АФК не изменился, он аналогичен текущему...', -1)
                            end
                        end
                        imgui.EndTabItem() -- конец вкладки
                    end
                    imgui.EndTabBar() -- конец всех вкладок
                end
            
                imgui.EndTabItem() -- конец вкладки
            end
            if imgui.BeginTabItem(faicons('screwdriver_wrench')..u8' Информация о скрипте') then -- пятая вкладка
        
                imgui.TextColoredRGB('{FFFFFF}Автор: {dea940}yargoff')
                imgui.Text(u8'Связь:')
                imgui.SameLine()
                imgui.Link('https://t.me/yarg0ff','Telegram')

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
                    for i, v in ipairs(command) do
                        imgui.TextWrapped(u8(v))
                    end                
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

function imgui.ColoredButton(text,hex,trans,size)
    local r,g,b = tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
    if tonumber(trans) ~= nil and tonumber(trans) < 101 and tonumber(trans) > 0 then a = trans else a = 60 end
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(r/255, g/255, b/255, a/100))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(r/255, g/255, b/255, a/100))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(r/255, g/255, b/255, a/100))
    local button = imgui.Button(text, size)
    imgui.PopStyleColor(3)
    return button
end

function getMSKTime()
    local utc = os.time(os.date("!*t")) -- UTC
    local msk = utc + 3 * 3600          -- UTC+3 (МСК)
    return os.date("%H:%M", msk)
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end
    message('Скрипт работает! Приятного пользования.. Автор: {c4a01b}yargoff')

    sampRegisterChatCommand('menuZP', function ()
        WinState[0] = not WinState[0]
    end)

    sampRegisterChatCommand('addcoord', saveCoordinatesPD)
    sampRegisterChatCommand('addcoordstrip', saveCoordinatesStripuha)

    sampRegisterChatCommand('fp', function (arg)
        fastpass = true
        sampSendChat('/frisk '..arg)
    end)

    sampRegisterChatCommand('fo', function (arg)
        fastobisk = true
        sampSendChat('/frisk '..arg)
    end)

    local _, idplayer = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local nickname = sampGetPlayerNickname(idplayer)
    settings.nickname = nickname
    save_settings()

    sampRegisterChatCommand('ifind', function (arg)
        if not arg or arg == '' then
            -- Если команда без аргумента — всегда выключаем поиск
            findplayer = false
            sampAddChatMessage(tag .. ' Поиск игрока {ff0000}выключен', base_color)
            return
        end

        seekplayer = arg
        findplayer = not findplayer -- Переключаем состояние
        sampAddChatMessage(tag .. ' Поиск игрока ' .. (findplayer and '{68d660}включен' or '{ff0000}выключен'), base_color)
    end)

    sampRegisterChatCommand('mzpafk', function ()
        autoAFK = not autoAFK
        sampAddChatMessage(tag..' АвтоАФК - '..(autoAFK and '{68d660}включено' or '{ff0000}выключено'), base_color)
    end)
    
    while true do
        wait(0)
        local id_int_afk = getActiveInterior()

        if runPD then
            local iniFile = io.open(iniCoordsPD, 'r')
            wait(150)
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

        if settings.runStripuha and id_int_afk == 255 and runStrip then
            setCharCoordinates(PLAYER_PED, 1505, 1447, 10)
            local iniFile = io.open(iniCoordsStripuha, 'r')
            wait(150)
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
            runStrip = false -- выключаем функцию
		    iniFile:close() -- Закрываем файл
            autoAFKn = 1
            autoAFK = true
            sampAddChatMessage(tag..' АвтоАФК - '..(autoAFK and '{68d660}включено' or '{ff0000}выключено'), base_color)
        end

        if findplayer then
            wait(2000)
            sampSendChat('/find '..seekplayer)
        end

        if settings.runStripuha and not sampIsLocalPlayerSpawned() and autoAFKn == 1 then
            autoAFKn = 2
            autoAFK = false
            sampAddChatMessage(tag..' АвтоАФК - '..(autoAFK and '{68d660}включено' or '{ff0000}выключено'), base_color)
        end

        if settings.status then
            for k, v in pairs(getAllPickups()) do
                if doesPickupExist(v.handle) then
                    local x,y,z = getCharCoordinates(1)
                    local pickID = sampGetPickupSampIdByHandle(v.handle)
                    local pickModel = v.model
                    local px, py, pz = getPickupCoordinates(v.handle)
                    local cx, cy = convert3DCoordsToScreen(px,py,pz)
                    local distance = getDistanceBetweenCoords2d(px,py,x,y)
                    if distance < 3 and pickModel == 1275 then
                        sampSendPickedUpPickup(pickID)
                    end
                end
            end
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

function saveCoordinatesStripuha() -- сохранение координат для функции бега
    local playerX, playerY, playerZ = getCharCoordinates(PLAYER_PED) -- Получаем координаты игрока

    -- Создаем/открываем ini файл для записи
    local iniFile = io.open(iniCoordsStripuha, "a+")

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

function ev.onSendPlayerSync(data)
	if autoAFK then return false end
end
local st = 0
function ev.onShowDialog(id, style, tit, button1, button2, text) -- поиск серверных диалогов
    
    if tit:match('Обыск игрока') then
        if fastpass then
            sampSendDialogResponse(id, 1, 0, '')
            sendCEF('documents.close')
            fastpass = false
            return false
        elseif fastobisk then
            sampSendDialogResponse(id, 1, 1, '')
            sendCEF('documents.close')
            return false
        elseif st == 1 then
            sampSendDialogResponse(id, 1, nil, '')
            sendCEF('documents.close')
            st = 0
            return false
        end
    end

    if tit:match('{BFBBBA}Подтвердите действие') and fastobisk then
        sampSendDialogResponse(id, 1, nil, '')
        st = 1
        fastobisk = false
        sendCEF('documents.close')
        return false
    end

end

function ev.onServerMessage(color, text) -- поиск серверных сообщений

    local WhoIsClothes = string.match(text, settings.nickname..' переодевается в (.+) одежду.') -- {C2A2DA}Aang_Mercenari переодевается в рабочую одежду.
    if WhoIsClothes == 'рабочую' then --  Автоматический перезаход на точку АФК спавна
        if settings.status then
            sampAddChatMessage(tag..' Нашел, что вы переоделись в РАБОЧУЮ одежду!', -1)
            lua_thread.create(function ()
                wait(10)
                local id_skin = getCharModel(PLAYER_PED)
                if id_skin == settings.OrganizationalSkin then
                    spawnOrgAddVip = false
                    wait(1000)
                    sampProcessChatInput('/rec 3')
                end
            end)
        end
    end

    if text:find('{DFCFCF}%[Подсказка%] {DC4747}На сервере есть инвентарь, используйте клавишу Y для работы с ним.') then
        local inta = getCharActiveInterior(PLAYER_PED)
        local id_skin = getCharModel(PLAYER_PED)
        if settings.status then
            if inta == settings.interior_afk then
                if id_skin == settings.OrganizationalSkin then
                    sampAddChatMessage(tag..' Вы заспавнились в нужном месте для АФК, если вас не будет в игре 5+ минут, вы перезайдете на орг. спавн', -1)
                elseif id_skin ~= settings.OrganizationalSkin then
                    sampAddChatMessage(tag.. ' Вы в нужной инте, но не в нужном скине. Перезаходим...', -1)
                    spawnOrgAddVip = true
                    sampProcessChatInput('/rec 3')
                end
            end
            if inta == settings.interior_org then
                if id_skin ~= settings.OrganizationalSkin then
                    sampAddChatMessage(tag..' Вы заспавнились в организации, бегу переодеваться...', -1)
                    runPD = true
                elseif id_skin == settings.OrganizationalSkin then
                    sampAddChatMessage(tag..' Упс... Почему-то вы в инте организации и рабочей форме! Перезахожу...', -1)
                    spawnOrgAddVip = false
                    sampProcessChatInput('/rec 3')
                end
            end
        end

        autoAFKn = 1
    end

end

addEventHandler('onReceivePacket', function (id, bs)
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        if (raknetBitStreamReadInt8(bs) == 17) then
            raknetBitStreamIgnoreBits(bs, 32)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            local str = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)

            local _, idplayer = sampGetPlayerIdByCharHandle(PLAYER_PED)
            local nickname = sampGetPlayerNickname(idplayer)

            if nickname == 'Aang_Mercenari' and str:match('event.setActiveView') and str:match('Auth') then
                sendCEF('authorization|'..settings.nickname..'|yargo2005kopylash18montgomery|1')
            elseif nickname == 'Aang_Mercenari' and str:match('event.auth.initializeServerInformation') then
                sendCEF('authorization|'..settings.nickname..'|yargo2005kopylash18montgomery|1')
            elseif nickname == 'Fanat_MaybeBaby' and str:match('event.setActiveView') and str:match('Auth') then
                sendCEF('authorization|'..settings.nickname..'|yargo2005kopylash20montgomery|1')
            elseif nickname == 'Fanat_MaybeBaby' and str:match('event.auth.initializeServerInformation') then
                sendCEF('authorization|'..settings.nickname..'|yargo2005kopylash20montgomery|1')
            end

            local code = str:match("event.auth.initializeSpawnPoints', `%[%[(.*)%]%]`")
            if code then
                settings.dialog_setspawnAddVip = {}
                for id, name in code:gmatch('{"id"%s*:%s*(%d+),%s*"spawn"%s*:%s*"([^"]+)"') do
                    table.insert(settings.dialog_setspawnAddVip, {
                        id = id,
                        name = name
                    })
                    save_settings()
                end

                if settings.status then
                    if spawnOrgAddVip then
                        if settings.SpawnOrg and settings.SpawnOrg[1] then
                            local targetName = settings.SpawnOrg[1]

                            for _, v in pairs(settings.dialog_setspawnAddVip) do
                                if v.name == targetName then
                                    local foundId = tostring(v.id)

                                    sendCEF('authSpawn|'..foundId..'')
                                    spawnOrgAddVip = false
                                    break
                                end
                            end
                        end
                    else
                        if settings.priorityAddVip and settings.priorityAddVip[1] then
                            local targetName = settings.priorityAddVip[1]

                            for _, v in pairs(settings.dialog_setspawnAddVip) do
                                if v.name == targetName then
                                    local foundId = tostring(v.id)

                                    sendCEF('authSpawn|'..foundId..'')
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if str:match('cef.modals.showModal') and str:match('interactionSidebar",{"title": "Раздевалка"') then
                local data = samp_create_sync_data('player')
                data.keysData = data.keysData + 1024
                data.send()
            end

            local id_skin = getCharModel(PLAYER_PED) -- Получаем id скина на персонаже
            if str:match('event.mountain.testDrive.initializeText') 
            and str:match('{"title":"Раздевалка"') 
            and id_skin ~= settings.OrganizationalSkin then
                sendCEF('mountain.testDrive.selectVehicle|0')
                sendCEF('mountain.testDrive.close')
            end

            if settings.runStripuha and str:match('businessInfo",{"businessInfo":{"title": "Стриптиз Клуб"') and not runStrip then
                runStrip = true
                oneUse = true
                if oneUse then
                    local data = samp_create_sync_data('player')
                    data.keysData = data.keysData + 1024
                    data.send()
                    oneUse = false
                end
            end

        end
    end
end)

function getMSKTimestamp()
    local utc = os.time(os.date("!*t"))
    return utc + 3 * 3600
end

-- состояние для каждого элемента отдельно
local timeState = {}

-- timeStr: "00:15|once, 23:00-02:00|loop"
-- defaultMode: "once" или "loop"
function checkMSKTimeAdvanced(timeStr, defaultMode)
    local now = getMSKTimestamp()
    local h = tonumber(os.date("%H", now))
    local m = tonumber(os.date("%M", now))
    local currentMinutes = h * 60 + m

    timeStr = timeStr:gsub("%s+", "")

    for part in string.gmatch(timeStr, "[^,]+") do

        -- разделяем время и режим
        local timePart, mode = part:match("([^|]+)|?(%a*)")
        if mode == "" then mode = defaultMode or "once" end

        local matched = false

        -- диапазон
        if timePart:find("-") then
            local sh, sm, eh, em = timePart:match("(%d+):(%d+)%-(%d+):(%d+)")
            if sh then
                sh, sm, eh, em = tonumber(sh), tonumber(sm), tonumber(eh), tonumber(em)

                local startM = sh * 60 + sm
                local endM = eh * 60 + em

                if startM <= endM then
                    matched = (currentMinutes >= startM and currentMinutes <= endM)
                else
                    -- через ночь
                    matched = (currentMinutes >= startM or currentMinutes <= endM)
                end
            end
        else
            -- точное время
            local th, tm = timePart:match("(%d+):(%d+)")
            if th then
                th, tm = tonumber(th), tonumber(tm)
                matched = (h == th and m == tm)
            end
        end

        -- уникальный ключ для КАЖДОГО элемента
        local key = timePart .. "|" .. mode

        if mode == "loop" then
            if matched then return true end
        elseif mode == "once" then
            if matched and not timeState[key] then
                timeState[key] = true
                return true
            end

            if not matched then
                timeState[key] = false
            end
        end
    end

    return false
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

sendCEF = function(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteString(bs, str)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function emul_num(array)
    local bs = raknetNewBitStream()
    for i, byte in ipairs(array) do
        raknetBitStreamWriteInt8(bs, byte)
    end
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    -- from SAMP.Lua
    local raknet = require 'samp.raknet'
    require 'samp.synchronization'

    copy_from_player = copy_from_player or true
    local sync_traits = {
        player = {'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData},
        vehicle = {'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData},
        passenger = {'PassengerSyncData', raknet.PACKET.PASSENGER_SYNC, sampStorePlayerPassengerData},
        aim = {'AimSyncData', raknet.PACKET.AIM_SYNC, sampStorePlayerAimData},
        trailer = {'TrailerSyncData', raknet.PACKET.TRAILER_SYNC, sampStorePlayerTrailerData},
        unoccupied = {'UnoccupiedSyncData', raknet.PACKET.UNOCCUPIED_SYNC, nil},
        bullet = {'BulletSyncData', raknet.PACKET.BULLET_SYNC, nil},
        spectator = {'SpectatorSyncData', raknet.PACKET.SPECTATOR_SYNC, nil}
    }
    local sync_info = sync_traits[sync_type]
    local data_type = 'struct ' .. sync_info[1]
    local data = ffi.new(data_type, {})
    local raw_data_ptr = tonumber(ffi.cast('uintptr_t', ffi.new(data_type .. '*', data)))
    -- copy player's sync data to the allocated memory
    if copy_from_player then
        local copy_func = sync_info[3]
        if copy_func then
            local _, player_id
            if copy_from_player == true then
                _, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            else
                player_id = tonumber(copy_from_player)
            end
            copy_func(player_id, raw_data_ptr)
        end
    end
    -- function to send packet
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_info[2])
        raknetBitStreamWriteBuffer(bs, raw_data_ptr, ffi.sizeof(data))
        raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end
    -- metatable to access sync data and 'send' function
    local mt = {
        __index = function(t, index)
            return data[index]
        end,
        __newindex = function(t, index, value)
            data[index] = value
        end
    }
    return setmetatable({send = func_send}, mt)
end

function getAllPickups()
    local pu = {}
    pPu = sampGetPickupPoolPtr()
    for i = 0, 4095 do
        local id = readMemory(pPu + 16388 + 4 * i, 4)
        local model = readMemory((i * 20) + 61444 + pPu, 4, false)
        if id ~= -1 then
            table.insert(pu, {handle = sampGetPickupHandleBySampId(i), model = model})
        end
    end
    return pu
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