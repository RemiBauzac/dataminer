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

function Test_load_error()
  local csv, err = pcall(miner.new, 'sample_error.csv', 'csv', ',')
  if not err:find('CSV parsing error at line 3, column 5') then
    error('Error in CSV loading, errror awaited')
  end
end
