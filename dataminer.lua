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

local module = {}

local function _newdataset()
  dataset = {}
  dataset.data = {}
  dataset.keys = {}
  function dataset:print(limit) return dprint(self.data, limit) end
  function dataset:printkeys() return dprintkeys(self.keys) end
  function dataset:append(line) return dappend(self.data, self.keys, line) end
  function dataset:insert(line, pos) return dinsert(self.data, self.keys, line, pos) end
  function dataset:find(key, value, strict) return dfind(self.data, key, value, strict) end
  function dataset:sort(func) return table.sort(self.data, func) end
  function dataset:distinct_value_count(key, value) return ddistinct_value_count(self.data, key, value) end
  function dataset:distinct_value_func(dkey, fkey, func, share) return ddistinct_value_func(self.data, dkey, fkey, func, share) end
  function dataset:distinct_func_value_func(dkey, dfunc, fkey, func, share) return ddistinct_func_value_func(self.data, dkey, dfunc, fkey, func, share) end
  function dataset:linewalk(func) return dlinewalk(self.data, func) end
  function dataset:keywalk(key, func) return dkeywalk(self.data, key, func) end
  function dataset:addkey(key, func) return daddkey(self.data, self.keys, key, func) end
  function dataset:accumulation(key) return daccumulation(self.data, key) end
  function dataset:size() return #self.data end
  function dataset:exportcsv(filename, separator, userkeys) return dexportcsv(self.data, self.keys, filename, separator, userkeys) end
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

function module.tonumber(number)
  if type(number) == 'string' then
    number = number:gsub(',','.')
  end
  return tonumber(number)
end

function module.round(number, dec)
  local d = dec or 2
  fmt = '%.'..tostring(d)..'f'
  return tonumber(string.format(fmt, number)) 
end

function module.sumtable(t)
  local s = 0
  for _,v in ipairs(t) do
    value = module.tonumber(v)
    if value then
      s = s + value
    end
  end
  return s
end

--
-- Data collection functions
--
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

  for _,line in ipairs(lines) do
    local nl, idx, temp = {}, 1, nil 
    for value in string.gmatch(line, '(.-'..sep..')') do
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

function dinsert(data, keys, line, pos)
  for k,_ in pairs(line) do
    _uniq(keys, k)
  end
  table.insert(data, pos, line)
end

function dappend(data, keys, line)
  for k,_ in pairs(line) do
    _uniq(keys, k)
  end
  table.insert(data, line)
end

function dprint(data, limit)
  local count = 0
  for _,v in ipairs(data) do
    count = count + 1
    if limit and count > limit then break end
    str = ''
    for k,v2 in pairs(v) do
      io.write(string.format('%s=%s ', k, v2))
    end
    io.write('\n')
  end
end

function dprintkeys(keys)
  for _, k in ipairs(keys) do
    io.write(string.format('%s\n', k))
  end
end

function dfind(data, key, value, strict)
  new = _newdataset()
  for _,v in ipairs(data) do
    for k, v2 in pairs(v) do
      if strict and k == key and not value then
        new:append(v)
      elseif strict and not key and v2 == value then
        new:append(v)
      elseif strict and k == key and v2 == value then
        new:append(v)
      elseif not strict and type(key) == 'string' and k:find(key) and
          not value then
        new:append(v)
      elseif not strict and not key and type(v2) == 'string' and type(value) == 'string' and
          v2:find(value) then
        new:append(v)
      elseif not strict and type(v2) == 'string' and type(value) == 'string' and type(key) == 'string' and
          k:find(key) and v2:find(value) then 
        new:append(v)
      end
    end
  end
  return new
end

function dsort(data, func)
  return table.sort(data, func)
end

function ddistinct_value_count(data, key)
  result = {}
  -- Set table
  for _,line in ipairs(data) do
    local value = line[key]
    if result[value] then result[value] = result[value] + 1 else result[value] = 1 end
  end

  -- Sum
  sum = 0
  for k, v in pairs(result) do
    sum = sum + v
  end

  new = _newdataset()
  for k, v in pairs(result) do
    new:append({[key] = k, count = v, share = (v*100)/sum})
  end
  return new
end

function ddistinct_value_func(data, dkey, fkey, ffunc, share)
  local result = {}
  local func = ffunc or function(t) return #t end

  -- Set table
  for _,line in ipairs(data) do
    local value = line[dkey]
    if value and result[value] then
      table.insert(result[value], line[fkey])
    else
      result[value] = { line[fkey] }
    end
  end

  new = _newdataset()
  local total = 0
  for k, v in pairs(result) do
    if k and v then
      local value = func(v)
      if share then total = total + value end
      new:append({[dkey] = k, [fkey] = value})
    end
  end

  if share then
    for _,line in ipairs(new.data) do
      line['share'] = (line[fkey]*100)/total
    end
  end
  return new
end

function ddistinct_func_value_func(data, dkey, dffunc, fkey, ffunc, share)
  local result = {}
  local func = ffunc or function(t) return #t end
  local dfunc = dffunc or function(t) return t end 

  for _,line in ipairs(data) do
    local dv = dfunc(line[dkey])
    if dv and result[dv] then
      table.insert(result[dv], line[fkey])
    else
      result[dv] = { line[fkey] }
    end
  end

  new = _newdataset()
  local total = 0
  for k, v in pairs(result) do
    local value = func(v)
    if share then total = total + value end
    new:append({[dkey] = k, [fkey] = value})
  end

  if share then
    for _,line in ipairs(new.data) do
      line['share'] = (line[fkey]*100)/total
    end
  end
  return new
end

function dlinewalk(data, func)
  for _,line in ipairs(data) do
    func(line)
  end
end

function dkeywalk(data, key, kfunc)
  local func = kfunc or function(t) return t end
  local values = {}
  for _,line in ipairs(data) do
    if line[key] then table.insert(values, line[key]) end
  end
  return func(values)
end

function daddkey(data, keys, key, func)
  local afunc = func or function() return '' end

  for _,line in ipairs(data) do
    line[key] = func(line)
  end
  table.insert(keys, key)
end

function dexportcsv(data, allkeys, filename, separator, userkeys)
  local sep = separator or ';'
  local ks = userkeys or allkeys 

  output = io.open(filename, 'w')
  output:write(table.concat(ks, sep)..'\n')

  for _,line in ipairs(data) do
    local vs = {}
    for _,k in ipairs(ks) do
      table.insert(vs, line[k])
    end
    output:write(table.concat(vs, sep)..'\n')
  end
  output:close()
end

function daccumulation(data, key)
  local cumul = 0
  for _,line in ipairs(data) do
    cumul = line[key] + cumul
    line[key] = cumul
  end
end

return module
