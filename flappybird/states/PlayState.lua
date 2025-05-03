--[[
    PlayState Class
    Author: Colton Ogden
    cogden@cs50.harvard.edu

    The PlayState class is the bulk of the game, where the player actually controls the bird and
    avoids pipes. When the player collides with a pipe, we should go to the GameOver state, where
    we then go back to the main menu.
]]

PlayState = Class{__includes = BaseState}

PIPE_SPEED = 60
PIPE_WIDTH = 70
PIPE_HEIGHT = 288

BIRD_WIDTH = 38
BIRD_HEIGHT = 24

heightVariation = 20
levelChanger = 0

spawnGap = 2
spawnGapDecrementer = 0
spawnGapTimer = 0

isPaused = false

function PlayState:init()
    self.bird = Bird()
    self.pipePairs = {}
    self.timer = 0
    self.score = 0

    -- initialize our last recorded Y value for a gap placement to base other gaps off of
    self.lastY = -PIPE_HEIGHT + math.random(80) + 20

    isPaused = false
end

function PlayState:update(dt)
    levelChanger = levelChanger + dt
    spawnGapTimer = spawnGapTimer + dt

    if love.keyboard.wasPressed('p') then
        isPaused = not isPaused
    end

    if isPaused == false then
        if spawnGapTimer>15 then
            spawnGapDecrementer = math.min(spawnGapDecrementer + 0.2, 1)
            spawnGapTimer = 0
        end
        spawnGap = math.max(spawnGap - spawnGapDecrementer, 1.25)
    
        if levelChanger > 15 then
            heightVariation = math.min(heightVariation + 5, 50)
            levelChanger = 0
        end 
    
        -- update timer for pipe spawning
        self.timer = self.timer + dt
    
        -- spawn a new pipe pair every second and a half
        if self.timer > spawnGap then
            -- modify the last Y coordinate we placed so pipe gaps aren't too far apart
            -- no higher than 10 pixels below the top edge of the screen,
            -- and no lower than a gap length (90 pixels) from the bottom
            local y = math.max(-PIPE_HEIGHT + 10, 
                math.min(self.lastY + math.random(-heightVariation, heightVariation), VIRTUAL_HEIGHT - 90 - PIPE_HEIGHT))
            self.lastY = y
    
            -- add a new pipe pair at the end of the screen at our new Y
            table.insert(self.pipePairs, PipePair(y))
    
            -- reset timer
            self.timer = 0
        end
    
        -- for every pair of pipes..
        for k, pair in pairs(self.pipePairs) do
            -- score a point if the pipe has gone past the bird to the left all the way
            -- be sure to ignore it if it's already been scored
            if not pair.scored then
                if pair.x + PIPE_WIDTH < self.bird.x then
                    self.score = self.score + 1
                    pair.scored = true
                    sounds['score']:play()
                end
            end
    
            -- update position of pair
            pair:update(dt)
        end
    
        -- we need this second loop, rather than deleting in the previous loop, because
        -- modifying the table in-place without explicit keys will result in skipping the
        -- next pipe, since all implicit keys (numerical indices) are automatically shifted
        -- down after a table removal
        for k, pair in pairs(self.pipePairs) do
            if pair.remove then
                table.remove(self.pipePairs, k)
            end
        end
    
        -- simple collision between bird and all pipes in pairs
        for k, pair in pairs(self.pipePairs) do
            for l, pipe in pairs(pair.pipes) do
                if self.bird:collides(pipe) then
                    sounds['explosion']:play()
                    sounds['hurt']:play()
    
                    gStateMachine:change('score', {
                        score = self.score
                    })
                end
            end
        end
    
        -- update bird based on gravity and input
        self.bird:update(dt)
    
        -- reset if we get to the ground
        if self.bird.y > VIRTUAL_HEIGHT - 15 then
            sounds['explosion']:play()
            sounds['hurt']:play()
    
            gStateMachine:change('score', {
                score = self.score
            })
        end
    end
end

function PlayState:render()

    if self.score>=10 then
        love.graphics.setColor(205/255, 127/255, 50/255, 1)
    elseif self.score>=6 then
        love.graphics.setColor(192/255, 192/255, 1)
    elseif self.score>=3 then
        love.graphics.setColor(255/255, 215/255, 0/255, 1)
    end

    love.graphics.rectangle("fill", VIRTUAL_WIDTH-30, 30, 20, 20)

    love.graphics.setColor(1, 1, 1, 1)
    
    for k, pair in pairs(self.pipePairs) do
        pair:render()
    end

    love.graphics.setFont(flappyFont)
    love.graphics.print('Score: ' .. tostring(self.score), 8, 8)

    self.bird:render()

    if isPaused == true then
        love.graphics.rectangle("fill", VIRTUAL_WIDTH/2 -10, VIRTUAL_HEIGHT/2 -20, 5, 40)
        love.graphics.rectangle("fill", VIRTUAL_WIDTH/2 +10, VIRTUAL_HEIGHT/2 -20, 5, 40)

        love.graphics.setFont(hugeFont)
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT/4, VIRTUAL_WIDTH, "center")
    end
end

--[[
    Called when this state is transitioned to from another state.
]]
function PlayState:enter()
    -- if we're coming from death, restart scrolling
    scrolling = true
end

--[[
    Called when this state changes to another state.
]]
function PlayState:exit()
    -- stop scrolling for the death/score screen
    scrolling = false
end