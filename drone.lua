-- drone.lua
-- A simple runtime for OpenComputers drones. Exposes a simple API to the extras file.

local comp, ta, str = computer, table, string
function sleep(timeout)
   local deadline = comp.uptime() + (timeout or 0)
  repeat
    comp.pullSignal(deadline - comp.uptime())
  until comp.uptime() >= deadline
end

local function part(name)
  return component.proxy(component.list(name)())
end

local repo = "https://github.com/osmarks/oc-drone/blob/master/"
chat = part "chat"
radar = part "radar"
drone = part "drone"
cam = part "camera"
nav = part "navigation"
interweb = part "internet"
bios = part "eeprom"
local code_addr = pastebin .. "drone.lua"
local extra_addr = pastebin .. "drone_extras.lua"
local speak, status = chat.say, drone.setStatusText
status "Bound"

function read_keys()
  if bios.getData() == "" then
    bios.setData("{}")
  end
  return load("return " .. bios.getData())()
end

function key_exists(key)
  data = read_keys()

  if data[key] then
    return true
  end

  return false
end

function read_key(key)
  return read_keys()[key]
end

function store_table(tab)
  local string_representation = "{"

  for k, v in pairs(tab) do
    string_representation = string_representation .. k .. "=" .. str.format("%q", v) .. ","
  end

  bios.setData(string_representation .. "}")
end

function store_key(key, value)
  local data = read_keys()
  data[key] = value
  store_table(data)
end

sleep()

comp.beep(2000)

status "Init"

function net_get(address)
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

status "Coro init"
local resumecoro = coroutine.resume

local coros = {}

function register_coro(func, recv_events)
  ta.insert(coros, {thread = createcoro(func), event = recv_events})
end

-- At this point we download the extras file & execute it. The extras file should add its coroutines.
status "Downloading"
load(net_get(extra_addr) or "")()

while true do
  local event = {comp.pullSignal(0.001)}

  for index, coro in pairs(coros) do
    local coro_thread = coro["thread"]
    local coro_status = coroutine.status(coro_thread)
    if coro_status == "dead" then
      ta.remove(coros, index)
      status ":(           "
      speak("Error in coroutine " .. index)
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
