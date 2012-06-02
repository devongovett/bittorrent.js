assert = require 'assert'
bencode = require '../src/bencode'

# decode
assert.equal bencode.decode('4:spam'), 'spam'
assert.equal bencode.decode('9:spam:alot'), 'spam:alot'
assert.equal bencode.decode('0:'), ''
assert.equal bencode.decode('i3e'), 3
assert.equal bencode.decode('i-3e'), -3
assert.deepEqual bencode.decode('l4:spam4:eggse'), ['spam', 'eggs']
assert.deepEqual bencode.decode('d3:cow3:moo4:spam4:eggse'), { cow: "moo", spam: "eggs" }
assert.deepEqual bencode.decode('d4:spaml1:a1:bee'), { spam: [ "a", "b" ] }
assert.deepEqual bencode.decode('d9:publisher3:bob17:publisher-webpage15:www.example.com18:publisher.location4:homee'), 
    { "publisher": "bob", "publisher-webpage": "www.example.com", "publisher.location": "home" }
    
assert.throws -> bencode.decode('z23e')
    
# encode
assert.equal '4:spam', bencode.encode('spam')
assert.equal '9:spam:alot', bencode.encode('spam:alot')
assert.equal 'i3e', bencode.encode(3)
assert.equal 'i300e', bencode.encode(300)
assert.equal 'l4:spam4:eggse', bencode.encode(['spam', 'eggs'])
assert.equal 'd3:cow3:moo4:spam4:eggse', bencode.encode({ cow: "moo", spam: "eggs" })
assert.equal 'd4:spaml1:a1:bee', bencode.encode({ spam: [ "a", "b" ] })
assert.equal 'd9:publisher3:bob17:publisher-webpage15:www.example.com18:publisher.location4:homee', 
    bencode.encode { "publisher": "bob", "publisher-webpage": "www.example.com", "publisher.location": "home" }
    
assert.throws -> bencode.encode(null)
assert.throws -> bencode.encode(undefined)
assert.throws -> bencode.encode(/regexp/)
assert.throws -> bencode.encode(true)
assert.throws -> bencode.encode(false)