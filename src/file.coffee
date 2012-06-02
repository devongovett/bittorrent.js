path = require 'path'

class File
    constructor: (root, info) ->
        @length = info.length
        @md5sum = info.md5sum
        
        info.path ?= []
        @name = path.join(root, info.path...)
    
module.exports = File