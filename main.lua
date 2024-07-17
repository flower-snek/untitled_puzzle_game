--[[ XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

TODO LIST:
- ~~"damage" in whatever form i choose (frozen blocks? clearing adjacent unfreezes, clearing with them inside removes, can't rotate?)~~ done
- menuing
- alternate damage idea (block is directly sent over - how are combos treated?
  - refactor locked pieces to allow multiple locks on one piece? (+ graphics)
- ~~time trial modes?~~ kinda done
  - leaderboards?
- survival mode?

- multiplayer vs???

XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX ]]--

require("enum")
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
fonts = {}
score = 0
game_active = false

cur_screen = Screen.MAIN_MENU
-- keys = {}

function love.load()
	math.randomseed(os.time())
	load_graphics()
	-- init_time_trial(60)
	-- init_board(BOARD_SIZE)
	
	fonts.TITLE = love.graphics.newFont(36)
	fonts.DEFAULT = love.graphics.newFont(18)
end

function love.update(dt)
	if cur_screen == Screen.TIME_TRIAL then
		if game_active then
			update_board(dt)
			game_active = time_trial_active()
		end
	end
end

function love.draw()
	local w = love.graphics.getWidth()
	local h = love.graphics.getHeight()
	
	love.graphics.print("FPS: " .. love.timer.getFPS(), 0, 0)
	if cur_screen == Screen.MAIN_MENU then
		local title_text = "INSERT NAME HERE" -- i really should figure out a name
		local title_w = fonts.TITLE:getWidth(title_text)
		love.graphics.print(title_text, fonts.TITLE, (w - title_w)/2, h/4)
		
		menu_button("Press enter", fonts.DEFAULT, w/3, h/2 - 15, w/3, 30, {1, 1, 1}, {.8, .6, .8}, {.4, .2, .4}, true)
		
		love.graphics.setColor(1, 1, 1)
	elseif cur_screen == Screen.TIME_TRIAL then
		draw_board(w/2, h/2)
		-- todo center these ig
		local r_time = get_remaining_time()
		if game_active then
			love.graphics.print(string.format("Time left: %.2f", get_remaining_time()), w/2, h*7/8 - 15)
		else
			love.graphics.print("Time's up!", w/2, h*7/8 - 15)
		end
		love.graphics.print("Score: " .. score, w/2, h*7/8)
	end
end

function love.keypressed(key)
	if cur_screen == Screen.TIME_TRIAL then
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
				game_active = true
			end
		end
		
		-- todo remove
		if key == "p" then
			deal_damage(10)
		end
	end
	if cur_screen == Screen.MAIN_MENU then
		-- temp
		if key == "return" then
			cur_screen = Screen.TIME_TRIAL
			init_time_trial(60)
			game_active = true
		end
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



function menu_button(text, font, x, y, w, h, rgb_text, rgb_unselected, rgb_selected, selected)
	local box_col = rgb_unselected
	if selected then
		box_col = rgb_selected
	end
	love.graphics.setColor(box_col[1], box_col[2], box_col[3])
	love.graphics.rectangle("fill", x, y, w, h)
	local txt_w = font:getWidth(text)
	local txt_h = font:getHeight(text)
	love.graphics.setColor(rgb_text[1], rgb_text[2], rgb_text[3])
	love.graphics.print(text, font, x + w/2 - txt_w/2, y + h/2 - txt_h/2)
end