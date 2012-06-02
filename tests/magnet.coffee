assert = require 'assert'
magnet = require '../src/magnet'

# single tracker
link = "magnet:?xt=urn:btih:2I2UAEFDZJFN4W3UE65QSOTCUOEZ744B&dn=Display%20Name&tr=http%3A%2F%2Ftracker.openbittorrent.com%2Fannounce&ws=http%3A%2F%2Fserver.webseed.org%2Fpath%2Fto%2Ffile"
assert.deepEqual magnet.parse(link), 
    'url-list': [ 'http://server.webseed.org/path/to/file' ]
    'magnet-info': 
        info_hash: '2I2UAEFDZJFN4W3UE65QSOTCUOEZ744B'
        'display-name': 'Display Name'
    'announce': 'http://tracker.openbittorrent.com/announce'

# multiple trackers
link = "magnet:?xt=urn:btih:2I2UAEFDZJFN4W3UE65QSOTCUOEZ744B&dn=Display%20Name&tr=http%3A%2F%2Ftracker.openbittorrent.com%2Fannounce&ws=http%3A%2F%2Fserver.webseed.org%2Fpath%2Fto%2Ffile&tr=http%3A%2F%2Ftracker.opentracker.org%2Fannounce"
assert.deepEqual magnet.parse(link), 
    'url-list': [ 'http://server.webseed.org/path/to/file' ]
    'magnet-info': 
        info_hash: '2I2UAEFDZJFN4W3UE65QSOTCUOEZ744B'
        'display-name': 'Display Name'
    'announce-list': [ 'http://tracker.openbittorrent.com/announce', 'http://tracker.opentracker.org/announce' ]

# no trackers or webseeds    
link = 'magnet:?xl=2049966080&dn=The+Avengers+2012+TS+XviD+AC3+ADTRG&xt=urn:btih:A9AC69A718A352DD1F7D8BE2A589391585755716'
assert.deepEqual magnet.parse(link),
    'magnet-info':
        info_hash: 'A9AC69A718A352DD1F7D8BE2A589391585755716'
        'display-name': 'The Avengers 2012 TS XviD AC3 ADTRG'
        
assert.throws -> magnet.parse('http://google.com/')
assert.throws -> magnet.parse('magnet:?foo=bar')
assert.throws -> magnet.parse('magnet:?xt=urn:foo:2I2UAEFDZJFN4W3UE65QSOTCUOEZ744B')