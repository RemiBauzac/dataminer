miner = require('dataminer')
require('sample')

local newKey = 'newKey'
local delKey = 'Score'

function Test_delKey()
  local csv = miner.new('sample.csv', 'csv', ',')

  csv:delkey(delKey)
  for k, v in csv:lines() do
    if v['Score'] ~= nil then
      error(string.format('Key %s is not deleted at line %d', delKey, k))
    end
  end
end

function Test_delKeyAfterAdd()
  local csv = miner.new('sample.csv', 'csv', ',')
  csv:addkey(newKey)
  for k,v in csv:lines() do
    if v[newKey] ~= '' then
      error(string.format('The value of the new key %s must be empty string at line %d',
        newKey, k))
    end
  end
  csv:delkey(newKey)
  if csv ~= sample_miner then error('Error deleting key after insert') end
end

function Test_delBadKey()
  local csv = miner.new('sample.csv', 'csv', ',')
  _,err = pcall(csv.delkey, csv, 10)
  if not err:find('k awaited type is string insteadof number') then
    error('Error on adding bad key error handling ('..err..')')
  end
end
