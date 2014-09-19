miner = require('dataminer')

function Test_load()
  csv = miner.new('sample.csv', 'csv', ',')
  sample = require('sample')
  if csv ~= sample then error('Error in CSV loading') end
end

function Test_modified_load()
  csv = miner.new('sample.csv', 'csv', ',')
  sample = require('sample')
  l = csv:first()
  csv:remove(l)
  if csv == sample then error('Error in CSV loading') end
end
