--
-- Constants
--
local TIMESTAMP='@timestamp'
local TAG='@tag'

local SPAN = {
  ['Year'] = '%Y',
  ['Month'] = '%m/%Y',
  ['Day'] = '%d/%m/%Y',
  ['Hour'] = '%d/%m/%Y %H',
  ['Minute'] = '%d/%m/%Y %H:%M',
  ['Second'] = '%d/%m/%Y %H:%M:%S',
  ['%Y'] = 'Year',
  ['%m/%Y'] = 'Month',
  ['%d/%m/%Y'] = 'Day',
  ['%d/%m/%Y %H'] = 'Hour',
  ['%d/%m/%Y %H:%M'] = 'Minute',
  ['%d/%m/%Y %H:%M:%S'] = 'Second'
}

local TIMESP = {
  ['%d'] = 'day',
  ['%m'] = 'month',
  ['%Y'] = 'Year',
  ['%y'] = 'year',
  ['%H'] = 'hour',
  ['%M'] = 'min',
  ['%S'] = 'sec'
}

local DEFAULTSPAN = 'Day'

local docstrings = setmetatable({}, {__mode = "kv"})

--
-- Helpers
--
local function _trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end 

local function _uniq(t, value)
  for _,v in ipairs(t) do
    if v == value then return end
  end
  table.insert(t, value)
end

local function _mandatory(value, name, awtype)
  if value and awtype == 'all' then return end
  if type(value) ~= awtype then
    error(string.format('%s awaited type is %s insteadof %s',
      name, awtype, type(value)))
  end
end

local function _optional(value, name, awtype)
  if value and type(value) ~= awtype  and awtype ~= 'all' then
    error(string.format('%s awaited type is %s insteadof %s',
      name, awtype, type(value)))
  end
end

local function _gettimestamp(str, format)
  local parser = {}
  local match = format:gsub('%%[dmYyHMS]', function(a)
      table.insert(parser, TIMESP[a]); return '(%d+)' end)
  local timespec = {day=1, month=1, year=1970, hour=1, min=0, sec=0}
  if not str then return os.time(timespec) end
  local dt = {str:match(match)}
  for k, v in ipairs(parser) do
    if v == 'year' then dt[k] = dt[k]+2000 end
    if v == 'Year' then v = 'year' end
    timespec[v] = dt[k]
  end
  return os.time(timespec)
end

local function _getspan(line, span)
  local sp = span or DEFAULTSPAN 
  if SPAN[sp] then
    return os.date(SPAN[span], line[TIMESTAMP])
  end
  return os.date(SPAN[DEFAULTSPAN], line[TIMESTAMP])
end

local function _getline(dataset, tag)
  return dataset.tags[tag]
end

local function _updatetags(dataset)
  dataset.tags = {} 
  for k,v in ipairs(dataset.data) do dataset.tags[v[TAG]] = k end
end

local module = {}
module.ctag = 1
module.TIMESTAMP = TIMESTAMP
module.TAG = TAG

local function _newdataset()
  -- create initial tables
  local dataset = {}
  dataset.data = {}
  dataset.keys = {}
  dataset.tags = {}
  dataset.docs = setmetatable({}, {__mode = "kv"})
  dataset.shortdocs = setmetatable({}, {__mode = "kv"})

  -- doc function to create inline doc
  function dataset:doc(str)
    return function(obj)
      self.shortdocs[obj] = str:match('(.-)- .*')
      self.docs[obj] = str
      return obj
    end
  end

  function dataset:help(obj)
    if type(obj) == 'string' then obj = self[obj] end
    if obj then
      if self.docs[obj] then
        print(self.docs[obj])
      else
        print('Documentation is unavailable for requested object')
      end
    else
      for _,v in pairs(self.shortdocs) do print(v) end
    end
  end
  dataset:doc[[help(f) - print help for function 'f' and return the data set
  - f(function or string, optional): the function f which need help.
      If nil, print all the function's help]](dataset.help)

  function dataset:append(line)
    _mandatory(line, 'l', 'table')
    return dappend(self, line)
  end
  dataset:doc[[append(l) - append a line 'l' to the data set and return the data set
  - line(table, mandatory): key/value table to append]](dataset.append)

  function dataset:size() return #self.data end
  dataset:doc[[size() - return the data set line number]](dataset.size)

  function dataset:first() return self.data[1] end
  dataset:doc[[first() - return the data set first line
  ]](dataset.first)

  function dataset:last() return self.data[#self.data] end
  dataset:doc[[last() - return the data set last line
  ]](dataset.last)

  function dataset:addkey(key, func)
    _mandatory(key, 'k', 'string')
    _optional(func, 'f', 'function')
    daddkey(self.data, self.keys, key, func)
    return self
  end
  dataset:doc[[addkey(k, f) - add a key named 'k' on each line and return the data set
  - k(string, mandatory): name of the key to add
  - f(function, optional): function to compute key, with the current line as parameter.
      If nil, empty string is set for the key on all lines
  ]](dataset.addkey)

  function dataset:delkey(key)
    _mandatory(key, 'k', 'string')
    ddelkey(self.data, self.keys, key)
    return self
  end
  dataset:doc[[delkey(k) - delete the key named 'k' on each line and return the data set
  - k(string, mandatory): name of the key to delete
  ]](dataset.delkey)

  function dataset:distinct(key)
    _mandatory(key, 'k', 'string')
    return ddistinct(self.data, key)
  end
  dataset:doc[[distinct(k) - return a new dataset with all key 'k' distinct values and count
  - k(string, mandatory): name of the key distinct values and count
  ]](dataset.distinct)

  function dataset:distinctvalues(key)
    _mandatory(key, 'k', 'string')
    return ddistinctvalues(self.data, key)
  end
  dataset:doc[[distinct(k) - return a list with all key 'k' distinct values
  - k(string, mandatory): name of the key distinct values
  ]](dataset.distinctvalues)

  function dataset:remove(line)
    _mandatory(line, 'l', 'table')
    dremove(self, line)
    return self
  end
  dataset:doc[[remove(l) - remove the 'l' line to the data set and return the data set
  - l(table, mandatory): line to remove
  ]](dataset.remove)

  function dataset:replace(key, value, replace)
    _mandatory(key, 'k', 'string')
    _mandatory(value, 'v', 'all')
    _mandatory(replace, 'r', 'all')
    dreplace(self.data, key, value, replace)
    return self
  end
  dataset:doc[[replace(k, v, r) - replace the value 'v' of the key 'k' by the new value 'r' on all data set lines and return the data set
  - k(string, mandatory): key of value to replace 
  - v(all, mandatory): value to replace 
  - r(all, mandatory): new value
  ]](dataset.remove)

  function dataset:lines() return ipairs(self.data) end
  dataset:doc[[lines() - return the iterator on data set lines
  ]](dataset.lines)

  function dataset:keywalk(key, func)
    _mandatory(key, 'k', 'string')
    _optional(func, 'f', 'function')
    return dkeywalk(self.data, key, func)
  end
  dataset:doc[[keywalk(k, f) - walk through all key 'k' values and return the result of function 'f' applied on it
  - k(string, mandatory): key to walk through
  - f(function, optional): function to compute the values (as table).
      If nil, the number of values is returned
  ]](dataset.keywalk)

  function dataset:print(limit)
    _optional(limit, 'limit', 'number')
    dprint(self.data, limit);
    return self
  end
  dataset:doc[[print(limit) - print data set lines to the console, according to 'limit'
  - limit(number, optional): limit the number of printed lines
  ]](dataset.print)

  function dataset:printkeys() dprintkeys(self.keys); return self end
  dataset:doc[[printkeys() - print all the keys of the dataset
  ]](dataset.printkeys)

  function dataset:settimestamp(key, format)
    _mandatory(key, 'k', 'string')
    _mandatory(format, 'fmt', 'string')
    dsettimestamp(self, key, format)
    return self
  end
  dataset:doc[[settimestamp(k, fmt) - use the key 'k' to set dataset timestamp on each lines, according to time format 'fmt'
  - k(string, mandatory): key used as timestamp
  - fmt(string, mandatory): time format
  ]](dataset.settimestamp)

  function dataset:sort(param)
    dsort(self.data, param)
    _updatetags(self)
    return self
  end
  dataset:doc[[sort(p) - sort data set with 'p'
  - p(function or string, mandatory): sort parameter.
      If p is a function, this function is used as compare function.
      If p is a string, it is used as key to sort by values of this key (number awaited)
  ]](dataset.sort)

  function dataset:timesort()
    table.sort(self.data, function(a, b)
       return a[TIMESTAMP] and b[TIMESTAMP] and a[TIMESTAMP] < b[TIMESTAMP] end)
    _updatetags(self)
    return self
  end
  dataset:doc[[timesort() - use timestamp (added with settimestamp) to sort in time order
  ]](dataset.timesort)

  function dataset:top(pkey, fkey, func)
    return dtop(self.data, pkey, fkey, func)
  end

  function dataset:timechart(key, func, span)
    return dtimechart(self, key, func, span or DEFAULTSPAN)
  end

  function dataset:timegroup(span) return dtimegroup(self, span or DEFAULTSPAN) end
  function dataset:group(key) return dgroup(self, key) end
  function dataset:search(values, from, limit) return dsearch(self, values, from) end
  function dataset:select(func) return dselect(self.data, func) end
  function dataset:csv(filename, separator, userkeys)
    return dexportcsv(self.data, self.keys, filename, separator, userkeys)
  end
  return dataset
end

--
-- dataminer module functions
--
function module.new(source, sourcetype, sourcesep)
  if type(source) == 'string' and type(sourcetype) == 'string' then
    if sourcetype == 'csv' then
      return _newcsv(source, sourcesep)
    elseif sourcetype == 'lua' then
    else
      return _newdataset()
    end
  else
    return _newdataset()
  end
end

function module.tonumber(number, round)
  if type(number) == 'string' then
    number = number:gsub(',','.')
  end
  if round then
    return module.round(tonumber(number), round)
  end
  return tonumber(number)
end

function module.round(number, dec)
  local d = dec or 2
  fmt = '%.'..tostring(d)..'f'
  return tonumber(string.format(fmt, number)) 
end

function module.sum(t)
  local s = 0
  for _,v in ipairs(t) do
    local value = module.tonumber(v)
    if value then
      s = s + value
    end
  end
  return s
end

function module.avg(t)
  local s = 0
  for _,v in ipairs(t) do
    value = module.tonumber(v)
    if value then
      s = s + value
    end
  end
  return s/#t
end

function module.count(t)
  return #t
end

function module.distinctcount(t)
  local rt = {}
  for _,v in ipairs(t) do
    if rt[v] then rt[v] = rt[v] + 1 else rt[v] = 1 end
  end
  return rt
end

function _newcsv(filename, awsep)
  local lines = {}
  local sep = awsep or ';'
  result = _newdataset()

  -- Put file lines in a table
  for line in io.lines(filename) do
    -- remove leading and trailing whitespaces
    line = _trim(line)
    if line:byte(line:len()) ~= sep:byte(sep:len()) then line = line..sep end
    table.insert(lines, line)
  end

  -- Take care of empty file
  if #lines == 0 then return result end

  -- Parse header
  for header in string.gmatch(lines[1], "(.-)"..sep) do
    head,_ = string.gsub(header,"\"", "")
    _uniq(result.keys, head)
  end
  table.remove(lines, 1) 

  for lidx,line in ipairs(lines) do
    local nl, idx, temp = {}, 1, nil 
    for value in string.gmatch(line, '(.-'..sep..')') do
      if not result.keys[idx] then
        error(string.format('CSV parsing error at line %d, column %d', lidx, idx))
      end
      -- value is about "...." without separator inside (have to remove last one)
      if value:byte() == 34 and value:byte(#value-1) == 34 and temp == nil then
        nl[result.keys[idx]] = value:sub(1,-2)
        idx = idx + 1
      -- value starts with " with separator inside (don't remove it)
      elseif value:byte() == 34 and temp == nil then
        temp = value
      -- value ends with " without separator inside (have to remove last one)
      elseif temp ~= nil and value:byte(#value-1) == 34 then
        temp = temp..value:sub(1, -2)
        nl[result.keys[idx]] = temp
        idx = idx + 1
        temp = nil
      -- value continue, have to wait last ", don't remove separator
      elseif temp ~= nil then
        temp = temp..value
      -- value is standard (no separator, no ")
      else
        nl[result.keys[idx]] = value:sub(1, -2)
        idx = idx + 1
      end
    end
    result:append(nl)
  end
  return result
end

--
-- Data set functions
--
function dappend(dataset, line)
  for k,_ in pairs(line) do
    _uniq(dataset.keys, k)
  end
  if not line[TAG] then
    line[TAG] = module.ctag
    module.ctag = module.ctag + 1
  end
  table.insert(dataset.data, line)
  dataset.tags[line[TAG]] = #dataset.data
end

function daddkey(data, keys, key, func)
  local afunc = func or function() return '' end

  for _,line in ipairs(data) do
    if extdata then line[key] = func(line)
    else line[key] = func(line)
    end
  end
  table.insert(keys, key)
end

function ddelkey(data, keys, key)
  local keyidx = 0
  for _,line in ipairs(data) do
    line[key] = nil 
  end
  for k,v in ipairs(keys) do
    if v == key then keyidx = k; break end
  end
  table.remove(keys, keyidx)
end

function ddistinct(data, key)
  local rt = {}

  for _,line in ipairs(data) do
    if rt[line[key]] then
      rt[line[key]] = rt[line[key]] + 1
    else rt[line[key]] = 1 end
  end

  local result = _newdataset()
  for k, v in pairs(rt) do
    result:append({[key]= k, ['count']=v})
  end
  return result
end

function ddistinctvalues(data, key)
  local rt = {}
  local result = {}

  for _,line in ipairs(data) do
    if line[key] and not rt[line[key]] then
      table.insert(result, line[key])
      rt[line[key]] = 1
    end
  end
  return result
end

function dremove(dataset, line)
  local tag = line[TAG]
  local id = _getline(dataset, tag)
  if id and id > 0 then
    table.remove(dataset.data, id)
  end
  _updatetags(dataset)
end

function dreplace(data, key, value, replace)
  for _,line in ipairs(data) do
    if line[key] == value then
      line[key] = replace
    end
  end
end

function dprint(data, limit)
  local count = 0
  for _,v in ipairs(data) do
    count = count + 1
    if limit and count > limit then break end
    str = ''
    for k,v2 in pairs(v) do
      if k:sub(1,1) ~= '@' then
        if type(v2) == 'table' then
          io.write(string.format('%s=', k))
          for _,v3 in ipairs(v2) do
            io.write(string.format('%s,', v3))
          end
          io.write('\b ')
        else
          io.write(string.format('%s=%s ', k, v2))
        end
      end
    end
    io.write('\n')
   end
end

function dkeywalk(data, key, func)
  local f = func or miner.count
  local rt = {}

  for _,line in ipairs(data) do
    table.insert(rt, line[key])
  end

  return f(rt)
end

function dprintkeys(keys)
  for _, k in ipairs(keys) do
    io.write(string.format('%s\n', k))
  end
end

function dsettimestamp(dataset, key, format)
  dataset.timefield = key
  dataset.timeformat = format 
  dataset:addkey(TIMESTAMP, 
    function(line) return _gettimestamp(line[key], format) end)
  dataset:timesort()
end

function dsort(data, param)
  if type(param) == 'function' then
    table.sort(data, param)
  elseif type(param) == 'string' then
    table.sort(data, function(a, b)
      return a[param] and b[param] and miner.tonumber(a[param]) <
        miner.tonumber(b[param])
    end)
  end
end

function dtop(data, pkey, fkey, func)
  local rt = {}
  local f = func or module.count
  local fname = string.format('f(%s)',fkey) 

  -- collecting
  for _, line in ipairs(data) do
    if rt[line[pkey]] then
      table.insert(rt[line[pkey]], line[fkey])
    else
      rt[line[pkey]] = {line[fkey]}
    end 
  end

  -- processing
  local result = _newdataset()
  for k,v in pairs(rt) do
    result:append({[pkey]=k, [fname]= f(v)})
  end

  -- sorting
  result:sort(function(a, b) return a[fname] and b[fname] and a[fname] > b[fname] end)
  _updatetags(result)
  return result
end

function dtimechart(dataset, key, func, span)
  local rt = {}
  local f = func or module.count
  local fname = string.format('f(%s)', key)

  -- collecting
  for _, line in ipairs(dataset.data) do
    local sp = _getspan(line, span)
    if rt[sp] then
      table.insert(rt[sp], line[key])
    else
      rt[sp] = {line[key]}
    end 
  end

  -- processing
  local result = _newdataset()
  for k,v in pairs(rt) do
    local fr = f(v)
    if type(fr) == 'table' then
      rl = {[span]=k}
      for frk, frv in pairs(fr) do
        rl[frk] = frv
      end
      result:append(rl)
    else
      result:append({[span]=k, [fname]= fr})
    end
  end

  -- timestamping and sorting
  result:settimestamp(span, SPAN[span]) 
  _updatetags(result)
  return result
end

function dtimegroup(dataset, span)
  local rt = {}

  -- collecting
  for _, line in ipairs(dataset.data) do
    local sp = _getspan(line, span)
    line['#'..span] = sp
    if rt[sp] then
      rt[sp]:append(line)
    else
      rt[sp] = _newdataset()
      rt[sp]:append(line)
    end
  end

  -- timestamping and sorting
  for _,g in pairs(rt) do
    g:settimestamp(dataset.timefield, dataset.timeformat)
    _updatetags(g)
  end

  return rt
end

function dgroup(dataset, key)
  local rt = {}
  if not key then return rt end

  -- collecting
  for _, line in ipairs(dataset.data) do
    local sp = line[key]
    if sp and rt[sp] then
      rt[sp]:append(line)
    elseif sp then
      rt[sp] = _newdataset()
      rt[sp]:append(line)
    end 
  end

  -- timestamping and sorting
  for _,g in pairs(rt) do
    g:settimestamp(dataset.timefield, dataset.timeformat)
    _updatetags(g)
  end

  return rt
end

function dsearch(dataset, values, from)
  local data = dataset.data
  local result = _newdataset()
  local f, count = 1,0
  
  if from and from[TAG] then
    f = _getline(dataset, from[TAG])
  end
  if f < #data then
    for i = f,#data,1 do
      local found = true
      for k,v in pairs(values) do
        if data[i][k] ~= v then
          found = false;break
        end
      end
      if found then
        result:append(data[i])
        if limit and count == limit then break end
      end
    end
  end
  return result
end

function dselect(data, func)
  local f = func or function(l) return true end 
  local result = _newdataset()

  for _,line in ipairs(data) do
    if f(line) then result:append(line) end
  end
  return result
end

function dexportcsv(data, allkeys, filename, separator, userkeys)
  local sep = separator or ';'
  local ssep = ','
  local ks = {} 

  if sep == ',' then ssep = ';' end

  for _, k in ipairs(userkeys or allkeys) do
    if k:sub(1,1) ~= '@' then
      table.insert(ks, k)
    end
  end

  output = io.open(filename, 'w')
  if not output then error('Cannot open file '..filename..' for writing') end
  output:write(table.concat(ks, sep)..'\n')

  for _,line in ipairs(data) do
    local vs = {}
    for _,k in ipairs(ks) do
      if k:sub(1,1) ~= '@' then
        if type(line[k]) == 'table' then
          table.insert(vs, table.concat(line[k], ssep))
        else
          table.insert(vs, line[k] or '')
        end
      end
    end
    output:write(table.concat(vs, sep)..'\n')
  end
  output:close()
end


-- exporting module
return module
