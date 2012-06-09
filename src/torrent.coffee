fs = require 'fs'
crypto = require 'crypto'
{EventEmitter} = require 'events'
bencode = require './bencode'
magnet = require './magnet'
File = require './file'
Tracker = require './tracker'

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
        @requests = []
        
        if data.announce
            @trackers.push new Tracker(data.announce)
            
        if data['announce-list']
            for url in data['announce-list']
                @trackers.push new Tracker(url)
        
        info = data.info
        console.log info
        @infoHash = new Buffer(crypto.createHash('sha1').update(bencode.encode(info)).digest(), 'binary')
        @pieceLength = info['piece length']
        @pieces = info.pieces.length / 20
        @files = []
        
        @totalSize = 0
        @bitfield = new Bitfield(@pieces)
        
        @blockSize = @getBlockSize()
        @blocks = (@totalSize + @blockSize - 1) / @blockSize
        @blockBitfield = new Bitfield(@blocks)
        
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
    getBlockSize: ->
        b = @pieceLength
        
        while b > MAX_BLOCK_SIZE
            b = (b / 2) | 0
            
        if !b or @pieceLength % b
            return 0
            
        return b
        
    pieceSize: (piece) ->
        if piece is @pieces - 1
            return @totalSize % @pieceLength
        else
            return @pieceLength
        
    blockRangeFor: (piece) ->
        offset = @pieceLength * piece
        start = offset / @blockSize
        
        offset += @pieceSize piece
        end = offset / @blockSize
        
        return [start, end]
        
    hasBlock: (block) ->
        return @blockBitfield.has(block)
                
    downloadTo: (@basePath) ->
        
                
