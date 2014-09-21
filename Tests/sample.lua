package.path = package.path..';../lib/?.lua'
miner = require('dataminer')

sample_table = {
{['Name']='Robert',['Age']='18', ['Address']='"32 Duntarvie Avenue, Glasgow, Glasgow G34 9LU"',['Score']='18',['TestDate']='2014/05/12 10:34'},
{['Name']='Philip',['Age']='16',['Address']='"19-20 Chorley Avenue, Birmingham, Midlands de l\'Ouest B34"',['Score']='3.5',['TestDate']='2014/06/18 09:45'},
{['Name']='Jon',['Age']='16',['Address']='"Midleton Road, Guildford, Surrey GU2 8JZ, Royaume-Uni"',['Score']='9',['TestDate']='2014/04/01 12:12'},
{['Name']='Jo',['Age']='14',['Address']='"6A Clifton House Close, Clifton, Shefford, Central Bedfordshire SG17 5EQ, Royaume-Uni"',['Score']='19',['TestDate']='2014/04/01 6:01'},
{['Name']='Bob',['Age']='15',['Address']='"17 Llys Idris, Saint-Asaph, Saint Asaph, Denbighshire LL17, Royaume-Uni"',['Score']='02',['TestDate']='2014/10/10 9:00'},
{['Name']='Gus',['Age']='18',['Address']='"1 Whitecross Lane, Banwell, Somerset du Nord BS29 6DP, Royaume-Uni"',['Score']='12',['TestDate']='2013/11/10 8:00'},
{['Name']='Arlan',['Age']='16',['Address']='"1 Queen Street, Nottingham, Région urbaine de Nottingham NG1 2BL, Royaume-Uni"',['Score']='14',['TestDate']='2013/12/25 0:00'},
{['Name']='Ric',['Age']='15',['Address']='"38 Rushfield Gardens, Bridgend, Bridgend CF31 1DE, Royaume-Uni"',['Score']='1',['TestDate']='2013/12/31 4:00'},
}

sample_miner =  miner.new(sample_table, 'lua')
