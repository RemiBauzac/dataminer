miner = require('dataminer')
require('sample')

function Test_load()
  local csv = miner.new('sample.csv', 'csv', ',')
  if csv ~= sample_miner then error('Error in CSV loading') end
end

function Test_modified_load()
  local csv = miner.new('sample.csv', 'csv', ',')
  local l = csv:first()
  csv:remove(l)
  if csv == sample_miner then error('Error in CSV loading') end
end
