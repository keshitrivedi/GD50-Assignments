--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]

decFlag = false
incFlag = false

function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ballList = params.ballList
    self.level = params.level

    self.recoverPoints = 5000

    self.powerup = false
    self.powerupActive = false

    -- give ball random starting velocity
    for k, balls in pairs(self.ballList) do
        balls.dx = math.random(-200, 200)
        balls.dy = math.random(-50, -60)
    end
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    for k, balls in pairs(self.ballList) do
        balls:update(dt)

        if balls:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            balls.y = self.paddle.y - 8
            balls.dy = -balls.dy
    
            --
            -- tweak angle of bounce based on where it hits the paddle
            --
    
            -- if we hit the paddle on its left side while moving left...
            if balls.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                balls.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - balls.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif balls.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                balls.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - balls.x))
            end
    
            gSounds['paddle-hit']:play()
        end
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do
        for b, balls in pairs(self.ballList) do

            -- only check collision if we're in play
            if brick.inPlay and balls:collides(brick) then

                -- add to score
                self.score = self.score + (brick.tier * 200 + brick.color * 25)

                -- trigger the brick's hit function, which removes it from play
                brick:hit()

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)
                    incFlag = true

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ballList = self.ballList,
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if balls.x + 2 < brick.x and balls.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    balls.dx = -balls.dx
                    balls.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif balls.x + 6 > brick.x + brick.width and balls.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    balls.dx = -balls.dx
                    balls.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif balls.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    balls.dy = -balls.dy
                    balls.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    balls.dy = -balls.dy
                    balls.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(balls.dy) < 150 then
                    balls.dy = balls.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    for k, balls in pairs(self.ballList) do
        if balls.y >= VIRTUAL_HEIGHT then
            self.health = self.health - 1
            gSounds['hurt']:play()
            decFlag = true
    
            if self.health == 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            else
                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints
                })
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('p') then
        self.powerup = not self.powerup
    
        if self.powerup and not self.powerupActive then
            for i = 1, 2 do
                local ball = Ball()
                ball.skin = math.random(7)
                ball.x = self.paddle.x + (self.paddle.width / 2) - 4
                ball.y = self.paddle.y - 8
                ball.dx = math.random(-200, 200)
                ball.dy = math.random(-50, -60)
                table.insert(self.ballList, ball)
            end
            self.powerupActive = true
        elseif not self.powerup then
            while #self.ballList > 1 do
                table.remove(self.ballList)
            end
            self.powerupActive = false
        end
    end    

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for k, balls in pairs(self.ballList) do
        balls:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end

    if self.score >= 100 then
        love.graphics.draw(gTextures['main'], gFrames['icons'][5], 64, 0)
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end