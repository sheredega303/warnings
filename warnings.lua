script_name("WARNINGS")
script_author("sheredega")

require "lib.moonloader"
local inicfg = require('inicfg')
local sampev = require 'lib.samp.events'
local imgui = require('imgui')
local keys = require "vkeys"
local encoding = require 'encoding'
local requests = require('requests')
local distatus = require('moonloader').download_status
encoding.default = 'CP1251'
u8 = encoding.UTF8

local menu = imgui.ImBool(false)
local fastExit = imgui.ImBool(true)
local carSbiv = imgui.ImBool(true)
local heavyFist = imgui.ImBool(true)
local sniperRifle = imgui.ImBool(true)
local vertMafia = imgui.ImBool(true)
local fast_re = VK_3
local fast_reoff = VK_Q

local t = {} -- Время анимации выхода из машины (CarSbiv)
local mobile = {} -- Отлавливать игроков с телефона для игнора

local ls = {} -- Тайминг последнего выстрела (HeavyFist)
local lAnim = {} -- Последняя анимация (HeavyFist)
local lFlag = {} -- Последний флаг (HeavyFist)
local lKeys = {} -- Последнее нажатие клавиш (HeavyFist)
local skinAnim = {} -- Trigger animation для определенного скина (HeavyFist)

local wcd = {} -- Тайминг для некст варнинга
local inCar = {} -- Находится в машине
local carExit = {} -- Начал выходить из машины (исключаем ошибочные отправки пакетов)

local lw = nil -- Последний варнинг для перехода по кнопке
local autore = false -- Авторекон вкл-выкл
local recon = false -- Нахожусь в реконе или нет
local vertolet = false -- Отлавливать верт после двух или нет (по чатлогу)

local authorization = false -- Проверка, авторизован или нет
local aproved = false -- Полный доступ к функционалу

update_state = false
local script_vers = 2

local script_path = thisScript().path
local script_url = 'https://github.com/sheredega303/warnings/blob/main/warnings.luac?raw=true' -- Ссылка на файл

local update_path = getWorkingDirectory() .. "/vers.ini"
local update_url = "https://raw.githubusercontent.com/sheredega303/warnings/main/vers.ini" -- Ссылка на проверку версии

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end
	loadINI()

	downloadUrlToFile(update_url, update_path, function(id, status)
        if status == distatus.STATUS_ENDDOWNLOADDATA then
            updateIni = inicfg.load(nil, update_path)
            if tonumber(updateIni.info.vers) > script_vers then
				sampAddChatMessage("{049c02}[WARINGS]" .. "{ffffff} появилась новая версия, начинается автообновление", 0xffffff)
                update_state = true
            end
            os.remove(update_path)
        end
    end)

	sampAddChatMessage("{049c02}[WARINGS]" .. "{ffffff} beta version loaded " .. "{049c02}(/warnset)".."{ffffff}. Author: " .. "{049c02}sheredega", 0xffffff)
	sampRegisterChatCommand("autore", auto)
	sampRegisterChatCommand('warnset', function() menu.v = not menu.v end)
	
	while true do
		wait(0)

		if update_state then
            downloadUrlToFile(script_url, script_path, function(id, status)
                if status == distatus.STATUS_ENDDOWNLOADDATA then
					sampAddChatMessage("{049c02}[WARINGS]" .. "{ffffff} обновление установлено", 0xffffff)
                    thisScripit():reload()
                end
            end)
            break
        end

		imgui.Process = menu.v
		
		if isKeyJustPressed(fast_re) and not isPauseMenuActive() and isPlayerPlaying(PLAYER_HANDLE) and not sampIsChatInputActive() and not sampIsDialogActive() and lw then
			sampSendChat("/re "..lw)
		end 
		
		if isKeyJustPressed(fast_reoff) and not isPauseMenuActive() and isPlayerPlaying(PLAYER_HANDLE) and not sampIsChatInputActive() and not sampIsDialogActive() and recon then
			sampSendChat("/re off")
		end 
	end
end

-- Авторекон на последний варнинг для CarExitAnimSbiv
function auto()
	if autore then
		sampAddChatMessage("{049c02}[AUTORECON]" .. "{ffffff} Авторекон " .. "{B22222}выключен", -1)
		autore = false
	else
		sampAddChatMessage("{049c02}[AUTORECON]" .. "{ffffff} Авторекон " .. "{008000}включен", -1)
		autore = true
	end
end

-- Отлавливаем для FastExit и CarExitAnimSbiv
function sampev.onPlayerExitVehicle(playerid, vehicleid)
	-- FastExit
	if fastExit.v then
		if inCar[playerid] then -- Если игрок записан как находящийся в машине
			inCar[playerid] = nil -- Очищаем
			carExit[playerid] = os.time() + 1
		end	
	end

	-- CarExitAnimSbiv
	if carSbiv.v then
		result, car = sampGetCarHandleBySampVehicleId(vehicleid) -- Получаем ПЕД транспорта
		if result then -- Если получили
			modelId = getCarModel(car)
			speed = getCarSpeed(car)
			
			if speed > 5 then -- Если машина не стоит
				if (modelId == 448) or (modelId >= 461 and modelId <= 463) or (modelId == 468) or (modelId == 471) or (modelId == 481) or (modelId == 509) or (modelId == 510)
				or (modelId >= 521 and modelId <= 523) or (modelId == 581) or (modelId == 586) then -- Мотоциклы
					t[playerid] = os.time() + 1.1
				elseif (modelId == 447) or (modelId == 469) or (modelId == 487) or (modelId == 488) or (modelId == 497) or (modelId == 520) or (modelId == 519) or (modelId == 539) then -- Воздушный транспорт
					-- nothing
				else -- остальной транспорт
					t[playerid] = os.time() + 2.8
				end
			end
		else
			-- nothing
		end
	end
	
end

function sampev.onPlayerSync(id, data)
	if heavyFist.v and aproved then
		if ls[id] and ls[id] >= os.time() then
			if data.health > 0 then
				-- Если первая запись
				if not lAnim[id] then
					lAnim[id] = data.animationId
					lFlag[id] = data.animationFlags
					lKeys[id] = data.keysData
				-- 1335 - Перезарядка
				-- 1462 -- Usedrugs
				-- 1205 1206 1001 1084 1240 1243 1241 1178 1173 1177 1175 1242
				-- Если прошлая анимация была разгоночной, а сейчас вылетела анимация быстрого бега - очищаем до следующего выстрела
				elseif (lAnim[id] == 1276 or lAnim[id] == 1228 or lAnim[id] == 1224 or lAnim[id] == 1277 or lAnim[id] == 1280 or lAnim[id] == 1247 or lAnim[id] == 1279 or lAnim[id] == 1335 or lAnim[id] == 1462
				or lAnim[id] == 1205 or lAnim[id] == 1206 or lAnim[id] == 1001 or lAnim[id] == 1084 or lAnim[id] == 1240 or lAnim[id] == 1243 or lAnim[id] == 1241 or lAnim[id] ==  1178 or lAnim[id] == 1173 or lAnim[id] == 1177
				or lAnim[id] == 1175 or lAnim[id] == 1242 or lAnim[id] == nil) -- Анимации которые могут нарушить синхру
				and (skinAnim[id] == data.animationId) then -- Анимация быстрого бега соответствующая скину
					ls[id] = nil
					lAnim[id] = nil
					lFlag[id] = nil
					lKeys[id] = nil
				else
					-- Если прошлая не была разгоночной, перешли в 3ю анимацию с нужным флагом и без зажатого пробела - варнинг
					-- Без проверки на флаг 100% летят ложные, флаг оставлять
					if (skinAnim[id] == data.animationId) and (data.animationFlags == 32770) and (data.keysData < 8 and lKeys[id] < 8) then
						color = string.format('%06X', bit.band(sampGetPlayerColor(id), 0xFFFFFF))
						sampAddChatMessage("{049c02}[WARNING] " .."{" .. color .. "}" .. sampGetPlayerNickname(id) .. "[" .. id .. "]".. "{ffffff} возможно использует HeavyFist/MovementFix", 0xffffff)
						lw = id
						ls[id] = nil
						lAnim[id] = nil
						lFlag[id] = nil
						lKeys[id] = nil
					else
						lAnim[id] = data.animationId
						lFlag[id] = data.animationFlags
						lKeys[id] = data.keysData
					end
				end
			else
				ls[id] = nil
				lAnim[id] = nil
				lFlag[id] = nil
				lKeys[id] = nil
			end
		end
	end

	if fastExit.v then
		if inCar[id] and not mobile[id] then -- Варнинг на выход софтом (ошибочный при насильном выходе из кара)
			result, ped = sampGetCharHandleBySampPlayerId(id)
			if result then
				if not isCharInArea2d(ped, 1650.2545, -866.4215, 2927.3142, -2175.3066, false) then
					color = string.format('%06X', bit.band(sampGetPlayerColor(id), 0xFFFFFF))	
					sampAddChatMessage("{049c02}[WARNING] " .."{" .. color .. "}" .. sampGetPlayerNickname(id) .. "[" .. id .. "]".. "{ffffff} возможно FastExit", 0xffffff)
					lw = id
				end
			end
			inCar[id] = nil
			carExit[id] = nil
		end
	end
	
	
	if carSbiv.v then
		if t[id] and not mobile[id] then -- Если вышел из машины и не матарик
			if t[id] <= os.time() then -- И время анимации окончено - очищаем
				t[id] = nil	
			else
				local animId, animFlag = data.animationId, data.animationFlags
				if animId and animFlag then -- Проверяем, отловили ли ИД и ФЛАГ
					if (animId ~= 1189 and animFlag ~= 33000) and (animId ~= 1156 and animFlag ~= 33000) then -- Если не соответствуют анимации выхода из машины
						if (animId == 1132 and animFlag == 32772) or (animId == 1130 and animFlag == 32772) then -- Если это анимация падения - очищаем
							t[id] = nil
						else -- Варнинг на сбив анимации выхода из машины
							result, ped = sampGetCharHandleBySampPlayerId(id)
							if result then
								if not isCharInArea2d(ped, 1650.2545, -866.4215, 2927.3142, -2175.3066, false) then
									color = string.format('%06X', bit.band(sampGetPlayerColor(id), 0xFFFFFF))	
									sampAddChatMessage("{049c02}[WARNING] " .."{" .. color .. "}" .. sampGetPlayerNickname(id) .. "[" .. id .. "]".. "{ffffff} возможно CarExitSbiv", 0xffffff)
									lw = id -- Записываем последний варнинг для рекона по кнопке
									if autore and not recon then -- Если авторекон включен и ты не в реконе
										lua_thread.create(function()
											wait(50)
											sampSendChat("/re "..lw) -- Сразу уходим в рекон за игроком
										end)
									end
								end
							end

							t[id] = nil
						end
					end
				end
			end
		end
	end
end

function sampev.onBulletSync(id, data)

	if sniperRifle.v then
		-- Варнинги на снайперку в мафии
		if data.weaponId == 34 then
			if sampGetPlayerColor(id) == 2868838400 or sampGetPlayerColor(id) == 4292716289 or sampGetPlayerColor(id) == 4290033079 then
				color = string.format('%06X', bit.band(sampGetPlayerColor(id), 0xFFFFFF))
				if data.targetType == 1 then
					colorTarget = string.format('%06X', bit.band(sampGetPlayerColor(data.targetId), 0xFFFFFF))
					sampAddChatMessage("{049c02}[WARNING] ".."{" .. color .. "}"..sampGetPlayerNickname(id).."[".. id.."]".."{ffffff} выстрелил в {" .. colorTarget .. "}" .. sampGetPlayerNickname(data.targetId) .. "[" .. data.targetId .. "]".. "{ffffff} используя SniperRifle", -1)
				else
					sampAddChatMessage("{049c02}[WARNING] ".."{" .. color .. "}"..sampGetPlayerNickname(id).."[".. id.."]".."{ffffff} выстрелил используя SniperRifle", -1)
				end
				lw = id
			end
		end
	end
	
	if heavyFist.v and aproved then
		if data.weaponId == 24 then 

			result, ped = sampGetCharHandleBySampPlayerId(id) -- Получаем ПЕД игрока сделавшего выстрел с дигла
			if result then
				ls[id] = os.time() + 1
				skin = getCharModel(ped) -- Получаем скин игрока для исключение неизвестного бага
				
				if skin == 56 or skin == 195 or skin == 41 or skin == 226 or skin == 214 or skin == 216 or skin == 263 or skin == 201 then
					-- 1283 - Women skin
					skinAnim[id] = 1283
				elseif skin == 105 or skin == 107 or skin == 103 or skin == 109 or skin == 174 or skin == 115 then
					-- 1264 - Crime skin type 2
					skinAnim[id] = 1264
				elseif skin == 106 or skin == 102 or skin == 104 or skin == 21 or skin == 108 or skin == 110 or skin == 175 or skin == 173 or skin == 114 or skin == 116 or skin == 123 or skin == 124 then
					-- 1263 - Crime skin type 1
					skinAnim[id] = 1263
				elseif skin == 190 then
					-- 1281 - Women skin
					skinAnim[id] = 1281
				elseif skin == 91 or skin == 12 or skin == 246 then
					-- 1286 - Women skin
					skinAnim[id] = 1286
				elseif skin == 85 or skin == 64 then
					-- 1285 - Women skin
					skinAnim[id] = 1285
				else
					-- Все остальные скины
					skinAnim[id] = 1257
				end
			else
				-- nothing
			end
		end
	end
end


function sampev.onTogglePlayerSpectating(bool) -- Проверка в реконе или нет
	recon = bool
end

function sampev.onServerMessage(color, text)
	if vertMafia.v then
		if string.find(text, "У вас есть 2 минуты, чтобы решить") and string.find(text, "чей будет бизнес:") then
			vertolet = true
		end
		if string.find(text, "Война за бизнес окончена.") then
			vertolet = false
		end
	end
end

function sampev.onVehicleSync(id, vehicleid, data) -- Если игрок находится в машине

	if vertMafia.v and vertolet then	
		local _, car = sampGetCarHandleBySampVehicleId(vehicleid)
		if car then
			modelId = getCarModel(car)
			if (modelId == 447) or (modelId == 469) or (modelId == 487) or (modelId == 488) or (modelId == 497) or (modelId == 520) or (modelId == 519) or (modelId == 539) then
				if not wcd[id] then
					color = string.format('%06X', bit.band(sampGetPlayerColor(id), 0xFFFFFF))
					sampAddChatMessage("{049c02}[WARNING] " .."{" .. color .. "}" .. sampGetPlayerNickname(id) .. "[" .. id .. "]".. "{ffffff} использует вертолет после двух {049c02}[Пилот]", 0xffffff)
					lw = id
					wcd[id] = os.time() + 3
				elseif wcd[id] < os.time() then
					sampAddChatMessage("{049c02}[WARNING] " .."{" .. color .. "}" .. sampGetPlayerNickname(id) .. "[" .. id .. "]".. "{ffffff} использует вертолет после двух {049c02}[Пилот]", 0xffffff)
					lw = id
					wcd[id] = os.time() + 3
				end
			end
		else
			-- nothing
		end
	end

	if fastExit.v then
		if not inCar[id] then -- Если игрок не записан
			if carExit[id] then -- Исключаем ошибочные варнинги
				if carExit[id] < os.time() then -- Исключаем ошибочные варнинги
					inCar[id] = true
				end
			else
				inCar[id] = true
			end
		end
	end
end

function sampev.onPassengerSync(id, data) -- Если игрок находится в машине
	if fastExit.v then
		if not inCar[id] then -- Если игрок не записан
			if carExit[id] then -- Исключаем ошибочные варнинги
				if carExit[id] < os.time() then -- Исключаем ошибочные варнинги
					inCar[id] = true
				end
			else
				inCar[id] = true
			end
		end
	end
end

function sampev.onPlayerStreamOut(id) -- Если игрок вышел из стрима
	if fastExit.v then
		if inCar[id] then -- Если он записан как находящийся в машине
			inCar[id] = nil -- Очищаем переменную
		end
	end

	if fastExit.v or carSbiv.v then
		if mobile[id] then -- Если записан как мобильный игрок
			mobile[id] = nil -- Очищаем переменную
		end
	end
end

function sampev.onCreate3DText(id, color, position, distance, testLOS, attachedPlayerId, attachedVehicleId, text) -- Поиск матариков
	if fastExit.v or carSbiv.v then
		if text:find("%[{ae433d}M{FFFFFF}%]") then -- [M]
			if attachedPlayerId then
				mobile[attachedPlayerId] = true
			end
		end
	end
end

function imgui.OnDrawFrame()
    if menu.v then
		imgui.SetNextWindowPos(imgui.ImVec2(350.0, 250.0), imgui.Cond.FirstUseEver)
		if aproved then
			imgui.SetNextWindowSize(imgui.ImVec2(300.0, 255.0), imgui.Cond.FirstUseEver)
		else
			imgui.SetNextWindowSize(imgui.ImVec2(300.0, 235.0), imgui.Cond.FirstUseEver)
		end
        imgui.Begin('Warnings by sheredega', menu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)

        imgui.Checkbox('FastExit', fastExit)
        imgui.Checkbox('CarExitAnimSbiv', carSbiv)
		if aproved then
			imgui.Checkbox('HeavyFist/MovementFix', heavyFist)
		end
		imgui.Checkbox(u8"SniperRifle в мафии", sniperRifle)
		imgui.Checkbox(u8"Вертолет после 2х в мафии", vertMafia)

		if imgui.Button('Save Settings', imgui.ImVec2(-1, -1)) then 
			saveINI()
			sampAddChatMessage("{049c02}[WARNING]".."{ffffff} Настройки успешно обновлены", 0xffffff)
		end

        imgui.End()
    end
end

function saveINI()
    inicfg.save({
        sets = {
			fastExit = fastExit.v,
			carSbiv = carSbiv.v,
			heavyFist = heavyFist.v,
			sniperRifle = sniperRifle.v,
			vertMafia = vertMafia.v
        },
		keys = {
			fast_re = fast_re,
			fast_reoff = fast_reoff
		}
    }, 'warningsetting')
end

function loadINI()
    local ini = inicfg.load(nil, 'warningsetting')
    if ini == nil then
        saveINI()
    else
		fastExit.v = ini.sets.fastExit
        carSbiv.v = ini.sets.carSbiv
		heavyFist.v = ini.sets.heavyFist
		sniperRifle.v = ini.sets.sniperRifle
		vertMafia.v = ini.sets.vertMafia
		fast_re = ini.keys.fast_re
		fast_reoff = ini.keys.fast_reoff
    end
end

function apply_custom_style()
    imgui.SwitchContext()
    style = imgui.GetStyle()
    colors = style.Colors
    clr = imgui.Col
    ImVec4 = imgui.ImVec4
    ImVec2 = imgui.ImVec2
 
     style.WindowPadding = ImVec2(15, 15)
     style.WindowRounding = 15.0
     style.FramePadding = ImVec2(5, 5)
     style.ItemSpacing = ImVec2(12, 8)
     style.ItemInnerSpacing = ImVec2(8, 6)
     style.IndentSpacing = 25.0
     style.ScrollbarSize = 15.0
     style.ScrollbarRounding = 15.0
     style.GrabMinSize = 15.0
     style.GrabRounding = 7.0
     style.ChildWindowRounding = 8.0
     style.FrameRounding = 6.0
     style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
     
  
       colors[clr.Text] = ImVec4(0.95, 0.96, 0.98, 1.00)
       colors[clr.TextDisabled] = ImVec4(0.36, 0.42, 0.47, 1.00)
       colors[clr.WindowBg] = ImVec4(0.11, 0.15, 0.17, 1.00)
       colors[clr.ChildWindowBg] = ImVec4(0.15, 0.18, 0.22, 1.00)
       colors[clr.PopupBg] = ImVec4(0.08, 0.08, 0.08, 0.94)
       colors[clr.Border] = ImVec4(1, 1, 1, 0.5)
       colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
       colors[clr.FrameBg] = ImVec4(0.20, 0.25, 0.29, 1.00)
       colors[clr.FrameBgHovered] = ImVec4(0.12, 0.20, 0.28, 1.00)
       colors[clr.FrameBgActive] = ImVec4(0.09, 0.12, 0.14, 1.00)
       colors[clr.TitleBg] = ImVec4(0.09, 0.12, 0.14, 0.65)
       colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)
       colors[clr.TitleBgActive] = ImVec4(0.08, 0.10, 0.12, 1.00)
       colors[clr.ScrollbarBg] = ImVec4(0.02, 0.02, 0.02, 0.39)
       colors[clr.ScrollbarGrab] = ImVec4(0.20, 0.25, 0.29, 1.00)
       colors[clr.ScrollbarGrabHovered] = ImVec4(0.18, 0.22, 0.25, 1.00)
       colors[clr.ScrollbarGrabActive] = ImVec4(0.09, 0.21, 0.31, 1.00)
       colors[clr.Button] = ImVec4(0.20, 0.25, 0.29, 1.00)
       colors[clr.ButtonHovered] = ImVec4(0.52, 0.2, 0.92, 1.00)
       colors[clr.ButtonActive] = ImVec4(0.60, 0.2, 1.00, 1.00)
       colors[clr.ComboBg] = ImVec4(0.20, 0.20, 0.20, 0.70)
       colors[clr.CheckMark] = ImVec4(0.52, 0.2, 0.92, 1.00)
       colors[clr.SliderGrab] = ImVec4(0.52, 0.2, 0.92, 1.00)
       colors[clr.SliderGrabActive] = ImVec4(0.60, 0.2, 1.00, 1.00)
       colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
       colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
       colors[clr.ResizeGripActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
       colors[clr.CloseButton] = ImVec4(0.40, 0.39, 0.38, 0.16)
       colors[clr.CloseButtonHovered] = ImVec4(0.40, 0.39, 0.38, 0.39)
       colors[clr.CloseButtonActive] = ImVec4(0.40, 0.39, 0.38, 1.00)
 end
apply_custom_style()

-- Проверка привязки при условии авторизации
function sampev.onSendPlayerSync()
	if not authorization then
		authorization = true
		check_aprove()
	end
end

function check_aprove()
	local request = requests.get('https://raw.githubusercontent.com/sheredega303/warnings/main/approved.txt') -- получаем ссылку
	local nick = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) -- получаем свой ник
	local function res()
		for n in request.text:gmatch('[^\r\n]+') do -- получаем список ников из ссылки
			if nick:find(n) then
				sampAddChatMessage("{049c02}[WARINGS]" .. "{ffffff} Доступ к полному функционалу предоставлен", 0xffffff)
				aproved = true
				return true 
			end  -- если находит ник то все гуд и скрипт работает дальше
		end
		return false
	end
	if not res() then 
		aproved = false
	end
end

-- От махинаций с никами защита
function sampev.onConnectionAttemptFailed()
	aproved = false
	authorization = false
end

-- От махинаций с никами защита
function sampev.onConnectionRequestAccepted()
	aproved = false
	authorization = false
end