local script = {}
local heroes = {}
local ui = {}
local fixedNames = {
    ['outworlddevoure'] = "outworlddestroyer",
    ['beastmaste'] = "primalbeast",
}

local colors = {
    ["S"] = {124, 58, 237, 255},
    ["A"] = {2, 132, 199, 255},
    ["B"] = {5, 150, 105, 255},
    ["C"] = {217, 119, 6, 255},
    ["D"] = {225, 29, 72, 255},
    ["RED"] = {255, 0, 0, 255},
    ["GREEN"] = {0, 255, 0, 255},
    ["GRAY"] = {128, 128, 128, 255},
}

local data = {}
local loaded = false
local loadedHeroes = false

local defaultFont = Renderer.LoadFont("FontAwesomeEx", 8, Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)

local JSON = require('assets.JSON');

local tab = Menu.Create("Miscellaneous", "Other", "DOTABUFF")
tab:Icon("\u{e473}")

local group = tab:Create("Main"):Create("DOTABUFF")
ui.switchEnable = group:Switch("Enable", false, "\u{f00c}")
ui.switchWinRate = group:Switch("Win rate", true, "\u{f00c}")
ui.switchWinRateChange= group:Switch("Win rate change", true, "\u{f00c}")
ui.switchTier= group:Switch("Tier", true, "\u{f00c}")

ui.categories = group:MultiCombo("Categories", {"S", "A", "B", "C", "D"}, {"S", "A", "B", "C", "D"})

ui.switchEnable:SetCallback(function ()

    ui.switchWinRate:Disabled(not ui.switchEnable:Get())
    ui.switchWinRateChange:Disabled(not ui.switchEnable:Get())
    ui.switchTier:Disabled(not ui.switchEnable:Get())
    ui.categories:Disabled(not ui.switchEnable:Get())

end, true)

ui.categories:SetCallback(function ()

    loadedHeroes = false

end, true)

ui.drawWinRate = function(bounds, win_rate)

    if not bounds or not win_rate then
        return
    end

    local color = colors.GREEN
    if win_rate < 50 then
        color = colors.RED
    elseif win_rate == 50 then
        color = colors.GRAY
    end

    local text = string.format("%s%%", win_rate)
    local fontSize, textSize = Renderer.GetTextSize(defaultFont, text)

    local x, y, w, h = bounds.x + 3, bounds.y + 3, fontSize + 6, textSize + 6

    Renderer.SetDrawColor(0, 0, 0, 200)
    Renderer.DrawFilledRoundedRect(x, y, w, h, 5)

    Renderer.SetDrawColor(color[1], color[2], color[3], color[4])
    Renderer.DrawText(defaultFont, x + 3, y + 3, text)
end

ui.drawWinRateChange = function(bounds, win_rate_change)

    if not bounds or not win_rate_change then
        return
    end

    local color = win_rate_change > 0 and colors.GREEN or colors.RED

    local text = string.format("%s", win_rate_change)
    local fontSize, textSize = Renderer.GetTextSize(defaultFont, text)

    local x, y, w, h = bounds.x + bounds.w / 2 - fontSize / 2, bounds.y + bounds.h - textSize - 9, fontSize + 6, textSize + 6

    Renderer.SetDrawColor(0, 0, 0, 200)
    Renderer.DrawFilledRoundedRect(x, y, w, h, 5)

    Renderer.SetDrawColor(color[1], color[2], color[3], color[4])
    Renderer.DrawText(defaultFont, x + 3, y + 3, text)
end

ui.drawTier = function(bounds, tier)

    if not bounds or not tier or not colors[tier] then
        return
    end

    local r, g, b, a = colors[tier][1], colors[tier][2], colors[tier][3], colors[tier][4]
    local text = tier
    local fontSize, textSize = Renderer.GetTextSize(defaultFont, text)

    local x, y, w, h = bounds.x + 3, bounds.y + (bounds.h / 2), fontSize + 6, textSize + 6

    Renderer.SetDrawColor(r, g, b, a)
    Renderer.DrawFilledRoundedRect(x, y, w, h, 3)

    Renderer.SetDrawColor(255, 255, 255, 255)
    Renderer.DrawText(defaultFont, x + 3, y + 3, text)
end

local getHeroName = function(src_image)
    local no_suffix = string.sub(src_image, 1, string.find(src_image, ".png") - 1)
	local hero_img_name = string.sub(no_suffix, string.find(no_suffix, "/selection/") + 11)
    local hero_name = Engine.GetDisplayNameByUnitName( hero_img_name )
	return hero_name
end

local checkCategory = function(hero)
    local selectedCategories = ui.categories:ListEnabled()
    for _, value in pairs(selectedCategories) do
        if value == hero.tier then
            return hero
        end
    end

    return false
end

local getHeroData = function(hero_name)
    local hero_name = string.lower(hero_name):gsub(" ", "")

    if heroes[hero_name] then
        return checkCategory(heroes[hero_name])
    end

    for name, heroName in pairs(fixedNames) do
        if hero_name:find(name) then
            return checkCategory(heroes[heroName])
        end
    end


    return false
end

local formatString = function(str)
    local formats = {"&#x27", "&amp;", "&quot;", "&#x2F;", "&#x60;", "&lt;", "&gt;", " "}
    for i = 1, #formats do
        str = str:gsub(formats[i], "")
    end
    return string.lower(str):gsub(";", "'")
end

local extractData = function(html)
    heroes = {}
    
    for hero_name, tier, win_rate, win_rate_change, pick_rate, pick_rate_change, ban_rate in html:gmatch('<div class="tw%-flex tw%-flex%-col tw%-items%-start tw%-gap%-1">.-<div>(.-)</div>.-<div class="tw%-rounded.-">(.-)</div>.-<span>(.-)%%</span>.-<span>(.-)%%</span>.-<span>(.-)%%</span>.-<span>(.-)%%</span>.-<span>(.-)%%</span>') do
        local hero_name = formatString(hero_name)
        heroes[hero_name] = {
            name = hero_name,
            tier = tier,
            win_rate = win_rate:gsub("<!--.-?-->", ""),
            win_rate_change = win_rate_change:gsub("<!--.-?-->", ""),
            pick_rate = pick_rate:gsub("<!--.-?-->", ""),
            pick_rate_change = pick_rate_change:gsub("<!--.-?-->", ""),
            ban_rate = ban_rate:gsub("<!--.-?-->", "")
        }
        table.insert(heroes, hero)
    end

    -- Log.Write("Loaded heroes data")

    loaded = true

    return heroes
end

local HTTPCallback = function(response)
    local html = response["response"]
    local heroes = extractData(html)

    
end

local HTTPRequest = function()

    local url = 'https://www.dotabuff.com/heroes?show=heroes&view=meta&mode=all-pick&date=7d'
    HTTP.Request("GET", url, nil, HTTPCallback, "reqres_get")

end

script.OnScriptsLoaded = function()
    HTTPRequest()
end

script.OnFrame = function(bounds, hero_data)

    if not ui_state then return end

    for index, value in pairs(data) do
        local bounds = value.bounds
        local hero_data = value.hero_data

        if ui.switchWinRate:Get() then
            ui.drawWinRate(bounds, math.floor(tonumber(hero_data.win_rate)))
        end
        if ui.switchTier:Get() then
            ui.drawTier(bounds, hero_data.tier)
        end
        if ui.switchWinRateChange:Get() then
            ui.drawWinRateChange(bounds, tonumber(hero_data.win_rate_change))
        end

    end

end

script.OnUpdateEx = function()

    if not ui.switchEnable:Get() then
        ui_state = false
        return
    end
    
    local heroes_page = Panorama.GetPanelByName("HeroPickLeftColumn", false)

    if not heroes_page then 
        ui_state = false 
        return 
    end

    local pregame_bg = Panorama.GetPanelByName("PregameBG", false)

    if not pregame_bg:HasClass("SceneLoaded") then
        ui_state = false
        return
    end

    local pregame = Panorama.GetPanelByName("PreGame", false)

    if pregame:HasClass("StrategyVisible") then
        ui_state = false
        return
    end

    -- Test Mode
    -- local heroes_page = Panorama.GetPanelByName("DOTAHeroesPage", false)
    -- if not heroes_page then ui_state = false return end

    -- if not heroes_page:HasClass("PageVisible") then
    --     ui_state = false
    --     return
    -- end

    local grid = heroes_page:GetChildByPath({"HeroGrid", "MainContents", "GridCategories"}, false);
    if not grid then ui_state = false return end

    ui_state = true

    if loadedHeroes then
        return
    end

    data = {}

    for i = 0, grid:GetChildCount() - 1 do
        local hero_category = grid:GetChild(i)
        if not hero_category then
            goto continue
        end
        local hero_list_container = hero_category:GetLastChild();
        if not hero_list_container then
            goto continue
        end
        local hero_list = hero_list_container:GetChild(0);
        if not hero_list then
            goto continue
        end
        if not loaded then
            goto continue
        end
        for i = 0, hero_list:GetChildCount() - 1 do
            local hero = hero_list:GetChild(i)
            if hero then
                local bounds = hero:GetBounds()
                if bounds then
                    local hero_image_path = hero:GetChild(0):GetChild(0);
                    local hero_name = getHeroName(hero_image_path:GetImageSrc())
                    if hero_name then
                        local hero_data = getHeroData(hero_name)
                        if hero_data then
                            data[hero_name] = {
                                bounds = bounds,
                                hero_data = hero_data
                            }
                        end
                    end
                end
            end
        end
        if i == grid:GetChildCount() - 1 then
            loadedHeroes = true
        end
        ::continue::
    end

end

return script
