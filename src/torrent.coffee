fs = require 'fs'
crypto = require 'crypto'
{EventEmitter} = require 'events'
bencode = require './bencode'
magnet = require './magnet'
File = require './file'
Tracker = require './tracker'
Bitfield = require './bitfield'

class Torrent extends EventEmitter
    @fromFile: (filename) ->
        data = fs.readFileSync filename, 'binary'
        return new Torrent bencode.decode(data)
        
    @fromMagnet: (link) ->
        return magnet.parse(link)
        # return new Torrent(info)
        
    constructor: (data) ->
        @downloading = false
        @basePath = ''
        
        @trackers = []
        @peers = []
        @files = []
        
        if data.announce
            @trackers.push new Tracker(data.announce)
            
        if data['announce-list']
            for url in data['announce-list']
                @trackers.push new Tracker(url)
        
        info = data.info
        @infoHash = new Buffer(crypto.createHash('sha1').update(bencode.encode(info)).digest(), 'binary')
        
        @pieceLength = info['piece length']
        @pieceCount = info.pieceCount / 20
        @pieces = []
        for i in [0...@pieceCount]
            hash = new Buffer(info.pieces.slice(i * 20, i * 20 + 20), 'binary')
            @pieces[i] = new Piece(this, i, hash)
                
        # stats
        @totalSize = 0
        @downloaded = 0
        @uploaded = 0
        @bitfield = new Bitfield(@pieceCount)
        
        @blockSize = @getBlockSize()
        @blocks = (@totalSize + @blockSize - 1) / @blockSize
        @blockBitfield = new Bitfield(@blocks)
        @blocksPerPiece = @pieceLength / @blockSize
        
        # Before the endgame this should be 0. In endgame, is contains the average
        # number of pending requests per peer. Only peers which have more pending
        # requests are considered 'fast' are allowed to request a block that's
        # already been requested from another (slower?) peer.
        @endgame = 0 
        
        # multi-file mode
        if info.files?
            for file in info.files
                @files.push new File(info.name, file)
                @totalSize += file.length
       
        # single-file mode         
        else
            @files.push new File info.name,
                length: info.length
                md5sum: info.md5sum
    
    ###
    # Decide on a block size. Constraints:
    # (1) most clients decline requests over 16 KiB
    # (2) pieceSize must be a multiple of block size
    ###
    MAX_BLOCK_SIZE = 1024 * 16
    getBlockSize: ->
        b = @pieceLength
        
        while b > MAX_BLOCK_SIZE
            b = (b / 2) | 0
            
        if !b or @pieceLength % b
            return 0
            
        return b
        
    pieceSize: (piece) ->
        if piece is @pieceCount - 1
            return @totalSize % @pieceLength
        else
            return @pieceLength
        
    blockRangeFor: (piece) ->
        offset = @pieceLength * piece
        start = offset / @blockSize
        
        offset += @pieceSize piece
        end = offset / @blockSize
        
        return [start, end]
        
    blockSize: (block) ->
        if block is @blocks - 1
            return @totalSize % @blockSize
        else
            return @blockSize
            
    blockIndex: (piece, offset) ->
        return piece * (@pieceLength / @blockSize) + (offset / @blockSize)
        
    pieceIndex: (block) ->
        return block / @blocksPerPiece
        
    hasBlock: (block) ->
        return @blockBitfield.has(block)
        
    hasPiece: (piece) ->
        return @bitfield.has(piece)
        
    missingBlocksFor: (piece) ->
        if @hasAll()
            return 0
        else
            [start, end] = @blockRangeFor piece
            return (end - start) - @blockBitfield.countInRange(start, end)
        
    completedPiece: (piece) ->
        return @missingBlocksFor(piece) is 0
        
    calculateHashFor: (piece) ->
        # TODO
        
    bufferEquals = (a, b) ->
        return false if a.length isnt b.length
        
        for i in [0...a.length]
            return false if a[i] isnt b[i]
        
        return true
        
    checkPiece: (piece) ->
        pass = bufferEquals @calculateHashFor(piece), @hashes[piece]
        
        # set has piece
        # set piece checked
        return pass
                
    downloadTo: (@basePath) ->
        
                
torrent = Torrent.fromFile '/Users/devongovett/Downloads/test.torrent'
console.log torrent

# torrent.downloadTo()