class Piece
    constructor: (@torrent, @index, @hash) ->
        @cache = null
        @length = @torrent.pieceSize(@index)
        @peerCount = 0                      # number of peers that have this piece
        @requestCount = 0                   # number of requests made for this piece
        
    weight: ->
        missing = @torrent.missingBlocksFor @index
        ia = if missing > @requestCount then missing - @requestCount else @torrent.blocksPerPiece + @requestCount