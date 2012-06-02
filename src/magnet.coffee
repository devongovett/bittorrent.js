querystring = require 'querystring'

exports.parse = (link) ->
    if link.slice(0, 8) isnt 'magnet:?'
        throw new Error "Invalid magnet link."
        
    data = querystring.parse link.slice(8)
    if not data.xt?
        throw new Error "Missing hash."
        
    if data.xt.slice(0, 9) isnt 'urn:btih:'
        throw new Error "Unknown hash URN type."
        
    info = {}
    if data.ws?
        info['url-list'] = if Array.isArray(data.ws) then data.ws else [data.ws]
    
    info['magnet-info'] = { info_hash: data.xt.slice(9) }
    if data.dn?
        info['magnet-info']['display-name'] = data.dn
    
    if data.tr?    
        if typeof data.tr is 'string'
            info.announce = data.tr
        else
            info['announce-list'] = data.tr
        
    return info