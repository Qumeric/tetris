require 'SICK'
require 'TEsound'
require 'helpers'
Gamestate = require 'gamestate'

-- Size of a block
HEIGHT = 22
WIDTH  = 10
GRAVITY = true
SPEED = 100 -- base speed  (actual depends on score)
SIZE = 0   -- determined dynamically (in game:enter)
DROPTIME = 0.5 -- is seconds. Very high values ignored

local menu = {}
local game = {}

bs = 0 -- size of a block. Set in game:spawn()

-- Super Rotation System
blocks = {{{0, 0, 0, 0}, {1, 1, 1, 1}, {0, 0, 0, 0}, {0, 0, 0, 0}},
          {{1, 0, 0}, {1, 1, 1}, {0, 0, 0}},
          {{0, 0, 1}, {1, 1, 1}, {0, 0, 0}},
          {{1, 1}, {1, 1}}, -- FIXME not SRS (Wontfix?)
          {{0, 1, 1}, {1, 1, 0}, {0, 0, 0}},
          {{0, 1, 0}, {1, 1, 1}, {0, 0, 0}},
          {{1, 1, 0}, {0, 1, 1}, {0, 0, 0}}}

function love.update()
    TEsound.cleanup()
end

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
    game:spawn()
end

dtotal = 0
function game:update(dt)
    dtotal = dtotal + dt
    local maxtotal = 100/(SPEED+score)

    local move_result = game:move(0, 1)

    if love.keyboard.isDown('down') then
        active_block = move_result.block
    end

    if dtotal > math.min(DROPTIME, maxtotal) and move_result.collision == true then
        for _, i in ipairs(active_block) do
            field[i[1]][i[2]] = 1
        end
        TEsound.play('sounds/fall.wav')
        game:spawn()
    end

    if dtotal > maxtotal then
        dtotal = dtotal - maxtotal

        if not move_result.collision then
            active_block = move_result.block
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

    TEsound.play('sounds/destroy.wav')
    score = score + 1
end

function game:isColliding(block)
    just_collided = false
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
        i[1] = i[1] + y
    end

    block['x'] = active_block['x'] + x
    block['y'] = active_block['y'] + y

    if game:isColliding(block) then
        return {block = active_block, collision = true}
    else
        return {block = block, collision = false}
    end
end

function game:rotate(active_block)
    local temp = table.empty(bs, bs)
    local block = table.empty(bs, bs)

    -- make temp square from active_block
    for _, i in ipairs(active_block) do
        temp[i[1]-active_block['y']][i[2]-active_block['x']] = 1
    end

    -- rotate square by 90 degrees
    for i=1, bs do
        for j=1, bs do
            block[j][bs-i+1] = temp[i][j]
        end 
    end

    local rotated_block = {}
    rotated_block['x'] = active_block['x']
    rotated_block['y'] = active_block['y']
    for i=1, bs do
        for j=1, bs do
            if block[i][j] == 1 then
                table.insert(rotated_block, {i+active_block['y'], j+active_block['x']})
            end
        end
    end

    return rotated_block
end

function game:keypressed(key, code)
    if key == 'right' then
        active_block = game:move(1, 0).block
    elseif key == 'left' then
        active_block = game:move(-1, 0).block
    elseif key == 'up' then
        rotated_block = game:rotate(active_block)

        if not game:isColliding(rotated_block) then
            active_block = rotated_block
        end
    end
end

function game:spawn()
    active_block = {}
    active_block['x'] = 3
    active_block['y'] = 0
 
    block = blocks[math.random(1, #blocks)]
    bs = #block
    
    for i=1, #block do
        for j=1, #block do
            if block[i][j] == 1 then
                if field[i][j+3] == 1 then
                    Gamestate.switch(menu)
                else
                    table.insert(active_block, {i, j+3})
                end
            end
        end
    end
end

function game:leave()
    highscore.add('player', score)
    score = 0
    TEsound.play('sounds/game_over.wav')
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

    -- Draw active block
    love.graphics.setColor(0, 127, 255)
    if just_collided then
        love.graphics.setColor(255, 0, 0)
        just_collided = false
    end
    for _, i in ipairs(active_block) do
        love.graphics.rectangle('fill', i[2]*SIZE, i[1]*SIZE, SIZE, SIZE)
    end

    -- Draw frame
    love.graphics.setColor(200, 255, 225)
    love.graphics.setLineWidth(SIZE)
    love.graphics.rectangle('line', SIZE/2, SIZE/2,
                            WIDTH*SIZE+SIZE, HEIGHT*SIZE+SIZE)
    love.graphics.rectangle('line', SIZE*1.5, SIZE*1.5,
                            WIDTH*SIZE-SIZE, SIZE)

    -- Draw score
    love.graphics.setColor(55, 0, 0)
    love.graphics.print('Score: ' .. score, 10, 700)
end

function love.quit()
    highscore.save()
end
