function reduce(fn, arr, start)
    result = start
    for i,v in ipairs(arr) do
        if start == nil then
            start = v
            result = v
        else
            result = fn(result, v)
        end
    end
    return result
end

function _pack(...) return arg end

function evaluate(s)
	local f, err, status, res

    f,err = loadstring('_last_repl_result = _pack('..s..')')

    if err ~= nil then
        f, err = loadstring(s)
    end

    if f then
        _last_repl_result = nil
        status, err = pcall(f)
        if not status then
            return err
        else
            res = _last_repl_result
        end
        if res and #res > 0 then
            return reduce(function(a,b) return a..'; '..b end, res)
        end
    else
        return err
    end
end
