net = require 'net'

class Peer
    CHOKE = 0
    UNCHOKE = 1
    INTERESTED = 2
    NOT_INTERESTED = 3
    HAVE = 4
    BITFIELD = 5
    REQUEST = 6
    PIECE = 7
    CANCEL = 8
    PORT = 9
    
    constructor: (@address, @port) ->
        @chocking = true        # peer is choking this client
        @interested = false     # peer is interested in this client
        
        @am_choking = true      # this client is choking the peer
        @am_interested = false  # the client is interested in the peer
        
        # TODO: use same peer_id as tracker
        @peer_id = new Buffer('2d4e4a303030312d502180e9bf7f000081660a2e', 'hex')
        
    shouldDownload: ->
        @am_interested and not @choking
        
    shouldUpload: ->
        @interested and not @am_choking
        
    connect: ->
        @client = net.connect @port, @address, =>
            @connected = true
            @handshake()
            
        @client.on 'data', @message
        @client.on 'end', => console.log 'ended'
        
    handshake: ->
        return @connect() unless @connected
        
        message = new Buffer(68)
        message[0] = 19
        message.write('BitTorrent protocol', 1, 'ascii')
        message.fill(0, 20, 28) # reserved
        @data.info_hash.copy(message, 28)
        @peer_id.copy(message, 48)
        
        @handshaking = true
        @send message
        
    handleHandshake: (msg) ->
        if msg[0] isnt 19 or msg.toString('ascii', 1, 20) isnt 'BitTorrent protocol'
            console.log "Invalid handshake."
            return @client.destroy()
            
        info_hash = msg.slice(28, 48)
        peer_id = msg.slice(48, 68)
        
        @handshaking = false
        if msg.length > 68
            return msg.slice(68)
            
        return null
        
    send: (message) ->
        @client.write message, 'binary'
        
    message: (msg) =>
        if @handshaking
            msg = @handleHandshake msg
            
        return unless msg?
        
        # TODO: use bufferlist class instead to avoid allocations and copies
        if @buffer?
            buf = new Buffer(@buffer.length + msg.length)
            @buffer.copy(buf, 0, 0)
            msg.copy(buf, @buffer.length, 0)
            @buffer = buf
        else
            @buffer = msg
        
        msg = @buffer
        len = msg.readUInt32BE(0)
        
        return if msg.length < 4 + len       
        return if len is 0 # keep alive TODO: timeout in 2 mins
        
        switch msg[4]
            when CHOKE
                console.log 'choke'
                
            when UNCHOKE
                console.log 'unchoke'
                
            when INTERESTED
                console.log 'interested'
                
            when NOT_INTERESTED
                console.log 'not interested'
                
            when HAVE
                piece = msg.readUInt32BE(5)
                console.log 'have', piece
                
            when BITFIELD
                data = msg.slice(5, 5 + len - 1)
                console.log 'bitfield', data
                
            when REQUEST
                piece = msg.readUInt32BE(5)
                begin = msg.readUInt32BE(9)
                length = msg.readUInt32BE(13)
                console.log 'request', piece, begin, end
                
            when PIECE
                piece = msg.readUInt32BE(5)
                begin = msg.readUInt32BE(9)
                data = msg.slice(12, 12 + len - 9)
                console.log 'piece', piece, begin, data
                
            when CANCEL
                piece = msg.readUInt32BE(5)
                begin = msg.readUInt32BE(9)
                length = msg.readUInt32BE(13)
                console.log 'cancel', piece, begin, end
                
            when PORT
                port = stream.readUInt16BE(5)
                console.log 'port', port
            
            else
                throw new Error "Unknown message."
        
        if msg.length is len + 4
            @buffer = null
        else
            @buffer = msg.slice(len + 4)
            @message null
                
module.exports = Peer