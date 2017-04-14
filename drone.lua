-- GolDrone 0025b

local comp, ta, num, str = computer, table, tonumber, string
local function sleep(timeout)
   local deadline = comp.uptime() + (timeout or 0)
  repeat
    comp.pullSignal(deadline - comp.uptime())
  until comp.uptime() >= deadline
end

local function part(name)
  return component.proxy(component.list(name)())
end

local pastebin = "http://pastebin.com/raw/"
local owner_name = "gollark"
local drone_name = "QT-8"
local chat = part "chat"
local radar = part "radar"
local drone = part "drone"
local cam = part "camera"
local nav = part "navigation"
local interweb = part "internet"
local bios = part "eeprom"
local code_addr = pastebin .. "WcR4Jn1D"
local extra_addr = pastebin .. "8dBw0yME"
local speak, status = chat.say, drone.setStatusText
status "Bound"

local function split(inputstr, sep)
  local parts = {}
  for str in str.gmatch(inputstr, "([^"..sep.."]+)") do
    ta.insert(parts, str)
  end
  return parts
end

local function read_keys()
  if bios.getData() == "" then
    bios.setData("{}")
  end
  return load("return " .. bios.getData())()
end

local function key_exists(key)
  data = read_keys()

  if data[key] then
    return true
  end

  return false
end

local function read_key(key)
  return read_keys()[key]
end

local function store_table(tab)
  local string_representation = "{"

  for k, v in pairs(tab) do
    string_representation = string_representation .. k .. "=" .. str.format("%q", v) .. ","
  end

  bios.setData(string_representation .. "}")
end

local function store_key(key, value)

  local data = read_keys()
  data[key] = value
  store_table(data)
end

sleep()

comp.beep(2000)

status "Init"

if key_exists "name" then
  drone_name = read_key "name"
end

chat.setName(drone_name)
chat.setDistance(1000)

if key_exists "owner" then
  owner_name = read_key "owner"
end

local command_prefix = drone_name .. ","

sleep()

local function net_get(address)
  local web_request = interweb.request(address)
  status "Updating"
  web_request.finishConnect()
  status "Connected"

  local full_response = ""
  while true do
    status "Processing"
    local chunk = web_request.read()
    if chunk then
      str.gsub(chunk, "\r\n", "\n")
      full_response = full_response .. chunk
    else
      break
    end
  end

  return full_response
end

local bios_code = net_get(code_addr)
if bios_code ~= "" then
  status "Flashing"
  local old_checksum = bios.getChecksum()
  bios.set(bios_code)
  local new_checksum = bios.getChecksum()
  if old_checksum ~= new_checksum then
    comp.shutdown(true) -- Reboot if the firmware was updated
  end
end

status "Configuring"

sleep()

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
      speak("X distance: " .. waypoint["position"][1] .. ".")
      speak("Y distance: " .. waypoint["position"][2] .. ".")
      speak("Z distance: " .. waypoint["position"][3] .. ".")
      speak("Applied redstone signal: " .. waypoint["redstone"])
      sleep(0.3)
    end

    speak(cam.distance(0, 0) .. " blocks from ground.")
  end,
  suck = function(string_slot)
    local slot = num(string_slot)
    if slot > 8 then
      speak("I'm sorry " .. owner_name .. ", I cannot do that; I only have 8 slots.")
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

local coro_yield = coroutine.yield

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
    ev = {coro_yield()}
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
        ta.insert(args, w)
        sleep()
      end

      if args[1] == command_prefix then -- Is command directed at us?
        ta.remove(args, 1)
        if commands[args[1]] then -- Does the command actually exist?
          sleep()
          local cfunc = commands[args[1]]
          status "Executing"
          sleep()
          ta.remove(args, 1)

          sleep()
          cfunc(ta.unpack(args)) --Execute command with args.
        end
      end
    end
  end
end

status "Coroutines"
local createcoro, resumecoro = coroutine.create, coroutine.resume
local coros = {{thread = createcoro(follow), event = false}, {thread = createcoro(chat_control), event = true}}

status "Downloading"
load(net_get(extra_addr) or "")()

while true do
  local event = {comp.pullSignal(0.001)}

  for index, coro in pairs(coros) do
    local coro_thread = coro["thread"]
    local coro_status = coroutine.status(coro_thread)
    if coro_status == "dead" then
      ta.remove(coros, index)
      speak("Error in subroutine " .. index)
    end
    if coro["event"] then
      if event then
        resumecoro(coro_thread, ta.unpack(event))
      end
    else
      resumecoro(coro_thread)
    end
  end
end
