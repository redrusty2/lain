
--[[
                                                  
     Licensed under GNU General Public License v2 
      * (c) 2013,      Luke Bonham                
      * (c) 2010-2012, Peter Hofmann              
                                                  
--]]

local newtimer     = require("lain.helpers").newtimer
local first_line   = require("lain.helpers").first_line

local naughty      = require("naughty")
local wibox        = require("wibox")

local math         = { floor  = math.floor }
local string       = { format = string.format }
local tonumber     = tonumber

local setmetatable = setmetatable

-- Battery infos
-- lain.widgets.bat

local function worker(args)
    local bat      = {}
    local args     = args or {}
    local timeout  = args.timeout or 30
    local battery  = args.battery or "BAT0"
    local ac       = args.ac or "AC0"
    local notify   = args.notify or "on"
    local settings = args.settings or function() end

    bat.widget = wibox.widget.textbox('')

    bat_notification_low_preset = {
        title = "Battery low",
        text = "Plug the cable!",
        timeout = 15,
        fg = "#202020",
        bg = "#CDCDCD"
    }

    bat_notification_critical_preset = {
        title = "Battery exhausted",
        text = "Shutdown imminent",
        timeout = 15,
        fg = "#000000",
        bg = "#FFFFFF"
    }

    function update()
        bat_now = {
            status    = "Not present",
            ac_status = "N/A",
            perc      = "N/A",
            time      = "N/A",
            watt      = "N/A"
        }

        local bstr    = "/sys/class/power_supply/" .. battery
        local present = first_line(bstr .. "/present")

        if present == "1"
        then
            local ratep    = tonumber(first_line(bstr .. "/power_now"))
            local ratec    = tonumber(first_line(bstr .. "/current_now"))
            local ratev    = tonumber(first_line(bstr .. "/voltage_now"))

            local rem      = tonumber(first_line(bstr .. "/energy_now") or
                                      first_line(bstr .. "/charge_now"))

            local tot      = tonumber(first_line(bstr .. "/energy_full") or
                                      first_line(bstr .. "/charge_full"))

            bat_now.status = first_line(bstr .. "/status") or "N/A"
            bat_now.ac     = first_line(string.format("/sys/class/power_supply/%s/online", ac)) or "N/A"

            local time_rat = 0
            if bat_now.status == "Charging"
            then
                time_rat = (tot - rem) / (ratep or ratec)
            elseif bat_now.status == "Discharging"
            then
                time_rat = rem / (ratep or ratec)
            end

            local hrs = math.floor(time_rat)
            if hrs < 0 then hrs = 0 elseif hrs > 23 then hrs = 23 end

            local min = math.floor((time_rat - hrs) * 60)
            if min < 0 then min = 0 elseif min > 59 then min = 59 end

            bat_now.time = string.format("%02d:%02d", hrs, min)

            local perc = tonumber(first_line(bstr .. "/capacity")) or math.floor((rem / tot) * 100)

            if perc <= 100 then
                bat_now.perc = string.format("%d", perc)
            elseif perc > 100 then
                bat_now.perc = "100"
            elseif perc < 0 then
                bat_now.perc = "0"
            end

            if ratep then
                bat_now.watt = string.format("%.2fW", ratep)
            else
                bat_now.watt = string.format("%.2fW", (ratev * ratec) / 1e12)
            end
        end

        widget = bat.widget
        settings()

        -- notifications for low and critical states
        if bat_now.status == "Discharging" and notify == "on" and bat_now.perc
        then
            local nperc = tonumber(bat_now.perc) or 100
            if nperc <= 5
            then
                bat.id = naughty.notify({
                    preset = bat_notification_critical_preset,
                    replaces_id = bat.id,
                }).id
            elseif nperc <= 15
            then
                bat.id = naughty.notify({
                    preset = bat_notification_low_preset,
                    replaces_id = bat.id,
                }).id
            end
        end
    end

    newtimer(battery, timeout, update)

    return setmetatable(bat, { __index = bat.widget })
end

return setmetatable({}, { __call = function(_, ...) return worker(...) end })
