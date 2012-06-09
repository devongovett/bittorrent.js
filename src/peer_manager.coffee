Request = require './request'

class PeerManager
    REQUEST_TIMEOUT = 120 * 1000
    CLEAR_INTERVAL = 10 * 1000
    
    constructor: (@torrent) ->
        @pieces = []
        @peers = []
        @requests = []
        
    inEndgame: ->
        # we consider ourselves to be in endgame if the number of bytes
        # we've got requested is >= the number of bytes left to download
        return @requests.length * @torrent.blockSize >= @torrent.remaining()
        
    requestsForBlock: (block) ->
        req for req in @requests when req.index is block
        
    sortByWeight: (a, b) ->
        
        
    makeRequestsTo: (peer, want) ->
        return unless peer.shouldDownload() and want > 0
        
        # walk through the pieces and find blocks that should be requested
        got = 0
        
        # TODO: pieceListRebuild
        @pieces.sort @sortByWeight
        
        # updateEndgame
        
        for i in [0...@torrent.pieces]
            piece = @pieces[i]
            
            # if the peer has this piece that we want...
            if peer.bitfield.has(piece.index)
                [start, end] = @torrent.blockRangeFor(piece.block)
                
                for block in [first..last]
                    # don't request blocks we've already got
                    continue if @torrent.hasBlock(block)
                    
                    # always add peer if this block has no peers yet
                    requests = @requestsForBlock block
                    if requests > 0
                        # don't make a second block request until the endgame
                        continue unless @inEndgame()
                        
                        # don't have more than two peers requesting this block
                        continue if requests.length > 1
                        
                        # don't send the same request to the same peer twice
                        continue if peer is requests[0].peer
                        
                        # in the endgame allow an additional peer to download a
                        # block but only if the peer seems to be handling requests
                        # relatively fast
                        continue if peer.pendingRequests + want - got < @torrent.endgame
                    
                    request = new Request(peer, block, @torrent.blockSize * block, @torrent.blockSize)
                    @requests.push request
                    request.send()
                    got++
            
            break if got >= want
        
        if got > 0
            @pieces.sort @sortByWeight
            
        return got
        
    cancelOldRequests: =>
        now = Date.now()
        tooOld = now - REQUEST_TIMEOUT
        
        keep = []
        for request, i in @requests
            if request.sentAt <= tooOld and not @peer.reading(request.block)
                request.cancel()
                @peer.pendingRequests--
            else
                keep.push(request)
                
        @requests = keep
        setTimeout @cancelOldRequests, CANCEL_INTERVAL