--
-- Constants
--
local TIMESTAMP='@timestamp'
local GROUPSTAMP='@group'
local GROUPFUNCTION='f(group)'

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

--
-- Metatables
--
local _line_meta = {
  __eq = function(a,b) 
    ret = true
    for k,v in pairs(a) do
      if k:sub(1,1) ~= '@' and b[k] ~= v then ret = false; break end
    end
    return ret
  end,
  __tostring = function(t)
    local ret = ''
    for k, v in pairs(t) do
      if k:sub(1,1) ~= '@' then
        if type(v) == 'table' then
          ret = ret..string.format('%s=', k)
          for _,v2 in ipairs(v) do
            ret = ret..string.format('%s,', v2)
          end
          ret = ret..'\b '
        else
          ret = ret..string.format('%s=%s ', k, v)
        end
      end
    end
    return ret
  end
}

local _dataset_meta = {
  __tostring = function(t)
    ret = ''
    for _,v in ipairs(t.data) do
      ret = ret..tostring(v)..'\n'
    end
    return ret
  end,
  __eq = function(a, b)
    ret = true
    if #a.data ~= #b.data then return false end
    for idx = 1,#a.data,1 do
      if a.data[idx] ~= b.data[idx] then ret = false; break end
    end
    return ret
  end,
  __len = function(t) return #t.data end,
	__index = function(t, k)
		local data = rawget(t, 'data')
		local groupkey = rawget(t, 'groupkey')
		if type(k) == 'number' then
			return data[k]
		end
		
		if type(k) == 'string' and groupkey then
			for _,v in ipairs(data) do
				if v[groupkey] == k then
					return v[GROUPSTAMP]
				end
			end
		end
		return nil
	end,
	__add = function(t, l)
  	for k,_ in pairs(l) do
    	_uniq(t.keys, k)
  	end
  	setmetatable(l, _line_meta)
  	table.insert(t.data, l)
		return t
	end,
	__concat = function(d1, d2)
		local r = _newdataset()
		for _,l in d1:lines() do
			r = r + l
		end
		for _,l in d2:lines() do
			r = r + l
		end
		return r
	end
}

local module = {}
module.TIMESTAMP = TIMESTAMP
module.GROUPSTAMP = GROUPSTAMP
module.GROUPFUNCTION = GROUPFUNCTION

function _newdataset()
  -- create initial tables
  local dataset = {}
  setmetatable(dataset, _dataset_meta)
  dataset.data = {}
  dataset.keys = {}
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

  function dataset:first() return self.data[1] end
  dataset:doc[[first() - return the data set first line]](dataset.first)

  function dataset:last() return self.data[#self.data] end
  dataset:doc[[last() - return the data set last line]](dataset.last)

  function dataset:addkey(key, func)
    _mandatory(key, 'k', 'string')
    _optional(func, 'f', 'function')
    daddkey(self.data, self.keys, key, func)
    return self
  end
  dataset:doc[[addkey(k, f) - add a key named 'k' on each line and return the data set
  - k(string, mandatory): name of the key to add
  - f(function, optional): function to compute key, with the current line as parameter.
      If nil, empty string is set for the key on all lines]](dataset.addkey)

  function dataset:groupaddkey(key, func)
    _mandatory(key, 'k', 'string')
    _optional(func, 'f', 'function')
    dgroupaddkey(self, key, func)
    return self
  end
  dataset:doc[[groupaddkey(k, f) - add a key named 'k' on each group and return the group data set
  - k(string, mandatory): name of the key to add
  - f(function, optional): function to compute key, with the current group lines as parameter.
      If nil, empty string is set for the key on all lines]](dataset.groupaddkey)

  function dataset:delkey(key)
    _mandatory(key, 'k', 'string')
    ddelkey(self.data, self.keys, key)
    return self
  end
  dataset:doc[[delkey(k) - delete the key named 'k' on each line and return the data set
  - k(string, mandatory): name of the key to delete]](dataset.delkey)

  function dataset:distinct(key)
    _mandatory(key, 'k', 'string')
    return ddistinct(self.data, key)
  end
  dataset:doc[[distinct(k) - return a new dataset with all key 'k' distinct values and count
  - k(string, mandatory): name of the key distinct values and count]](dataset.distinct)

  function dataset:distinctvalues(key)
    _mandatory(key, 'k', 'string')
    return ddistinctvalues(self.data, key)
  end
  dataset:doc[[distinct(k) - return a list with all key 'k' distinct values
  - k(string, mandatory): name of the key distinct values]](dataset.distinctvalues)

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
  - r(all, mandatory): new value]](dataset.replace)

  function dataset:lines() return ipairs(self.data) end
  dataset:doc[[lines() - return the iterator on data set lines]](dataset.lines)

  function dataset:glines()
		local group = {}
		if not self.groupkey then return pairs(group) end
		for _, l in self:lines() do
			group[l[self.groupkey]] = l[GROUPSTAMP]
		end
		return pairs(group)
	end
  dataset:doc[[glines() - return the iterator on group lines]](dataset.glines)

	function dataset:grouptable()
		local group = {}
		if not self.groupkey then return pairs(group) end
		for _, l in self:lines() do
			group[l[self.groupkey]] = l[GROUPSTAMP]
		end
		return group
	end
  dataset:doc[[glines() - return group as a table]](dataset.grouptable)

  function dataset:keywalk(key, func)
    _mandatory(key, 'k', 'string')
    _optional(func, 'f', 'function')
    return dkeywalk(self.data, key, func)
  end
  dataset:doc[[keywalk(k, f) - walk through all key 'k' values and return the result of function 'f' applied on it
  - k(string, mandatory): key to walk through
  - f(function, optional): function to compute the values (as table).
      If nil, the number of values is returned]](dataset.keywalk)

	function dataset:groupwalk(func)
		_mandatory(func, 'f', 'function')
		return dgroupwalk(self, func)
	end
  dataset:doc[[groupwalk(k, f) - walk through groups of a grouped dataset and return a new dataset with result of function 'f' applied of all lines of this group
  - f(function, mandatory): function to compute the values (as group keys and dataset) ]] (dataset.groupwalk)

  function dataset:print(limit)
    _optional(limit, 'limit', 'number')
    dprint(self.data, limit);
    return self
  end
  dataset:doc[[print(limit) - print data set lines to the console, according to 'limit'
  - limit(number, optional): limit the number of printed lines]](dataset.print)

  function dataset:printkeys() dprintkeys(self.keys); return self end
  dataset:doc[[printkeys() - print all the keys of the dataset]](dataset.printkeys)

  function dataset:settimestamp(key, format)
    _mandatory(key, 'k', 'string')
    _mandatory(format, 'fmt', 'string')
    dsettimestamp(self, key, format)
    return self
  end
  dataset:doc[[settimestamp(k, fmt) - use the key 'k' to set dataset timestamp on each lines, according to time format 'fmt' and return the data set
  - k(string, mandatory): key used as timestamp
  - fmt(string, mandatory): time format]](dataset.settimestamp)

  function dataset:sort(param)
    dsort(self.data, param)
    return self
  end
  dataset:doc[[sort(p) - sort data set with 'p' and return the data set
  - p(function or string, mandatory): sort parameter.
      If p is a function, this function is used as compare function.
      If p is a string, it is used as key to sort by values of this key (number awaited)]](dataset.sort)

  function dataset:timesort()
    table.sort(self.data, function(a, b)
       return a[TIMESTAMP] and b[TIMESTAMP] and a[TIMESTAMP] < b[TIMESTAMP] end)
    return self
  end
  dataset:doc[[timesort() - use timestamp (added with settimestamp) to sort in time order and return data set]](dataset.timesort)

  function dataset:top(pkey, fkey, func)
    _mandatory(pkey, 'k', 'string')
    _mandatory(fkey, 'ck', 'string')
    _optional(func, 'f', 'function')
    return dtop(self.data, pkey, fkey, func)
  end
  dataset:doc[[top(k, ck, f) - return a new dataset with top of key 'k' values, according to function 'f' applied to key 'ck'
  - k(string, mandatory): top key
  - ck(string, mandatory): key used to compute the top
  - f(function, optional): function used to compute the top
      If nil, top count the number of distinct values of key 'k']](dataset.top)

  function dataset:timechart(key, group, func, span)
    _mandatory(key, 'k', 'string')
    _optional(group, 'g', 'string')
    _optional(func, 'f', 'function')
    _optional(span, 's', 'string')
    return dtimechart(self, key, group, func, span or DEFAULTSPAN)
  end
  dataset:doc[[timechart(k, g, f, s) - return a new data set with computed key 'k' values with function 'f' over the time grouped by key 'g'
  - k(string, mandatory): key of values to compute
  - g(string, optional): key to group values
  - f(function,optional): function used to compute values
      If nil, timechart count distinct values of key 'k'
  - s(string, optional): span of the timechart.
      Available values are : 'Year', 'Month', 'Day', 'Hour', 'Minute', 'Second'
      If nil, 'Day' is used]](dataset.timechart)

  function dataset:timegroup(span, ...)
    _optional(span, 's', 'string')
    return dtimegroup(self, span or DEFAULTSPAN, ...)
  end
  dataset:doc[[timegroup(s) - return a table of data set, grouped by 's'
  - s(string, optional): span of the timechart.
      Available values are : 'Year', 'Month', 'Day', 'Hour', 'Minute', 'Second'
      If nil, 'Day' is used
	- keys(list of string, optional): keys to subgroup]](dataset.timegroup)

  function dataset:group(...)
    return dgroup(self, ...)
  end
  dataset:doc[[group(k1, k2, ...) - return a table of data set, hierarchicaly grouped by distinct values of key 'k1', then 'k2', etc.  
  - kX(string, mandatory): keys for the distinct value to group]](dataset.group)

  function dataset:search(values)
    _mandatory(values, 'v', 'table')
    return dsearch(self, values)
  end
  dataset:doc[[search(v) - return a dataset with lines matching values 'v' 
  - v(table, mandatory): key/value table to match dataset key/value]](dataset.search)

  function dataset:select(func)
    _optional(func, 'f', 'function')
    return dselect(self.data, func)
  end
  dataset:doc[[select(f) - return a dataset with selected lines of function 'f'
  - f(function, optional): function used to select a line. Must return true if the line is selcted 
      If nil, all lines are selected]](dataset.select)

  function dataset:csv(filename, separator, userkeys)
    _mandatory(filename, 'f', 'string')
    _optional(separator, 's', 'string')
    _optional(userkeys, 'k', 'table')
    return dexportcsv(self.data, self.keys, filename, separator, userkeys)
  end
  dataset:doc[[csv(f, s, k) - export data set in csv file, using 's' as separator, and return data set
  - f(string, mandatory): file name to export csv
  - s(string, optional): csv separator. ';' by default
  - k(table, optional): key table to force only these on csv
  ]](dataset.csv)

  return dataset
end

--
-- dataminer module functions
--
function module.new(source, sourcetype, sourcesep)
  if sourcetype == 'csv' then
    return _newcsv(source, sourcesep)
  elseif sourcetype == 'lua' then
    return _newlua(source)
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

function _newlua(t)
  local result = _newdataset()

  for _,v in ipairs(t) do
		result = result + v
  end
  return result
end

function _newcsv(filename, awsep)
  local lines = {}
  local sep = awsep or ';'
  local result = _newdataset()

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
    result = result + nl
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
  setmetatable(line, _line_meta)
  table.insert(dataset.data, line)
end

function daddkey(data, keys, key, func)
  local afunc = func or function() return '' end

  for _,line in ipairs(data) do
    line[key] = afunc(line)
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
    result = result + {[key]= k, ['count']=v}
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
    print(v)
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

function dgroupwalk(dataset, func)
	local rt = _newdataset()
	local key = dataset.groupkey
	if not key then return rt end
	
	for _,v in dataset:lines() do
		rt = rt + {[key] = v[key], [GROUPFUNCTION] = func(v[key], v[GROUPSTAMP])}
	end

	if dataset.timefield and dataset.timeformat then
		rt:settimestamp(dataset.timefield, dataset.timeformat)
	end
	return rt
end

function dgroupaddkey(dataset, key, func)
	local gkey = dataset.groupkey
	if not gkey then return dataset end

	for _,v in dataset:lines() do
		v[key] = func(v[GROUPSTAMP])
	end
	table.insert(dataset.keys, key)
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
    result = result + {[pkey]=k, [fname]= f(v)}
  end

  -- sorting
  result:sort(function(a, b) return a[fname] and b[fname] and a[fname] > b[fname] end)
  return result
end

function dtimechart(dataset, key, group, func, span)
  local rt = {}
  local f = func or module.count
  local fname = string.format('f(%s)', key)

  -- collecting
  for _, line in ipairs(dataset.data) do
    local sp = _getspan(line, span)
    if rt[sp] then
      if group and rt[sp][line[group]] then
        table.insert(rt[sp][line[group]], line[key])
      elseif group then
        rt[sp][line[group]] = {line[key]}
      else
        table.insert(rt[sp], line[key])
      end
    else
      if group then
				local idx = line[group] or 'nil'
        rt[sp] = {[idx]={line[key]}}
       else 
        rt[sp] = {line[key]}
      end
    end 
  end

  -- processing
  local result = _newdataset()
  if group then
    for k1,v1 in pairs(rt) do
      newline = {[span]=k1}
      for k2,v2 in pairs(v1) do
        newline[string.format('%s(%s)',key, k2)] = f(v2)
      end
      result = result + newline
    end
  else
    for k,v in pairs(rt) do
       result = result + {[span]=k, [string.format('f(%s)', key)]= f(v)}
    end
  end

  -- timestamping and sorting
  result:settimestamp(span, SPAN[span]) 
  return result
end

function dtimegroup(dataset, span, ...)
  local rt = _newdataset()
	local collect = {}
	local key = '#'..span
  -- collecting
  for _, line in dataset:lines() do
		local sp = _getspan(line, span)
    if sp and collect[sp] then
      collect[sp] = collect[sp] + line
    elseif sp then
      collect[sp] = _newdataset()
      collect[sp] = collect[sp] + line
    end 
  end

	-- create dataset
	for k,v in pairs(collect) do
		rt = rt + {[key] = k, [GROUPSTAMP] = v}
	end

  -- timestamping and sorting
	if dataset.timefield and dataset.timeformat then
		for _,gl in rt:lines() do
			local g = gl[GROUPSTAMP]
    	g:settimestamp(dataset.timefield, dataset.timeformat)
  	end
	end

	rt:settimestamp(key, SPAN[span])
	rt.groupkey = key 

	-- subgrouping
	if #{...} > 0 then
		for _,gline in rt:lines() do
			gline[GROUPSTAMP] = dgroup(gline[GROUPSTAMP], ...)
		end
	end
  return rt
end

function dgroup(dataset, ...)
  local rt = _newdataset()
	local collect = {}
	local keys = {...}
	local key = keys[1]
	if not key then return rt end

  -- collecting
  for _, line in dataset:lines() do
    local sp = line[key]
    if sp and collect[sp] then
      collect[sp] = collect[sp] + line
    elseif sp then
      collect[sp] = _newdataset()
      collect[sp] = collect[sp] + line
    end 
  end

	-- create dataset
	for k,v in pairs(collect) do
		rt = rt + {[key] = k, [GROUPSTAMP] = v}
	end

  -- timestamping and sorting
	if dataset.timefield and dataset.timeformat then
		for _,gl in rt:lines() do
			local g = gl[GROUPSTAMP]
    	g:settimestamp(dataset.timefield, dataset.timeformat)
  	end
	end

	-- set groupkey
	rt.groupkey = key

	-- Recursively fill groups
	if #keys > 1 then
		table.remove(keys, 1)
		for _,gline in rt:lines() do
			gline[GROUPSTAMP] = dgroup(gline[GROUPSTAMP], unpack(keys))
		end
	end

  return rt
end

function dsearch(dataset, values)
  local data = dataset.data
  local result = _newdataset()
  local f, count = 1,0
  
  for i = f,#data,1 do
      local found = true
      for k,v in pairs(values) do
        if data[i][k] ~= v then
          found = false;break
        end
      end
      if found then
        result = result + data[i]
        if limit and count == limit then break end
      end
  end
  return result
end

function dselect(data, func)
  local f = func or function(l) return true end 
  local result = _newdataset()

  for _,line in ipairs(data) do
    if f(line) then result = result + line end
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
