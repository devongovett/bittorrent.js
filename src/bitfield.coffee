class Bitfield
    constructor: (@pieces) ->
        @bits = new Buffer(@pieces / 8)
        @bits.fill(0)
        @trueCount = 0
            
    has: (piece) ->
        return true if @hasAll()
        return false if @hasNone()
        return false unless (piece >> 3) < @pieces
        return (@bits[piece >> 3] << (piece & 7) & 0x80) isnt 0
        
    hasAll: ->
        return @trueCount is @pieces
        
    hasNone: ->
        return @trueCount is 0
        
    add: (piece) ->
        unless @has piece
            @bits[piece >> 3] |= 0x80 >> (piece & 7)
            @trueCount++
            
    remove: (piece) ->
        if @has piece
            @bits[piece >> 3] &= 0xff7f >> (piece & 7)
            @trueCount--
        
    addAll: ->
        @bits.fill(255)
        @trueCount = @pieces
        
    removeAll: ->
        @bits.fill(0)
        @trueCount = 0
        
    TRUE_BIT_COUNT = new Uint8Array([
        0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
        1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
        1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
        2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
        1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
        2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
        2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
        3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
        1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
        2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
        2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
        3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
        2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
        3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
        3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
        4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8
    ])
    
    set: (data) ->        
        if Buffer.isBuffer(data) # bits
            if data.length isnt @bits.length
                throw new Error "Invalid bitfield length."
                
            @bits = data
            @trueCount = 0
            for byte in data
                @trueCount += TRUE_BIT_COUNT[byte]
            
        else if Array.isArray(data) # booleans
            if data.length isnt @pieces
                throw new Error "Invalid bitfield length."
        
            @removeAll()
            for flag, i in data
                @add i if flag
                
        return
        
    countInRange: (start, end) ->
        if @pieces is 0
            return 0
        
        if @hasAll()
            return end - start
            
        if @hasNone()
            return 0
            
        if start is 0 and end is @pieces
            return @trueCount
        
        firstByte = start >> 3
        lastByte = Math.min((end - 1) >> 3, @bits.length)
        
        return 0 if firstByte >= @bits.length
        return 0 if firstByte > lastByte
        
        # first byte
        ret = 0
        val = @bits[firstByte] << (start % 8) & 0xff
        
        if firstByte isnt lastByte
            ret = TRUE_BIT_COUNT[val]
            
            # middle bytes
            for i in [firstByte + 1...lastByte]
                ret += TRUE_BIT_COUNT[@bits[i]]
                
            val = @bits[lastByte]
                
        # last byte
        val >>= (8 - end)        
        ret += TRUE_BIT_COUNT[val]
        
        return ret
            
module.exports = Bitfield