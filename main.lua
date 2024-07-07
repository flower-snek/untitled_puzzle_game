--[[ XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

TODO LIST:
- "damage" in whatever form i choose (frozen blocks? clearing adjacent unfreezes, clearing with them inside removes, can't rotate?)
- menuing
- ~~time trial modes?~~ kinda done
  - leaderboards?
- survival mode?

- multiplayer vs???

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX ]]--

require("board")
require("ease")
require("time_trial")

-- CONSTANTS (todo move to another file)
TILE_SIZE = 32
BOARD_SIZE = 10
ROTATE_FRAMES = 8
FALL_FRAME_DATA = {10, 5, 4, 3, 3, 3, 3, 2, 2, 2, 2, 2} -- infinite 1s
CLEAR_LINGER_FRAMES = 60
CLEAR_SOLID_FRAMES = 15 -- todo implement?

DEBUG = false


-- GLOBALS
gfx = {}
score = 0
game_active = true
-- keys = {}

function love.load()
	math.randomseed(os.time())
	load_graphics()
	init_time_trial(60)
	-- init_board(BOARD_SIZE)
end

function love.update(dt)
	if game_active then
		update_board(dt)
	end
	game_active = time_trial_active()
end

function love.draw()
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	draw_board(w/2, h/2)
	love.graphics.print("FPS: " .. love.timer.getFPS(), 0, 0)
	-- todo center these ig
	local r_time = get_remaining_time()
	if game_active then
		love.graphics.print(string.format("Time left: %.2f", get_remaining_time()), w/2, h*7/8 - 15)
	else
		love.graphics.print("Time's up!", w/2, h*7/8 - 15)
	end
	love.graphics.print("Score: " .. score, w/2, h*7/8)
end

function love.keypressed(key)
	if game_active then
		if key == "left" then
			move_cursor(-1, 0)
		end
		if key == "right" then
			move_cursor(1, 0)
		end
		if key == "down" then
			move_cursor(0, 1)
		end
		if key == "up" then
			move_cursor(0, -1)
		end
		if key == "x" then
			rotate_at_cursor(1)
		end
		if key == "z" then
			rotate_at_cursor(-1)
		end
		if key == "c" then
			rotate_at_cursor(0)
		end
	else
		if key == "r" then
			score = 0
			init_time_trial(60)
		end
	end
	
	
	if key == "p" then
		deal_damage(10)
	end
	--[[
	if DEBUG then
		local out = find_all_squares()
		-- print("{")
		for i = 1,#out do
			print("    {"..out[i][1]..","..out[i][2]..","..out[i][3]..","..out[i][4].."}")
		end
		-- print("}")
	end
	]]
end

function load_graphics()
	gfx.grid_img = love.graphics.newImage("gfx/grid.png")
    gfx.tile_imgs = {}
	for i = 1,3 do
		gfx.tile_imgs[i] = love.graphics.newImage("gfx/tile"..i..".png")
	end
	gfx.clear_imgs = {}
	local directions = {"UL", "UR", "DL", "DR", "U", "L", "R", "D"}
	for i = 1,3 do
		gfx.clear_imgs[i] = {}
		for d = 1,#directions do
			local dir = directions[d]
			gfx.clear_imgs[i][dir] = love.graphics.newImage("gfx/tile"..i.."_clear"..dir..".png")
		end
	end
	gfx.cursor = love.graphics.newImage("gfx/cursor.png")
	gfx.tile_lock = love.graphics.newImage("gfx/locked.png")
end