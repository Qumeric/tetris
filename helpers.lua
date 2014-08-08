function table.deepcopy(t) -- by github@MihailJP
    if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
        target[k] = table.deepcopy(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
    return target
end

function table.empty(x, y)
    t = {}
    for i=1, y do
        t[i] = {}
        for j=1, x do
            t[i][j] = 0
        end
    end
    return t
end

function table.twoDprint(t)
    for i=1, #t do
        print()
        for j=1, #t[1] do
            io.write(t[i][j])
        end
    end
    print()
end
