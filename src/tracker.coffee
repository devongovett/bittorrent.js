dgram = require 'dgram'
crypto = require 'crypto'
url = require 'url'
Peer = require './peer'

class Tracker
    constructor: (@url) ->
        @interval = 1887
        @seeders = 0
        @leechers = 0
        @connection = null
        
        @peerId = new Buffer('2d4e4a303030312d502180e9bf7f000081660a2e', 'hex')
        # @peerId = new Buffer(20)
        # @peerId.write('-NJ0001-', 0, 'ascii')
        # while @peerId.length < 20
        #     for i in [8...20] by 1
        #         @peerId[i] += Math.floor(Math.random() * 256)
                        
    announce: (info, fn) ->
        info.peerId = @peerId
        
        if @url.slice(0, 6) is 'udp://'
            @udpAnnounce info, fn
            
        else if @url.slice(0, 7) is 'http://'
            @httpAnnounce info, fn
            
        else
            throw new Error "Unknown tracker URL scheme."
            
    udpAnnounce: (info, fn) ->
        if not @connection
            @connection = new UDPConnection(@url)
            
        @connection.announce info, (@interval, @leechers, @seeders, @peers) =>
            fn?()

# see http://xbtt.sourceforge.net/udp_tracker_protocol.html
class UDPConnection
    ACTION_CONNECT = 0
    ACTION_ANNOUNCE = 1
    ACTION_SCRAPE = 2
    ACTION_ERROR = 3
    
    EVENT_NONE = 0
    EVENT_COMPLETED = 1
    EVENT_STARTED = 2
    EVENT_STOPPED = 3
    
    constructor: (loc) ->
        @url = url.parse(loc)
        @connection = dgram.createSocket('udp4')
        @connection.on 'message', @message
        @connection.on 'error', @error
        
    transaction: (fn) ->
        crypto.randomBytes 4, (err, buf) =>
            throw err if err
            @transaction_id = buf.readUInt32BE(0)
            fn?()
        
    send: (message, fn) ->
        @connection.send message, 0, message.length, @url.port or 80, @url.hostname, fn
        
    connect: (fn) ->
        @transaction =>
            message = new Buffer(16)
            
            # initial connection_id (uint64)
            message[0] = 0
            message[1] = 0
            message[2] = 4
            message[3] = 23
            message[4] = 39
            message[5] = 16
            message[6] = 25
            message[7] = 128
            
            message.writeUInt32BE(ACTION_CONNECT, 8)
            message.writeUInt32BE(@transaction_id, 12)
            
            @send message
        
    announce: (data, @announce_callback) ->
        unless @connection_id
            @announce_data = data
            return @connect()
        
        @transaction =>
            message = new Buffer(98)
            
            @connection_id.copy(message, 0, 0, 8)       # connection_id
            message.writeUInt32BE(ACTION_ANNOUNCE, 8)   # announce type
            message.writeUInt32BE(@transaction_id, 12)  # transaction_id
            data.info_hash.copy(message, 16)            # info_hash
            data.peerId.copy(message, 36)              # peerId
            message.fill(0, 56, 64)                     # downloaded
            message.fill(0, 64, 72)                     # left
            message.fill(0, 72, 80)                     # uploaded
            message.writeUInt32BE(EVENT_STARTED, 80)    # event
            message.writeUInt32BE(0, 84)                # ip
            message.writeUInt32BE(0, 88)                # key
            message.writeInt32BE(50, 92)                # num_want
            message.writeUInt16BE(6881, 96)             # port
            
            @send message
        
    message: (msg) =>
        action = msg.readUInt32BE(0)
        transaction_id = msg.readUInt32BE(4)
        
        if @transaction_id isnt transaction_id
            throw new Error "transaction_ids are different."
        
        switch action
            when ACTION_CONNECT
                # no 64 bit integers in JS, so just store it as a buffer
                @connection_id = msg.slice(0, 8)
                
                @announce @announce_data, @announce_callback
                delete @announce_data
                
            when ACTION_ANNOUNCE
                interval = msg.readUInt32BE(8)
                leechers = msg.readUInt32BE(12)
                seeders = msg.readUInt32BE(16)
                peers = []
                
                offset = 20
                n = (msg.length - 20) / 6
                for i in [0...n] by 1
                    address = msg[offset++] + '.' + msg[offset++] + '.' + msg[offset++] + '.' + msg[offset++]
                    port = msg.readUInt16BE(offset)
                    offset += 2
                    peers.push new Peer(address, port)
                
                @announce_callback? interval, leechers, seeders, peers
                delete @announce_callback
                
            when ACTION_ERROR
                err = msg.toString('ascii', 8)
                @connection.close()
                throw new Error(err)
        
    error: (err) =>
        @connection.close()
        throw new Error(err)
        
tracker = new Tracker('udp://tracker.openbittorrent.com:80')
tracker.announce({ 
    info_hash: new Buffer('ab08822b8497dabcf668aa760794fbfe1e57e09f', 'hex')
}, -> console.log tracker.peers)
    
module.exports = Tracker