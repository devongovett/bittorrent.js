fs = require 'fs'
crypto = require 'crypto'
bencode = require './bencode'
File = require './file'

class Torrent
    @fromFile: (filename) ->
        data = fs.readFileSync filename, 'binary'
        return new Torrent bencode.decode(data)
        
    @fromMagnet: (link) ->
        throw new Error "TODO: magnet link support"
        
    constructor: (data) ->
        info = data.info
        @infoHash = crypto.createHash('sha1').update(bencode.encode(info)).digest('hex')
        @pieceLength = info['piece length']
        @pieces = info.pieces.length / 20
        @files = []
        
        # multi-file mode
        if info.files?
            for file in info.files
                @files.push new File(info.name, file)
       
        # single-file mode         
        else
            @files.push new File info.name,
                length: info.length
                md5sum: info.md5sum
                
