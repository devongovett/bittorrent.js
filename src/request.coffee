class Request
    constructor: (@peer, @block, @offset, @length) ->
        @torrent = @peer.torrent
        @sentAt = null
    
    reject: ->
        
    send: ->
        message = new Buffer(17)
        
        message.writeUInt32BE(0, 13)
        message[4] = REQUEST
        message.writeUInt32BE(5, @block)
        message.writeUInt32BE(9, @offset)
        message.writeUInt32BE(13, @length)
        
        @peer.send message
        
        @sentAt = Date.now()
        @peer.pendingRequests++
        
    cancel: ->
        message = new Buffer(17)
        
        message.writeUInt32BE(0, 13)
        message[4] = CANCEL
        message.writeUInt32BE(5, @block)
        message.writeUInt32BE(9, @offset)
        message.writeUInt32BE(13, @length)
        
        @peer.send message
        @peer.pendingRequests--