miner = require('dataminer')
require('sample')

local newKey = 'newKey'

function Test_addEmptyKey()
  local csv = miner.new('sample.csv', 'csv', ',')
  csv:addkey(newKey)
  for k,v in csv:lines() do
    if v[newKey] ~= '' then
      error(string.format('The value of the new key %s must be empty string at line %d',
        newKey, k))
    end
  end
end

function Test_addConstantKey()
  local csv = miner.new('sample.csv', 'csv', ',')
  csv:addkey(newKey, function(l) return newKey end)
  for k,v in csv:lines() do
    if v[newKey] ~= newKey then
      error(string.format('The value of the new key value must be %s instead of %s at line %d',
        newKey, v[newKey], k))
    end
  end
end

function Test_addKey()
  local csv = miner.new('sample.csv', 'csv', ',')
  csv:addkey(newKey, function(l) return miner.tonumber(l['Score']*2) end)
  for k,v in csv:lines() do
    if v[newKey] ~= v['Score']*2 then
      error(string.format('The value of the new key value must be %d instead of %d at line %d',
        v['Score']*2, v[newKey], k))
    end
  end
end

function Test_addBadKey()
  local csv = miner.new('sample.csv', 'csv', ',')
  _,err = pcall(csv.addkey, csv, 10)
  if not err:find('k awaited type is string insteadof number') then
    error('Error on adding bad key error handling ('..err..')')
  end
end

function Test_addKeyBadFunction()
  local csv = miner.new('sample.csv', 'csv', ',')
  _,err = pcall(csv.addkey, csv, newKey, newKey)
  if not err:find('f awaited type is function insteadof string') then
    error('Error on adding key error handling ('..err..')')
  end
end
