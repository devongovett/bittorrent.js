class Bencode
    @encode: (obj) ->
        switch Object::toString.call(obj)
            when '[object Number]'
                if (obj | 0) isnt obj
                    throw new Error "Floating point numbers not allowed."
                    
                return 'i' + obj + 'e'
                
            when '[object String]'
                return obj.length + ':' + obj
                
            when '[object Array]'
                ret = 'l'
                for item in obj
                    ret += @encode item
                    
                ret += 'e'
                return ret
                
            when '[object Object]'
                ret = 'd'
                for own key, val of obj
                    ret += @encode(key) + @encode(val)
                    
                ret += 'e'
                return ret
                
            else
                throw new Error 'Unknown type to bencode: ' + Object::toString.call(obj)
                
    @decode: (str) ->
        return new Decoder(str).decode()
    
    class Decoder
        constructor: (@str) ->
            @pos = 0
            
        decode: ->
            switch @str[@pos]
                # lists
                when 'l'
                    list = []
                    @pos++
                    
                    while @str[@pos] isnt 'e'
                        list.push @decode()

                    @pos++    
                    return list

                # dictionaries    
                when 'd'
                    dict = {}
                    @pos++

                    while @str[@pos] isnt 'e'
                        dict[@decode()] = @decode()
                        
                    @pos++
                    return dict

                # ints
                when 'i'
                    @pos++
                    
                    end = @str.indexOf('e', @pos)
                    val = parseInt @str.slice(@pos, end)
                    
                    @pos = end + 1
                    return val

                # strings
                when '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
                    colon = @str.indexOf(':', @pos)
                    len = parseInt @str.slice(@pos, colon)
                    @pos = colon + 1
                    
                    val = @str.slice(@pos, @pos += len)
                    return val
                    
                else
                    throw new Error 'Unknown bencode type to decode: ' + @str[@pos]
                    
module.exports = Bencode