require 'SICK'
Gamestate = require 'gamestate'

SPEED = 1

-- Size of a block
SIZE = 30

HEIGHT = 21
WIDTH  = 10

local menu = {}
local game = {}

-- Blocks are squares
blocks = {{{0, 0, 0, 0}, {1, 1, 1, 0}, {1, 0, 0, 0}, {0, 0, 0, 0}},
          {{0, 0, 0, 0}, {1, 1, 1, 1}, {0, 0, 0, 0}, {0, 0, 0, 0}},
          {{0, 0, 0, 0}, {1, 1, 1, 0}, {0, 1, 0, 0}, {0, 0, 0, 0}},
          {{0, 0, 0, 0}, {0, 0, 1, 1}, {0, 1, 1, 0}, {0, 0, 0, 0}},
          {{0, 0, 0, 0}, {1, 1, 0, 0}, {0, 1, 1, 0}, {0, 0, 0, 0}},
          {{0, 0, 0, 0}, {0, 1, 1, 0}, {0, 1, 1, 0}, {0, 0, 0, 0}},
          {{0, 0, 0, 0}, {0, 1, 1, 1}, {0, 0, 0, 1}, {0, 0, 0, 0}}}


function love.load()
    highscore.set('highscores', 10, 'bot', 100)
    Gamestate.registerEvents()
    Gamestate.switch(menu)
end

function menu:draw()
    love.graphics.setColor(255, 255, 255)
    love.graphics.print("Press Enter to continue", 10, 10)

    for i, score, name in highscore() do
        print(name)
        love.graphics.print(name, 50, 50 + i * 30)
        love.graphics.print(score, 200, 50 + i * 30)
    end
end

function menu:keyreleased(key, code)
    if key == 'return' then
        Gamestate.switch(game)
    elseif key == 'escape' then
		love.event.quit()
    end
end

function game:enter()   
    score = 0
    field = {}

    for i=1, HEIGHT do
        field[i] = {}
        for j=1, WIDTH do
            field[i][j] = 0
        end
    end
    
    math.randomseed(os.time())
    game:spawn() -- FIXME
end

dtotal = 0
function game:update(dt)
    floor_encountered = false

    dtotal = dtotal + dt

    if dtotal > 1/SPEED then
        dtotal = dtotal - 1/SPEED

        for _, i in pairs(active_block) do
            if i[1] == HEIGHT or field[i[1]+1][i[2]] == 1 then
                floor_encountered = true
                break
            end
        end

        if floor_encountered then
            for _, i in pairs(active_block) do
                field[i[1]][i[2]] = 1
            end
            game:spawn()
        else
            for _, i in pairs(active_block) do
                i[1] = i[1] + 1
            end
            block_y = block_y + 1
        end
    end

    if love.keyboard.isDown('down') then
        dtotal = dtotal + 1/SPEED
    end

    -- Check for full rows
    for y=HEIGHT, 1, -1 do
        for x=1, WIDTH do
            if field[y][x] == 0 then break end
            if x == WIDTH then game:destroy(y) end
        end
    end
end

function game:destroy(y)
    for x=1, WIDTH do
        field[y][x] = 0
    end

    score = score + 1

    for y=y, 2, -1 do
        for x=1, WIDTH do
            field[y][x] = field[y-1][x]
        end
    end
end

function game:keypressed(key, code)
    function _move(direction)
        local colliding = false
        for _, i in pairs(active_block) do
            if field[i[1]][i[2]+direction] == 1 or
               i[2]+direction == WIDTH+1 or i[2]+direction == 0 then
                colliding = true
                break
            end
        end

        if not colliding then
            for _, i in pairs(active_block) do
                i[2] = i[2] + direction
            end
            block_x = block_x + direction
        end
    end

    if key == 'right' then
        _move(1)
    elseif key == 'left' then
        _move(-1)
    elseif key == 'up' then
        -- FIXME tricky, oh, so tricky
        local n = #blocks[1]
        local f = math.floor(n/2)
        local temp = {}
        local block = {}

        for i=1, n do
            temp[i] = {}
            block[i] = {}
            for j=1, n do
                temp[i][j] = 0
                block[i][j] = 0
            end
        end

        for _, i in pairs(active_block) do
            temp[i[1]-block_y][i[2]-block_x] = 1
        end

        for i=1, n do
            for j=1, n do
                block[j][n-i+1] = temp[i][j]
            end 
        end

        local xshift = 0

        active_block = {}
        for i=1, n do
            for j=1, n do
                local xpos = j+block_x
                if block[i][j] == 1 then
                    table.insert(active_block, {i+block_y, xpos})
                    if xpos < 1 then
                        xshift = math.max(-xpos+1, xshift)
                    elseif xpos > WIDTH then
                        xshift = math.min(WIDTH-xpos, xshift)
                    end
                end
            end
        end

        -- DEBUG
        for i=1, n do
            print()
            for j=1, n do
                io.write(block[i][j])
            end
        end
        print()
        

        print('xshift= ' .. xshift)
        if xshift ~= 0 then
            for k, v in pairs(active_block) do
                v[2] = v[2] + xshift  
            end
            block_x = block_x + xshift
        end
    end
end

function game:spawn()
    block_x = 3
    block_y = 0

    active_block = {}
 
    block = blocks[math.random(1, #blocks)]
    
    for i=1, #block do
        for j=1, #block do
            if block[i][j] == 1 then
                if field[i][j+3] == 1 then
                    highscore.add('player', score)
                    score = 0
                    Gamestate.switch(menu)
                else
                    table.insert(active_block, {i, j+3})
                end
            end
        end
    end
end

function game:draw()
    love.graphics.setColor(255, 255, 255)
   
    -- Draw field
    for i=1, HEIGHT do
        for j=1, 10 do
            if field[i][j] == 1 then
                love.graphics.rectangle('fill', j*SIZE, i*SIZE, SIZE, SIZE)
            end
        end
    end

    -- Draw frame
    love.graphics.setColor(200, 255, 225)
    love.graphics.setLineWidth(SIZE)
    love.graphics.rectangle('line', SIZE/2, SIZE/2, WIDTH*SIZE+SIZE, HEIGHT*SIZE+SIZE)
    
    -- Draw active block
    love.graphics.setColor(0, 127, 255)
    for _, i in pairs(active_block) do
        love.graphics.rectangle('fill', i[2]*SIZE, i[1]*SIZE, SIZE, SIZE)
    end

    -- Draw score
    love.graphics.print('Score: ' .. score, 10, 700)
end

function love.quit()
    highscore.save()
end
