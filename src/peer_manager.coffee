Request = require './request'
{EventEmitter} = require 'events'

#
#  REQUESTS
#
# There are two data structures associated with managing block requests:
#
# 1. Torrent::requests, an array of "struct block_request" which keeps
#    track of which blocks have been requested, and when, and by which peers.
#    This is list is used for (a) cancelling requests that have been pending
#    for too long and (b) avoiding duplicate requests before endgame.
#
# 2. Torrent::pieces, an array of "struct weighted_piece" which lists the
#    pieces that we want to request. It's used to decide which blocks to
#    return next when tr_peerMgrGetBlockRequests() is called.
#

class PeerManager extends EventEmitter
    REQUEST_TIMEOUT = 120 * 1000
    CLEAR_INTERVAL = 10 * 1000
    
    constructor: (@torrent) ->
        @pieces = @torrent.pieces.slice()   # pieces we want to request (start with all of them)
        @requests = []                      # pending requests, sent and recieved
        @peers = []                         # peers we know about
        
    inEndgame: ->
        # we consider ourselves to be in endgame if the number of bytes
        # we've got requested is >= the number of bytes left to download
        return @requests.length * @torrent.blockSize >= @torrent.remaining()
        
    requestsForBlock: (block) ->
        req for req in @requests when req.block is block
        
    sortByWeight: (a, b) ->
        # primary key: weight
        ia = a.weight()
        ib = b.weight()
        return -1 if ia < ib
        return +1 if ia > ib
        
        # secondary key: higher priorities go first
        # TODO: file priorities
        
        # tertiary key: rarest first
        ia = a.peerCount
        ib = b.peerCount
        return -1 if ia < ib
        return +1 if ia > ib
        
        # quaternary key: random
        ia = Math.random() * 1000 | 0
        ib = Math.random() * 1000 | 0
        return -1 if ia < ib
        return +1 if ia > ib
        
        # okay, they're equal
        return 0
        
    makeRequestsTo: (peer, want) ->
        return unless peer.shouldDownload() and want > 0
        
        # walk through the pieces and find blocks that should be requested
        got = 0
        
        @pieces.sort @sortByWeight
        # updateEndgame
        
        for piece in @torrent.pieces
            # if the peer has this piece that we want...
            if peer.has(piece.index)
                [start, end] = @torrent.blockRangeFor(piece.index)
                
                for block in [start..end]                    
                    # don't request blocks we've already got
                    continue if @torrent.hasBlock(block)
                    
                    # always add peer if this block has no peers yet
                    requests = @requestsForBlock block
                    if requests > 0
                        # don't make a second block request until the endgame
                        continue unless @torrent.endgame
                        
                        # don't have more than two peers requesting this block
                        continue if requests.length > 1
                        
                        # don't send the same request to the same peer twice
                        continue if peer is requests[0].peer
                        
                        # in the endgame allow an additional peer to download a block but
                        # only if the peer seems to be handling requests relatively fast
                        continue if peer.pendingRequests + want - got < @torrent.endgame
                    
                    request = new Request(peer, block, @torrent.blockSize * block, @torrent.blockSize)
                    @requests.push request
                    request.send()
                    
                    break if ++got >= want
            
            break if got >= want
        
        if got > 0
            @pieces.sort @sortByWeight
            
        return got
        
    cancelOldRequests: =>
        now = Date.now()
        tooOld = now - REQUEST_TIMEOUT
        
        keep = []
        for request, i in @requests
            if request.sentAt <= tooOld and not request.peer.reading(request.block)
                request.cancel()
            else
                keep.push(request)
                
        @requests = keep
        setTimeout @cancelOldRequests, CANCEL_INTERVAL
        
    declineAll: (peer) ->
        # peer choked us, or maybe it disconnected.
        # either way we need to remove all its requests
        keep = []
        for request in @requests
            if request.peer is peer
                peer.pendingRequests--
                idx = @torrent.pieceIndex(request.block)
                @torrent.pieces[idx].requestCount--
            else
                keep.push request
                
        @requests = keep
        
    setupEvents: (peer) ->
        # peer.on 'receive', ->
            # uploaded
            
        peer.on 'have', (piece) =>
            @pieces[piece].peerCount++
            # resort?
            
        peer.on 'bitfield', (bitfield) =>
            for i in [0...@torrent.pieceCount]
                @pieces[i].peerCount++ if bitfield.has(i)
                
            # resort?
            
        # TODO: reject
        
        peer.on 'choke', =>
            @declineAll peer
            
        # peer.on 'port', ->
            
        # peer.on 'error', ->
            
        peer.on 'data', (piece, begin, data) =>
            @torrent.downloaded += data.length
            # TODO: update activity time, stats?
            
            block = @torrent.blockIndex(piece, begin)
            
            if @received_whole_block # TODO
                # remove additional block requests and send cancel to peers
                requests = @requestsForBlock block
                for request in requests
                    unless request.peer is peer
                        request.cancel()
                        
                    @requests.splice @requests.indexOf(request), 1
                    
                if @torrent.hasBlock(block)
                    @torrent.downloaded -= Math.min(@torrent.downloaded, @torrent.blockSize(block))
                    @emit 'error', 'We already have this block'
                    return
                    
                @torrent.blockBitfield.add(block)
                # TODO: resort
                
                if @torrent.completedPiece(piece)
                    unless @torrent.checkPiece(piece)
                        @emit 'error', 'Got bad piece: ' + piece
                        # TODO: blame peer for that
                        # TODO: tell tracker
                        
                        return
                        
                    # TODO: tell tracker we have the piece
                    for peer in @peers
                        peer.sendHave(piece)
                        
                    # TODO: check if file completed