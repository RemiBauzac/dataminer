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
module.success = 0
module.failed = 0
module.tests = 0
module.run = function()
  for k,v in pairs(_G) do
    if k:sub(1,5) == 'Test_' and type(v) == 'function' then
      module.tests = module.tests + 1
      _header(string.format('Running %s',k:sub(6)))
      status, err = pcall(v)
      if status then
        module.success = module.success + 1
        _ok()
      else
        module.failed = module.failed + 1
        _fail(err)
      end
    end
  end
  local color = OKGREEN
  if module.success == 0 and module.tests > 0 then
    color = FAIL
  elseif module.success > 0 and module.tests > 0 and module.failed > 0 then
    color = WARNING
  end
  print('--------------------------------------------')
  io.write(string.format('%s%d tests ran: %d passed, %d failed%s\n',
    color, module.tests, module.success, module.failed,ENDC))
end

return module
