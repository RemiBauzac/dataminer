miner = require('dataminer')
require('sample')

function Test_last()
  local csv = miner.new('sample.csv', 'csv', ',')
  local csvl = csv:last()
  local samplel = sample_table[#sample_table]

  setmetatable(samplel, getmetatable(csvl))

  if csvl ~= samplel then
    error(string.format('Error in getting last miner line'))
  end 
end
