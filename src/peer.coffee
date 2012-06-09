net = require 'net'
Bitfield = require './bitfield'
{EventEmitter} = require 'events'

class Peer extends EventEmitter
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
    
    constructor: (@torrent, @address, @port) ->
        @clientIsChoked = true       # peer is choking this client
        @peerIsInterested = false    # peer is interested in this client
        
        @peerIsChoked = true         # this client is choking the peer
        @clientIsInterested = false  # the client is interested in the peer
        
        # TODO: use same peer_id as tracker
        @peer_id = @torrent.peer_id#new Buffer('2d4e4a303030312d502180e9bf7f000081660a2e', 'hex')
        @bitfield = new Bitfield(973)
        
        @connected = false
        @progress = 0.0 # percentage of the torrent this peer has
        @seedProbability = 0
        
        @requests = [] # requests that this peer has made
        @pendingRequests = 0
        
    shouldDownload: ->
        @clientIsInterested and not @clientIsChoked
        
    shouldUpload: ->
        @peerIsInterested and not @peerIsChoked
        
    isSeed: ->
        @seedProbability is 100
        
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
            @emit 'error', 'Invalid handshake.'
            return @client.destroy()
            
        info_hash = msg.slice(28, 48)
        peer_id = msg.slice(48, 68)
        
        @handshaking = false
        @emit 'handshakeComplete'
        
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
                @clientIsChoked = true
                @emit 'choke'
                
            when UNCHOKE
                @clientIsChoked = false
                @emit 'unchoke'
                
            when INTERESTED
                @peerIsInterested = true
                @emit 'interested'
                
            when NOT_INTERESTED
                @peerIsInterested = false
                @emit 'notInterested'
                
            when HAVE
                piece = msg.readUInt32BE(5)
                unless @bitfield.has(piece)
                    @bitfield.add(piece) # TODO: check piece < pieces
                    @emit 'have', piece
                    
                @updateProgress()
                
            when BITFIELD
                data = msg.slice(5, 5 + len - 1)
                @bitfield.set(data)
                @emit 'bitfield', @bitfield
                @updateProgress()
                
            when REQUEST
                piece = msg.readUInt32BE(5)
                begin = msg.readUInt32BE(9)
                length = msg.readUInt32BE(13)
                @emit 'request', piece, begin, end
                
            when PIECE
                piece = msg.readUInt32BE(5)
                begin = msg.readUInt32BE(9)
                data = msg.slice(12, 12 + len - 9)
                @emit 'piece', piece, begin, data
                
            when CANCEL
                piece = msg.readUInt32BE(5)
                begin = msg.readUInt32BE(9)
                length = msg.readUInt32BE(13)
                @emit 'cancel', piece, begin, end
                
            when PORT
                port = stream.readUInt16BE(5)
                @emit 'port', port
            
            else
                throw new Error "Unknown message."
        
        if msg.length is len + 4
            @buffer = null
        else
            @buffer = msg.slice(len + 4)
            @message null
            
    updateProgress: ->
        if @bitfield.hasAll()
            @progress = 1.0
            
        else if @bitfield.hasNone()
            @progress = 0.0
            
        else
            # TODO: if no metadata...
            @progress = @bitfield.trueCount / @torrent.pieces
            
    sendHave: (piece) ->
        message = new Buffer(9)
        message.writeUInt32BE(0, 5)
        message[4] = HAVE
        message.writeUInt32BE(5, piece)
        @send message
        
    sendChoke: (choked) ->
        message = new Buffer(5)
        message.writeUInt32BE(0, 1)
        message[4] = if choked then CHOKE else UNCHOKE
        @send message
        
    sendReject: (index, offset, length) ->
        # ext??
        
    sendBitfield: (bitfield) ->
        message = new Buffer(5 + bitfield.bits.length)
        message.writeUInt32BE(0, 1 + bitfield.bits.length)
        message[4] = BITFIELD
        bitfield.bits.copy(message, 5)
        @send message
        
module.exports = Peer