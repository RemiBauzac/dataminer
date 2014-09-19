HEADER = string.char(27)..'[95m'
OKGREEN = string.char(27)..'[92m'
WARNING = string.char(27)..'[93m'
FAIL = string.char(27)..'[91m'
ENDC = string.char(27)..'[0m'

local hclock

function _header(str)
  io.write(HEADER..str..'...'..ENDC)
  io.flush()
  hclock = os.clock()
end

function _ok()
  io.write(string.format('%sOK (%.2f s)%s\n',OKGREEN, os.clock()-hclock, ENDC))
end

function _fail(msg)
  io.write(string.format('%sFAIL (%s)%s\n',FAIL, msg, ENDC))
end

local module = {}

module.run = function()
  for k,v in pairs(_G) do
    if k:sub(1,5) == 'Test_' and type(v) == 'function' then
      _header(string.format('Running %s',k:sub(6)))
      status, err = pcall(v)
      if status then
        _ok()
      else
        _fail(err)
      end
    end
  end
end

return module
