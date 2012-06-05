Bitfield = require '../src/bitfield'
assert = require 'assert'

# make a bitfield with 500 pieces
bits = new Bitfield(500)

assert.equal 63, bits.bits.length
assert.equal 500, bits.pieces

# make sure it has nothing to start
assert bits.hasNone()
for i in [0...500]
    assert.equal bits.has(i), false

# test add
for i in [0...500] when i % 7 is 0
    bits.add(i)
    
assert.equal bits.trueCount, 72
assert.equal bits.hasAll(), false
assert.equal bits.hasNone(), false
for i in [0...500]
    assert.equal bits.has(i), i % 7 is 0

# test addAll
bits.addAll()
assert bits.hasAll()
assert.equal bits.hasNone(), false
for i in [0...500]
    assert bits.has(i)
    
# test remove
for i in [0...500] when i % 7 is 0
    bits.remove(i)

assert.equal bits.trueCount, 428
assert.equal bits.hasAll(), false
assert.equal bits.hasNone(), false
for i in [0...500]
    assert.equal bits.has(i), i % 7 isnt 0
    
# test removeAll
bits.removeAll()
assert bits.hasNone()
assert.equal bits.hasAll(), false
for i in [0...500]
    assert.equal bits.has(i), false
    
# test set
other = new Bitfield(500)
for i in [0...500] when i % 7 is 0
    other.add(i)
    
bits.set(other.bits)

assert.equal bits.trueCount, 72
assert.equal bits.hasAll(), false
assert.equal bits.hasNone(), false
for i in [0...500]
    assert.equal bits.has(i), i % 7 is 0
    
# test set by boolean flags
arr = []
for i in [0...500]
    arr[i] = i % 7 is 0

bits.set(arr)

assert.equal bits.trueCount, 72
assert.equal bits.hasAll(), false
assert.equal bits.hasNone(), false
for i in [0...500]
    assert.equal bits.has(i), i % 7 is 0