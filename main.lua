require 'SICK'
require 'TEsound'
require 'helpers'
-- HUMP
Gamestate = require 'gamestate'
Timer = require 'timer'

HEIGHT = 22
WIDTH  = 10
GRAVITY = true
DROP_TIME = 0.5 -- in seconds. Very high values ignored
DOWN_SENS = 25

local menu = {}
local game = {}

-- Each block must be non-empty square
blocks = {{{0, 0, 0, 0}, {1, 1, 1, 1}, {0, 0, 0, 0}, {0, 0, 0, 0}, color={0, 255, 255}},
          {{1, 0, 0}, {1, 1, 1}, {0, 0, 0}, color={0, 0, 255}},
          {{0, 0, 1}, {1, 1, 1}, {0, 0, 0}, color={255, 127, 0}},
          {{1, 1}, {1, 1}, color={255, 255, 0}},
          {{0, 1, 1}, {1, 1, 0}, {0, 0, 0}, color={0, 255, 0}},
          {{0, 1, 0}, {1, 1, 1}, {0, 0, 0}, color={127, 0, 255}},
          {{1, 1, 0}, {0, 1, 1}, {0, 0, 0}, color={255, 0, 0}}}

-- blocks = {{{0, 0, 0, 0}, {1, 1, 1, 1}, {0, 0, 0, 0}, {0, 0, 0, 0}}}

levels = {}

for i=1, 15.5, 0.5 do
    table.insert(levels, {speed = i, score_needed = (i-1) * i * 120})
end

function love.update(dt)
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
    math.randomseed(os.time())

    SIZE = math.floor(math.max( love.graphics.getHeight()/(HEIGHT+2),
                                love.graphics.getWidth() /(WIDTH+2)))
    score = 0
    rows_destroyed = 0
    current_level = 0

    field = table.empty(WIDTH, HEIGHT)

    fall_timer = Timer.new()
    freeze_timer = Timer.new()
    softdrop_timer = Timer.new()

    softdrop_timer:addPeriodic(1/DOWN_SENS, function() game:softDrop() end)

    game:spawn()
end

function game:softDrop()
    local move_result = game:move(0, 1)
    if love.keyboard.isDown('down') then
        active_block = move_result.block
        if not move_result.collision then
            score = score + 1
        end
    end
end

function game:hardDrop()
    while true do
        local move_result = game:move(0, 1)
        if move_result.collision then
            break
        else
            active_block = move_result.block
            score = score + 2
        end
    end
end

function game:update(dt)
    local move_result = game:move(0, 1)

    function _freeze()
        freeze_timer_running = false
        if move_result.collision then
            for _, i in ipairs(active_block) do
                field[i[1]][i[2]] = active_block.color
            end
            TEsound.play('sounds/fall.wav')

            local full_rows = game:fullrows()
            if #full_rows > 0 then game:destroy(full_rows) end

            game:spawn()
        end
    end

    function _fall()
        if not love.keyboard.isDown('down') then
            active_block = move_result.block
        end
    end

    if move_result.collision and not freeze_timer_running then
        freeze_timer:add(DROP_TIME, function() _freeze() end)
        freeze_timer_running = true
    end

    if current_level < #levels and score >= levels[current_level+1].score_needed  then
        if current_level > 0 then TEsound.play('sounds/level_up.wav') end
        current_level = current_level + 1
        fall_timer:clear()
        fall_timer:addPeriodic(1/levels[current_level].speed, function() _fall() end)
    end

    fall_timer:update(dt)
    freeze_timer:update(dt)
    softdrop_timer:update(dt)
end

function game:fullrows()
    local rows = {}
    for y=HEIGHT, 1, -1 do
        for x=1, WIDTH do
            if field[y][x] == 0 then break end
            if x == WIDTH then table.insert(rows, y) end
        end
    end
    return rows
end

function game:destroy(rows)
    for _, y in ipairs(rows) do
        for x=1, WIDTH do
            field[y][x] = 0
        end
    end

    if GRAVITY then
        for i = #rows, 1, -1 do
            for y=rows[i], 2, -1 do
                for x=1, WIDTH do
                    field[y][x] = field[y-1][x]
                end
            end
        end
    end

    TEsound.play('sounds/destroy.wav')
    score = score + (#rows * (#rows + 1) * 5) * (current_level - 1)
    rows_destroyed = rows_destroyed + #rows
end

function game:isColliding(block)
    for _, i in ipairs(block) do
        if i[1] > HEIGHT or field[i[1]][i[2]] ~= 0 or
           i[2] > WIDTH or i[2] <= 0 then
            return true
        end
    end

    return false
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
    local new_block = table.deepcopy(active_block)

    for _, i in ipairs(new_block) do
        i[2], i[1] = i[1] - new_block.y + new_block.x,
                     bs - i[2] + new_block.x + 1 + new_block.y
    end

    return new_block
end


function game:keypressed(key, code)
    if key == 'space' then
        game:hardDrop()
    elseif key == 'right' then
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
 
    block = next_block and next_block or blocks[math.random(1, #blocks)]

    next_block = blocks[math.random(1, #blocks)]
    bs = #block

    active_block.color = block.color
    
    for i=1, #block do
        for j=1, #block do
            if block[i][j] == 1 then
                table.insert(active_block, {i, j+3})
            end
        end
    end

    for col=1, WIDTH do
        if field[1][col] ~= 0 then
            Gamestate.switch(menu)
        end
    end

    for i=1, HEIGHT do
      for j=1, WIDTH do
        io.write(field[i][j] ~= 0 and 1 or 0)
      end
      io.write('\n')
    end
end

function game:leave()
    highscore.add('player', score)
    score = 0
    TEsound.play('sounds/game_over.wav')
end


function game:draw()
    -- Draw active block
    love.graphics.setColor(255, 255, 255)
    for _, i in ipairs(active_block) do
        love.graphics.rectangle('fill', i[2]*SIZE, (i[1]-2)*SIZE, SIZE, SIZE)
    end


    -- Draw field
    for i=1, HEIGHT do
        for j=1, 10 do
            if field[i][j] ~= 0 then
                love.graphics.setColor(unpack(field[i][j]))
                love.graphics.rectangle('fill', j*SIZE, (i-2)*SIZE, SIZE, SIZE)
            end
        end
    end

    -- Draw tetrion
    love.graphics.setColor(next_block.color)
    love.graphics.setLineWidth(SIZE)
    love.graphics.rectangle('line', SIZE/2, SIZE/2,
                            WIDTH*SIZE+SIZE, HEIGHT*SIZE-SIZE)

    -- Draw info
    love.graphics.setColor(0, 0, 0)
    love.graphics.print('Score: ' .. score, 55, SIZE*(HEIGHT-0.6))
    love.graphics.print('Level: ' .. current_level, 50 + SIZE*4, SIZE*(HEIGHT-0.6))
    love.graphics.print('Rows: '  .. rows_destroyed, 42 + SIZE*8, SIZE*(HEIGHT-0.6))
end

function love.quit()
    highscore.save()
end
