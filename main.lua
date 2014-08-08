require 'SICK'
require 'helpers'
Gamestate = require 'gamestate'

-- Size of a block
HEIGHT = 22
WIDTH  = 10
GRAVITY = true
SPEED = 75 -- base speed  (actual depends on score)
SIZE = 0   -- determined dynamically (in game:enter)
DOWN-MOD = 5 -- speed modifier when down arrow is pressed

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
    SIZE = math.floor(math.max( love.graphics.getHeight()/(HEIGHT+2),
                                love.graphics.getWidth() /(WIDTH+2)))

    score = 0
    field = {}
    just_collided = false

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
    dtotal = dtotal + dt

    if dtotal > 100/(SPEED+score) then
        dtotal = dtotal - 100/(SPEED+score)

        local next_block = table.deepcopy(active_block)

        for _, i in pairs(next_block) do
             i[1] = i[1] + 1
        end

        if game:isColliding(next_block) then
            for _, i in pairs(active_block) do
                field[i[1]][i[2]] = 1
            end
            game:spawn()
        else
            active_block = next_block
            block_y = block_y + 1
        end
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

    if GRAVITY then
        for y=y, 2, -1 do
            for x=1, WIDTH do
                field[y][x] = field[y-1][x]
            end
        end
    end

    score = score + 1
end

function game:isColliding(block)
    for _, i in ipairs(block) do
        if i[1] > HEIGHT or field[i[1]][i[2]] == 1 or
           i[2] > WIDTH or i[2] <= 0 then
            just_collided = true
            break
        end
    end

    return just_collided
end

function game:move(x, y)
    block = table.deepcopy(active_block)

    for _, i in ipairs(block) do
        i[2] = i[2] + x
    end

    if not game:isColliding(block) then
        active_block = block
        block_x = block_x + x
    end
end

function game:rotate(active_block)
    local n = #blocks[1]
    local temp = table.empty(n, n)
    local block = table.empty(n, n)

    -- make temp square from active_block
    for _, i in pairs(active_block) do
        temp[i[1]-block_y][i[2]-block_x] = 1
    end

    -- rotate square by 90 degrees
    for i=1, n do
        for j=1, n do
            block[j][n-i+1] = temp[i][j]
        end 
    end

    local rotated_block = {}
    for i=1, n do
        for j=1, n do
            if block[i][j] == 1 then
                table.insert(rotated_block, {i+block_y, j+block_x})
            end
        end
    end

    return rotated_block
end

function game:keypressed(key, code)
    if key == 'down' then
        SPEED = SPEED * DOWN-MOD
    elseif key == 'right' then
        game:move(1, 0)
    elseif key == 'left' then
        game:move(-1, 0)
    elseif key == 'up' then
        rotated_block = game:rotate(active_block)

        if not game:isColliding(rotated_block) then
            active_block = rotated_block
        end

        -- DEBUG
        table.twoDprint(block)
    end
end

function game:keyreleased(key, code)
    if key == 'down' then
        SPEED = SPEED / DOWN-MOD
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
    love.graphics.rectangle('line', SIZE/2, SIZE/2,
                            WIDTH*SIZE+SIZE, HEIGHT*SIZE+SIZE)
    
    -- Draw active block
    love.graphics.setColor(0, 127, 255)
    if just_collided then
        love.graphics.setColor(255, 0, 0)
        just_collided = false
    end
    for _, i in pairs(active_block) do
        love.graphics.rectangle('fill', i[2]*SIZE, i[1]*SIZE, SIZE, SIZE)
    end

    -- Draw score
    love.graphics.print('Score: ' .. score, 10, 700)
end

function love.quit()
    highscore.save()
end
