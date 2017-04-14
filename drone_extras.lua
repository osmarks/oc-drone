local owner_name = "gollark" -- Default username, can be reset by owner
local drone_name = "QT-8"
local status = drone.setStatusText

if key_exists "name" then
  drone_name = read_key "name"
end

chat.setName(drone_name)
chat.setDistance(1000)

if key_exists "owner" then
  owner_name = read_key "owner"
end

local command_prefix = drone_name .. ","

local function split(inputstr, sep)
  local parts = {}
  for str in str.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(parts, str)
  end
  return parts
end

isfollow = true

local commands = {
  go = function(x, y, z)
    drone.move(num(x), num(y), num(z))
  end,
  locate = function(range)
     x, y, z = nav.getPosition()

    if x and y and z then
      speak("I'm at relative position " .. x .. ", " .. y .. ", " .. z .. ".")
    else
      speak "Unable to locate."
    end

    speak "Waypoints: "
    for waypoint in nav.findWaypoints(num(range) or 1000) do
      speak("Waypoint name: " .. waypoint["label"])
      speak("X: " .. waypoint["position"][1] .. ".")
      speak("Y:" .. waypoint["position"][2] .. ".")
      speak("Z: " .. waypoint["position"][3] .. ".")
      speak("Redstone: " .. waypoint["redstone"])
      sleep(0.3)
    end

    speak(cam.distance(0, 0) .. " blocks from ground.")
  end,
  suck = function(string_slot)
    local slot = num(string_slot)
    if slot > 8 then
      speak "Error: only 8 slots exist."
    else
      drone.select(slot)
      drone.suckDown()
      speak("Collected ".. drone.count() .. " items.")
    end
  end,
  drop = function(string_slot)
    local slot = num(string_slot)
    if slot > 8 then
      speak "Cannot comply: I only have 8 slots."
    else
      drone.select(slot)
      drone.dropDown()
      speak("Dropped " .. drone.count() .. " items.")
    end
  end,
  color = function(colorvalue)
    drone.setLightColor(num(colorvalue))
  end,
  to = function(string_x, string_y, string_z)
     local desired_x = num(string_x)
     local desired_y = num(string_y)
     local desired_z = num(string_z)

     x, y, z = nav.getPosition()

    if not (x and y and z) then
      speak "Problem finding location"
      return
    end

    drone.move(desired_x - x, desired_y - y, desired_z - z)
  end,
  flystats = function()
    speak("Going at " .. drone.getVelocity() .. " blocks/second")
    speak("That's " .. (drone.getVelocity() / drone.getMaxVelocity()) * 100 .. "% of my top speed")
    speak("I'm " .. drone.getOffset() .. " blocks from my target position")
  end,
  chown = function(new_owner)
    store_key("owner", new_owner)
  end,
  chname = function(new_name)
    store_key("name", new_name)
  end,
  reboot = function()
    comp.shutdown(true)
  end,
  stopfollow = function()
    isfollow = false
  end,
  follow = function()
    isfollow = true
  end
}

sleep()

local coro_yield = coroutine.yield -- More space optimization.

local function follow()
  while true do
    if isfollow and (comp.energy() > 20000) then
      status "Following"
      sleep()
      for _, player in ipairs(radar.getPlayers(3)) do
        if player["name"] and (player["name"] == owner_name) then
          drone.move(player.x, player.y, player.z)
        end
      end
      sleep()
    end
    coro_yield()
  end
end

local function chat_control()
  while true do
    ev = {coroutine.yield()}
    -- Yes, there is no filtering, so maybe it won't be a chat message. There is parsing later though, which makes these risks small.
    status "Detected"

    local name = ev[3]
    local message = ev[4]

    if name == owner_name then
      args = {}
      status "Parsing"

      sleep()

      message = str.gsub(message, "%.", "")
      status(message)

      for w in str.gmatch(message, "%S+") do
        table.insert(args, w)
        sleep()
      end

      if args[1] == command_prefix then -- Is command directed at us?
        table.remove(args, 1)
        if commands[args[1]] then -- Does the command actually exist?
          sleep()
          local cfunc = commands[args[1]]
          status "Executing"
          sleep()
          table.remove(args, 1)

          sleep()
          cfunc(table.unpack(args)) -- Execute command with args.
        end
      end
    end
  end
end

register_coro(follow, false)
register_coro(chat_control, true)