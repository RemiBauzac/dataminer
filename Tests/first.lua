miner = require('dataminer')
require('sample')

function Test_first()
  local csv = miner.new('sample.csv', 'csv', ',')
  local csvl = csv:first()
  local samplel = sample_table[1]

  setmetatable(samplel, getmetatable(csvl))

  if csvl ~= samplel then
    error(string.format('Error in getting first miner line'))
  end 
end
