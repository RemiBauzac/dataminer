miner = require('dataminer')
require('sample')

function Test_size()
  local csv = miner.new('sample.csv', 'csv', ',')
  if csv:size() ~= #sample_table then
    error(string.format('Error in data size: %d/%d', csv:size(), #sample_table))
  end 
end

function Test_modified_size()
  local csv = miner.new('sample.csv', 'csv', ',')
  local l = csv:first()
  csv:remove(l)
  if csv:size() ~= #sample_table-1 then
    error(string.format('Error in data size: %d/%d', csv:size(), #sample_table-1))
  end 
end



