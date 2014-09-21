package.path = package.path..';../lib/?.lua'

require('newcsv')
require('size')
require('first')
require('last')
require('addkey')
test = require('test')

test.run()
