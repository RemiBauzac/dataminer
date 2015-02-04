--
-- Constants
--
local TIMESTAMP='@timestamp'
local GROUPSTAMP='@group'
local GROUPFUNCTION='f(group)'
local DATASET='@DATASET'

local SPAN = {
  ['Year'] = '%Y',
  ['Month'] = '%m/%Y',
  ['Week'] = '%V/%Y',
  ['Day'] = '%d/%m/%Y',
  ['Hour'] = '%d/%m/%Y %H',
  ['Minute'] = '%d/%m/%Y %H:%M',
  ['Second'] = '%d/%m/%Y %H:%M:%S',
  ['%Y'] = 'Year',
  ['%m/%Y'] = 'Month',
  ['%V/%Y'] = 'Week',
  ['%d/%m/%Y'] = 'Day',
  ['%d/%m/%Y %H'] = 'Hour',
  ['%d/%m/%Y %H:%M'] = 'Minute',
  ['%d/%m/%Y %H:%M:%S'] = 'Second'
}

local TIMESP = {
  ['%d'] = 'day',
	['%V'] = 'week',
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
-- XLS export constants
--
local XLS_XML = '<?xml version="1.0" encoding="UTF-8"?>'
local XLS_WB_HEAD = [[<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet" xmlns:html="http://www.w3.org/TR/REC-html40">
<DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">
  <Version>14.0</Version>
</DocumentProperties>
<OfficeDocumentSettings xmlns="urn:schemas-microsoft-com:office:office">
  <AllowPNG/>
</OfficeDocumentSettings>]]
local XLS_WB_TAIL = '</Workbook>'
local XLS_STYLES = '<Styles><Style ss:ID="number"><NumberFormat/></Style></Styles>'
local XLS_WS_HEAD = '<Worksheet ss:Name="%s">'
local XLS_WS_TAIL = '</Worksheet>'
local XLS_T_HEAD = '<Table>'
local XLS_T_TAIL = '</Table>'
local XLS_R_HEAD = '<Row>'
local XLS_R_TAIL = '</Row>'
local XLS_C_HEAD = '<Cell>'
local XLS_CNUM_HEAD = '<Cell ss:StyleID="number">'
local XLS_C_TAIL = '</Cell>'
local XLS_D_HEAD = '<Data ss:Type="%s">'
local XLS_D_TAIL = '</Data>'

--
-- Helpers
--
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
  local match = format:gsub('%%[dmVYyHMS]', function(a)
      table.insert(parser, TIMESP[a]); return '(%d+)' end)
  local timespec = {day=1, month=1, year=1970, hour=0, min=0, sec=0}
  if not str then return os.time(timespec) end
  local dt = {str:match(match)}

  for k, v in ipairs(parser) do
    if v == 'year' then dt[k] = dt[k]+2000 end
    if v == 'Year' then v = 'year' end
		if v == 'week' then v = 'day'; dt[k] = dt[k]*7 end
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
  __index = function(t, i)
    if type(i) == 'number' then
      return t[i]
    else
      local dataset = rawget(t, DATASET)
      local idx = dataset.keyidx[i]
      return t[idx]
    end
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
    if type(k) == 'number' then
		  local data = rawget(t, 'data')
      return data[k]
    end
      return rawget(t, k)
	end,
	__add = function(t, l)
    if #t.keylist ~= #l then
      error('Error inserting line: bad size')
    end
  	setmetatable(l, _line_meta)
  	table.insert(t.data, l)
    l[DATASET] = t
		return t
	end,
	__concat = function(d1, d2)
    -- TODO: check if keylist are the same
		local newname = ''
		if d1._name then newname = newname..d1._name end
		if d2._name then newname = newname..'/'..d2._name end
		local r = _newdataset(newname)
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

function _newdataset(_name, ...)
  -- create initial tables
  local dataset = {}
  setmetatable(dataset, _dataset_meta)
  dataset.data = {}
  dataset.keylist = {...}
  dataset.keyidx = {}
  for idx, k in ipairs(dataset.keylist) do
    dataset.keyidx[k] = idx
  end
  dataset.docs = setmetatable({}, {__mode = "kv"})
  dataset.shortdocs = setmetatable({}, {__mode = "kv"})
	dataset._name = _name

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

  -- OK
	function dataset:name(name)
    _mandatory(name, 'n', 'string')
		self._name = name
		return self
	end
	dataset:doc[[name(n) - set the name of dataset
	- n(string, mandatory): name of the dataset]](dataset.name)

  -- OK
  function dataset:first() return self.data[1] end
  dataset:doc[[first() - return the data set first line]](dataset.first)

  -- OK 
  function dataset:last() return self.data[#self.data] end
  dataset:doc[[last() - return the data set last line]](dataset.last)

  -- OK
  function dataset:addkey(key, func)
    _mandatory(key, 'k', 'string')
    _optional(func, 'f', 'function')
    local idx = #self.keylist+1
    self.keylist[idx] = key
    self.keyidx[key] = idx
    daddkey(self.data, idx, func)
    return self
  end
  dataset:doc[[addkey(k, f) - add a key named 'k' on each line and return the data set
  - k(string, mandatory): name of the key to add
  - f(function, optional): function to compute key, with the current line as parameter.
      If nil, empty string is set for the key on all lines]](dataset.addkey)

  -- OK
  function dataset:delkey(key)
    _mandatory(key, 'k', 'string')
    local idx = self.keyidx[key]
    table.remove(self.keylist, idx)
    self.keyidx[key] = nil
    ddelkey(self, idx)
    return self
  end
  dataset:doc[[delkey(k) - delete the key named 'k' on each line and return the data set
  - k(string, mandatory): name of the key to delete]](dataset.delkey)

  -- OK
  function dataset:distinctcount(key)
    _mandatory(key, 'k', 'string')
    return ddistinct(self, key, self.keyidx[key])
  end
  dataset:doc[[distinct(k) - return a new dataset with all key 'k' distinct values and count
  - k(string, mandatory): name of the key distinct values and count]](dataset.distinctcount)

  -- OK
  function dataset:distinctvalues(key)
    _mandatory(key, 'k', 'string')
    return ddistinctvalues(self, self.keyidx[key])
  end
  dataset:doc[[distinctvalues(k) - return a list with all key 'k' distinct values
  - k(string, mandatory): name of the key distinct values]](dataset.distinctvalues)

  -- OK
  function dataset:replace(key, value, replace)
    _mandatory(key, 'k', 'string')
    _mandatory(value, 'v', 'all')
    _mandatory(replace, 'r', 'all')
    dreplace(self, self.keyidx[key], value, replace)
    return self
  end
  dataset:doc[[replace(k, v, r) - replace the value 'v' of the key 'k' by the new value 'r' on all data set lines and return the data set
  - k(string, mandatory): key of value to replace 
  - v(all, mandatory): value to replace 
  - r(all, mandatory): new value]](dataset.replace)

  -- OK
  function dataset:lines() return ipairs(self.data) end
  dataset:doc[[lines() - return the iterator on data set lines]](dataset.lines)

	function dataset:grouptable()
		local group = {}
		if not self.groupkey then return pairs(group) end
		for _, l in self:lines() do
			group[l[self.groupkey]] = l[GROUPSTAMP]
		end
		return group
	end
  dataset:doc[[glines() - return group as a table]](dataset.grouptable)

  -- OK
  function dataset:keywalk(key, func)
    _mandatory(key, 'k', 'string')
    _optional(func, 'f', 'function')
    return dkeywalk(self, self.keyidx[key], func)
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

  -- OK
  function dataset:print(limit)
    _optional(limit, 'limit', 'number')
    dprint(self, limit);
    return self
  end
  dataset:doc[[print(limit) - print data set lines to the console, according to 'limit'
  - limit(number, optional): limit the number of printed lines]](dataset.print)

  -- OK
  function dataset:keys() return self.keylist end
  dataset:doc[[keys() - print all the keys of the dataset]](dataset.keys)

  -- OK
  function dataset:settimestamp(key, format)
    _mandatory(key, 'k', 'string')
    _mandatory(format, 'fmt', 'string')
    dsettimestamp(self, key, format)
    return self
  end
  dataset:doc[[settimestamp(k, fmt) - use the key 'k' to set dataset timestamp on each lines, according to time format 'fmt' and return the data set
  - k(string, mandatory): key used as timestamp
  - fmt(string, mandatory): time format]](dataset.settimestamp)

  -- OK
  function dataset:sort(param)
    dsort(self, param)
    return self
  end
  dataset:doc[[sort(p) - sort data set with 'p' and return the data set
  - p(function or string, mandatory): sort parameter.
      If p is a function, this function is used as compare function.
      If p is a string, it is used as key to sort by values of this key (number awaited)]](dataset.sort)

  -- OK
  function dataset:timesort()
    table.sort(self.data, function(a, b)
       return a[TIMESTAMP] and b[TIMESTAMP] and a[TIMESTAMP] < b[TIMESTAMP] end)
    return self
  end
  dataset:doc[[timesort() - use timestamp (added with settimestamp) to sort in time order and return data set]](dataset.timesort)

  -- OK
  function dataset:top(pkey, fkey, func)
    _mandatory(pkey, 'k', 'string')
    _mandatory(fkey, 'ck', 'string')
    _optional(func, 'f', 'function')
    return dtop(self, pkey, self.keyidx[pkey],
        string.format('f(%s)',fkey), self.keyidx[fkey], func)
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

  -- OK
  function dataset:select(func)
    _optional(func, 'f', 'function')
    return dselect(self, func)
  end
  dataset:doc[[select(f) - return a dataset with selected lines of function 'f'
  - f(function, optional): function used to select a line. Must return true if the line is selcted 
      If nil, all lines are selected]](dataset.select)

	function dataset:exportkeys(...)
		dataset.userkeys = {...} 
		return self
	end
	dataset:doc[[exportkeys(...) - set the keys to export (for csv or xls)
	- ...: list of keys to export]](dataset.exportkeys)

  function dataset:csv(filename, separator)
    _optional(filename, 'f', 'string')
    _optional(separator, 's', 'string')
    return dexportcsv(self, filename, separator)
  end
  dataset:doc[[csv(f, s) - export data set in csv file, using 's' as separator, and return data set
  - f(string, mandatory): file name to export csv
  - s(string, optional): csv separator. ';' by default
  ]](dataset.csv)

  function dataset:json(filename)
    _optional(filename, 'f', 'string')
    return dexportjson(self, filename)
  end
  dataset:doc[[json(f, s, k) - export data set in json file and return data set
  - f(string, mandatory): file name to export json 
  ]](dataset.json)

	function dataset:xls(filename)
    _optional(filename, 'f', 'string')
    return dexportxls(self, filename)
	end
  dataset:doc[[xls(f, k) - export data set in Excel xls file, and return data set
  - f(string, mandatory): file name to export xls 
  ]](dataset.xls)

	function dataset:xlsws(output)
		return dexportxlsws(self, output)
	end

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
    return _newdataset(source)
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
	if number == nil then return nil end
  local d = dec or 2
 	local fmt = '%.'..tostring(d)..'f'
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

function module.median(t)
	if math.mod(#t, 2) == 0 then
		return (t[#t/2] + t[#t/2+1])/2
	else
		local idx = module.round(#t/2, 0)
		return t[idx]
	end
end

function module.count(t)
  return #t
end

function module.xls(filename, ...)
  output = io.open(filename, 'w')
  if not output then error('Cannot open file '..filename..' for writing') end

	output:write(XLS_XML)
	output:write(XLS_WB_HEAD)
	output:write(XLS_STYLES)
	for _, dataset in ipairs({...}) do
		dataset:xlsws(output)
	end
	output:write(XLS_WB_TAIL)
	output:close()
end

function _newlua(t)
  local result = _newdataset('luaTable')

  for _,v in ipairs(t) do
		result = result + v
  end
  return result
end

function ParseCSVLine (line,sep)
  local res = {}
  local pos = 1
  sep = sep or ','
  while true do 
    local c = string.sub(line,pos,pos)
    if (c == "") then break end
    if (c == '"') then
      -- quoted value (ignore separator within)
      local txt = ""
      repeat
        local startp,endp = string.find(line,'^%b""',pos)
        txt = txt..string.sub(line,startp+1,endp-1)
        pos = endp + 1
        c = string.sub(line,pos,pos) 
        if (c == '"') then txt = txt..'"' end 
        -- check first char AFTER quoted string, if it is another
        -- quoted string without separator, then append it
        -- this is the way to "escape" the quote char in a quote. example:
        --   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
      until (c ~= '"')
      table.insert(res,txt)
      assert(c == sep or c == "")
      pos = pos + 1
    else  
      -- no quotes used, just look for the first separator
      local startp,endp = string.find(line,sep,pos)
      if (startp) then 
        table.insert(res,string.sub(line,pos,startp-1))
        pos = endp + 1
      else
        -- no separator found -> use rest of string and terminate
        table.insert(res,string.sub(line,pos))
        break
      end 
    end
  end
  return res
end

function _newcsv(filename, awsep)
  local lines = {}
  local sep = awsep or ';'
  local result
  keys = {}
  -- Put file lines in a table
  local lnum = 0
  for line in io.lines(filename) do
    local lt = ParseCSVLine(line, sep)
    if lnum == 0 then
      result = _newdataset('csvFile', unpack(lt))
    else
      result = result + lt 
    end
    lnum = lnum + 1
  end
  collectgarbage("collect")
  return result
end

--
-- Data set functions
--

-- OK
function daddkey(data, idx, func)
  local afunc = func or function() return '' end

  for _,line in ipairs(data) do
    line[idx] = afunc(line)
  end
end

-- OK
function ddelkey(dataset, idx)
  local keyidx = 0
  for _,line in dataset:lines() do
    table.remove(line, idx)
  end
  collectgarbage("collect")
end

-- OK
function ddistinct(dataset, key, idx)
  local rt = {}
  for _,line in dataset:lines() do
    local value = rawget(line, idx)
    if rt[value] then
      rt[value] = rt[value] + 1
    else rt[value] = 1 end
  end

  local result = _newdataset('distinctCount', key, 'count')
  for k, v in pairs(rt) do
    result = result + {k, v}
  end
  return result
end

function ddistinctvalues(dataset, idx)
  local rt = {}
  local result = {}

  for _,line in dataset:lines() do
    local value = rawget(line, idx)
    if value and not rt[value] then
      result[#result+1] = value
      rt[value] = true 
    end
  end
  return result
end

-- OK
function dreplace(dataset, idx, value, replace)
  for _,line in dataset:lines() do
    if rawget(line, idx) == value then
      rawset(line, idx, replace)
    end
  end
end

-- OK
function dprint(dataset, limit)
  for _, key in ipairs(dataset.keylist) do
    io.write(string.format('%s; ', key))
  end
  io.write('\n')
  io.flush()
  for count,line in ipairs(dataset.data) do
    if limit and count > limit then break end
    for _, v in ipairs(line) do 
      io.write(string.format('%s; ', v))
    end
    io.write('\n')
    io.flush()
  end
end

-- OK
function dkeywalk(dataset, idx, func)
  local f = func or miner.count
  local rt = {}

  for _,line in dataset:lines() do
    rt[#rt+1] = rawget(line, idx)
  end

  return f(rt)
end

function dgroupwalk(dataset, func)
	local rt = _newdataset('groupWalk')
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

-- OK
function dsettimestamp(dataset, key, format)
  -- Set timestamp
  dataset.timefield = key
  dataset.timeformat = format
  for _, line in dataset:lines() do
    line[TIMESTAMP] = _gettimestamp(line[dataset.keyidx[key]], format)
  end
  dataset:timesort()

  -- Time spanning now
  for _, span in ipairs({'Year', 'Month', 'Week', 'Day', 'Hour', 'Minute', 'Second'}) do
    for _, line in dataset:lines() do
      line[span] = _getspan(line, span)
    end
  end
end

-- OK 
function dsort(dataset, param)
  if type(param) == 'function' then
    table.sort(dataset.data, param)
  elseif type(param) == 'string' then
    local idx = dataset.keyidx[param]
    table.sort(dataset.data, function(a, b)
      return a[idx] and b[idx] and miner.tonumber(a[idx]) <
        miner.tonumber(b[idx])
    end)
  end
end

-- OK
function dtop(dataset, pkey, pidx, fname, fidx, func)
  local rt = {}
  local f = func or module.count

  -- collecting
  for _, line in dataset:lines() do
    local pval = line[pidx]
    if rt[pval] then
      table.insert(rt[pval], line[fidx])
    else
      rt[pval] = {line[fidx]}
    end 
  end

  -- processing
  local result = _newdataset('top', pkey, fname)
  for k,v in pairs(rt) do
    result = result + {k, f(v)}
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
  local result = _newdataset('timeChart')
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

function dgroup(dataset, ...)
  local rt = _newdataset('groupTable')
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
      collect[sp] = _newdataset('group')
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
  local result = _newdataset('search')
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

function dselect(dataset, func)
	local data = dataset.data
  local f = func or function(l) return true end 
  local rt = _newdataset('select', unpack(dataset.keylist))

  for _,line in dataset:lines() do
    if f(line) then rt = rt + line end
  end
	
	if dataset.timefield and dataset.timeformat then
		rt:settimestamp(dataset.timefield, dataset.timeformat)
	end

  return rt
end

function dexportcsv(dataset, filename, separator)
  local sep = separator or ';'
  local ssep = ','
  local ks = {} 
	local exportname = filename or dataset._name..'.csv'

  if sep == ',' then ssep = ';' end

  for _, k in ipairs(dataset.userkeys or dataset:keys()) do
		if type(k) == 'string' and k:sub(1,1) ~= '@' then
     	table.insert(ks, k)
		elseif type(k) == 'table' and type(k[1]) == 'string' and k[1]:sub(1,1) ~= '@' then
     	table.insert(ks, k[1])
		end
  end

  output = io.open(exportname, 'w')
  if not output then error('Cannot open file '..exportname..' for writing') end
  output:write(table.concat(ks, sep)..'\n')

  for _,line in ipairs(dataset.data) do
    local vs = {}
    for _,k in ipairs(ks) do
			table.insert(vs, tostring(line[k]) or '')
    end
    output:write(table.concat(vs, sep)..'\n')
  end
  output:close()
	return dataset
end

function dexportjson(dataset, filename)
	local ks = {}
	local exportname = filename or dataset._name..'.json'

  for _, k in ipairs(dataset.userkeys or dataset:keys()) do
		if type(k) == 'string' and k:sub(1,1) ~= '@' then
     	table.insert(ks, k)
		elseif type(k) == 'table' and type(k[1]) == 'string' and k[1]:sub(1,1) ~= '@' then
     	table.insert(ks, k[1])
		end
  end

  output = io.open(exportname, 'w')
  if not output then error('Cannot open file '..exportname..' for writing') end
	output:write('[') 
	for _,line in ipairs(dataset.data) do
		output:write('{')
		for _,k in ipairs(ks) do
			output:write(string.format('"%s":"%s", ', k, tostring(line[k])))
		end
		output:write('},')
	end
	output:write(']')
  output:close()
	return dataset
end

function dexportxlsws(dataset, output)
  local ssep = ','
  local ks = {}
	output:write(string.format(XLS_WS_HEAD, dataset._name))
	output:write(XLS_T_HEAD)

  for _, k in ipairs(dataset.userkeys or dataset:keys()) do
    if type(k) == 'string' and k:sub(1,1) ~= '@' then
      table.insert(ks, {k, 'string'})
		elseif type(k) == 'table' and type(k[1]) == 'string' and k[1]:sub(1,1) ~= '@' then
			table.insert(ks, k)
    end
  end

	-- keys
	output:write(XLS_R_HEAD)
	for _,k in ipairs(ks) do
		output:write(XLS_C_HEAD)
		output:write(string.format(XLS_D_HEAD, "String"))
		output:write(tostring(k[1]))
		output:write(XLS_D_TAIL)
		output:write(XLS_C_TAIL)
	end
	output:write(XLS_R_TAIL)

  for _,line in ipairs(dataset.data) do
		output:write(XLS_R_HEAD)
    for _,k in ipairs(ks) do
			value = line[k[1]]
			if k[2] == 'string' then
				output:write(XLS_C_HEAD)
				output:write(string.format(XLS_D_HEAD, "String"))
				if value then output:write(tostring(value)) end
			elseif k[2] == 'number' then
				output:write(XLS_CNUM_HEAD)
				output:write(string.format(XLS_D_HEAD, "Number"))
				if value then output:write(string.format('%f', miner.tonumber(value))) end
			end
			output:write(XLS_D_TAIL)
			output:write(XLS_C_TAIL)
		end
		output:write(XLS_R_TAIL)
	end
	output:write(XLS_T_TAIL)
	output:write(XLS_WS_TAIL)
	return dataset
end


function dexportxls(dataset, filename)
	local exportname = filename or dataset._name..'.xls'

  output = io.open(exportname, 'w')
  if not output then error('Cannot open file '..exportname..' for writing') end

	output:write(XLS_XML)
	output:write(XLS_WB_HEAD)
	output:write(XLS_STYLES)
	dataset:xlsws(output)
	output:write(XLS_WB_TAIL)
	output:close()
	return dataset
end



-- exporting module
return module
