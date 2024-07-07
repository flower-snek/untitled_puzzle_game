------------------------------------------------------------



-- i dont like having code up here it feels weird



------------------------------------------------------------

-- handles logic with the board

require("ease")

function init_board(size)
	board = {}
	board.size = size
	board.eases = {}
	board.fall = {}
	board.recent_clears = {}
	board.chain = 0
	
	repeat
		if DEBUG then
			print("generating...")
		end
		for x = 1,size do
			board[x] = {}
			board.eases[x] = {}
			board.fall[x] = {}
			for y = 1,size do
				board[x][y] = math.random(1,3)
				board.fall[x][y] = 0
				board.eases[x][y] = {}
			end
		end
	until(#find_all_squares() == 0)
	cursor = {}
	cursor.x = 1
	cursor.y = 1
end



function pos_from_board(cx, cy, x, y)
	local board_len = board.size * TILE_SIZE
	local px = cx - board_len/2 + ((x-1) * TILE_SIZE)
	local py = cy - board_len/2 + ((y-1) * TILE_SIZE)
	return {px, py}
end

function in_solid_clear(x, y)
	local ans = false
	for i = 1,#board.recent_clears do
		if not ans then
			local rc = board.recent_clears[i]
			if rc.el < CLEAR_SOLID_FRAMES/60 and x >= rc[1] and x < rc[1] + rc[3] and y >= rc[2] and y < rc[2] + rc[4] then
				ans = true
			end
		end
	end
	return ans
end


function draw_board(cx, cy)
	if not board then
		return
	end
	love.graphics.setColor(255, 255, 255, 255)
	-- draw the grid first...
	for x = 1,board.size do
		for y = 1,board.size do
			local p = pos_from_board(cx, cy, x, y)
			love.graphics.draw(gfx.grid_img, p[1], p[2])
		end
	end
	-- (its inefficient but z order matters)
	for x = 1,board.size do
		for y = 1,board.size do
			local n = board[x][y]
			local p = pos_from_board(cx, cy, x, y)
			if n > 0 then
				if board.eases[x][y].slide then
					local ease = board.eases[x][y].slide
					local ease_val = ease.es(0, ease.l, ease.el)
					local ease_dx = (((ease.ex - ease.sx) * ease_val) + ease.sx) * TILE_SIZE
					local ease_dy = (((ease.ey - ease.sy) * ease_val) + ease.sy) * TILE_SIZE
					love.graphics.draw(gfx.tile_imgs[n], p[1] + ease_dx, p[2] + ease_dy)
					if DEBUG then
						love.graphics.print(board.fall[x][y], p[1] + ease_dx, p[2] + ease_dy)
					end
					-- print(ease_dx .. " " .. ease_dy)
				else
					love.graphics.draw(gfx.tile_imgs[n], p[1], p[2])
				end
			end
		end
	end
	-- now the recent clears get to be drawn
	for i = 1,#board.recent_clears do
		local rc = board.recent_clears[i]
		local x = rc[1]
		local y = rc[2]
		local w = rc[3]
		local h = rc[4]
		local el = rc.el
		local col = rc.color
		love.graphics.setColor(1, 1, 1, 1 - ((el - CLEAR_SOLID_FRAMES/60) / ((CLEAR_LINGER_FRAMES - CLEAR_SOLID_FRAMES) / 60)))
		-- draw the corners...
		local p_UL = pos_from_board(cx, cy, x, y)
		-- print(col .. " " .. p_UL[1] .. " " .. p_UL[2])
		love.graphics.draw(gfx.clear_imgs[col]["UL"], p_UL[1], p_UL[2])
		love.graphics.draw(gfx.clear_imgs[col]["UR"], p_UL[1] + (w-1)*TILE_SIZE, p_UL[2])
		love.graphics.draw(gfx.clear_imgs[col]["DL"], p_UL[1], p_UL[2] + (h-1)*TILE_SIZE)
		love.graphics.draw(gfx.clear_imgs[col]["DR"], p_UL[1] + (w-1)*TILE_SIZE, p_UL[2] + (h-1)*TILE_SIZE)
		-- and then the edges...
		for dy = 1,h-2 do
			love.graphics.draw(gfx.clear_imgs[col]["L"], p_UL[1], p_UL[2] + dy*TILE_SIZE)
			love.graphics.draw(gfx.clear_imgs[col]["R"], p_UL[1] + (w-1)*TILE_SIZE, p_UL[2] + dy*TILE_SIZE)
		end
		for dx = 1,w-2 do
			love.graphics.draw(gfx.clear_imgs[col]["U"], p_UL[1] + dx*TILE_SIZE, p_UL[2])
			love.graphics.draw(gfx.clear_imgs[col]["D"], p_UL[1] + dx*TILE_SIZE, p_UL[2] + (h-1)*TILE_SIZE)
		end
	end
	love.graphics.setColor(255, 255, 255, 255)
	local cursor_p = pos_from_board(cx, cy, cursor.x, cursor.y)
	love.graphics.draw(gfx.cursor, cursor_p[1], cursor_p[2])
end



function update_board(dt)
	local falling_at_start = {}
	-- basically my check for chaining is "was it falling before this clear"
	-- since the falling variable gets reset in the gravity loop
	-- and the clear loop happens after the gravity loop
	-- i have to check if it was falling at the start of the update step
	-- (since a check for clearing is that it's not easing, and if it's not easing then it's not falling)
	for x = 1,board.size do
		falling_at_start[x] = {}
		for y = 1,board.size do
			falling_at_start[x][y] = (board.fall[x][y] > 0)
		end
	end
	
	-- gravity loop
	-- (gotta get all these eases set up before eases are updated)
	for x = 1,board.size do
		for y = board.size,1,-1 do -- reverse order for gravity
			if y < board.size then
				if board[x][y] > 0 and board[x][y+1] == 0 and not board.eases[x][y].slide and not in_solid_clear(x, y+1) then
					-- do the thing
					board[x][y+1] = board[x][y]
					board[x][y] = 0
					board.fall[x][y+1] = board.fall[x][y] + 1
					board.fall[x][y] = 0
					add_slide_ease(x, y+1, 0, -1, 0, 0, FALL_FRAME_DATA[board.fall[x][y+1]]/60, linear)
				elseif board[x][y] > 0 and not board.eases[x][y].slide then
					board.fall[x][y] = 0
				end
			elseif not board.eases[x][y].slide then
				board.fall[x][y] = 0
				
			end
			-- and bring in new blocks along the top
			if y == 1 then
				if board[x][y] == 0 and not in_solid_clear(x, y) then
					board[x][y] = math.random(1, 3)
					board.fall[x][y] = board.fall[x][y+1]
					if board.fall[x][y] == 0 then
						board.fall[x][y] = 1 -- i dont think this should ever happen but just in case...
					end
					add_slide_ease(x, y, 0, -1, 0, 0, FALL_FRAME_DATA[board.fall[x][y]]/60, linear)
				end
			end
		end
	end
	-- clear loop (gotta do this after gravity or else one gravity ease will end and the blocks will clear before the next gravity step)
	local out = find_all_squares()
	local change_chain = 0
	local cleared_tiles = 0
	for i = 1,#out do
		local t = out[i]
		-- first check if any of the squares involved are moving/in the middle of a rotation
		local safe_clear = true
		for x = t[1],t[1]+t[3]-1 do
			if safe_clear then -- (slight optimization?)
				for y = t[2],t[2]+t[4]-1 do
					if board.eases[x][y].slide then
						safe_clear = false
					end
				end
			end
		end
		-- if not, then clear
		if safe_clear then
			t.el = 0
			local continues_chain = false
			for x = t[1],t[1]+t[3]-1 do
				for y = t[2],t[2]+t[4]-1 do
					board[x][y] = 0
					board.fall[x][y] = 0
					if falling_at_start[x][y] then
						continues_chain = true
					end
				end
			end
			cleared_tiles = cleared_tiles + ((t[3]-2) * (t[4]-2))
			table.insert(board.recent_clears, t)
			
			-- basically: if this would continue the chain, change_chain = 1 (mark the chain to be incremented);
			-- if not, then set it to -1 (marks the chain to reset at 1), but chain-continues take precendence because thats what panel de pon does and its sick (lets a manual clear at the same time as a chain continue the chain)
			if continues_chain then
				change_chain = 1
			elseif change_chain == 0 then
				change_chain = -1
			end
			
			if DEBUG then
				print("  " .. t[3] .. " x " .. t[4])
			end
		end
	end
	if change_chain == 1 then
		board.chain = board.chain + 1
	elseif change_chain == -1 then
		board.chain = 1
	end
	if cleared_tiles > 0 then
		if DEBUG then
			print(cleared_tiles .. " tiles x (" .. board.chain .. " chain ^ 2) x 100 = " .. (100 * cleared_tiles * math.pow(board.chain, 2)) .. "pts")
		end
		score = score + (100 * cleared_tiles * math.pow(board.chain, 2))
	end
	-- update all eases
	for x = 1,board.size do
		for y = 1,board.size do
			if board.eases[x][y].slide then
				board.eases[x][y].slide.el = board.eases[x][y].slide.el + dt
				
				if board.eases[x][y].slide.el > board.eases[x][y].slide.l then
					board.eases[x][y].slide = nil
				end
			end
		end
	end
	
	-- and update all recent clears
	for i = #board.recent_clears,1,-1 do
		board.recent_clears[i].el = board.recent_clears[i].el + dt
		if board.recent_clears[i].el > CLEAR_LINGER_FRAMES / 60 then
			table.remove(board.recent_clears, i)
		end
	end
	
	-- return cleared_tiles
end



function move_cursor(dx, dy)
	cursor.x = cursor.x + dx
	if cursor.x >= board.size then
		cursor.x = board.size - 1
	elseif cursor.x < 1 then
		cursor.x = 1
	end
	cursor.y = cursor.y + dy
	if cursor.y >= board.size then
		cursor.y = board.size - 1
	elseif cursor.y < 1 then
		cursor.y = 1
	end
end



function rotate_at_cursor(dir)
	local EASE = outCubic
	-- well if any of the four are mid-ease i should probably not do it...
	-- actually, correction: if any of the four are mid-FALL i should probably not do it
	local x = cursor.x
	local y = cursor.y
	if board.fall[x][y] ~= 0 or board.fall[x][y+1] ~= 0 or board.fall[x+1][y+1]  ~= 0 or board.fall[x+1][y]  ~= 0 then
		return
	end
	if dir == 1 then -- clockwise
		local temp = board[x][y]
		board[x][y] = board[x][y+1]
		add_slide_ease(x, y, 0, 1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x][y+1] = board[x+1][y+1]
		add_slide_ease(x, y+1, 1, 0, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y+1] = board[x+1][y]
		add_slide_ease(x+1, y+1, 0, -1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y] = temp
		add_slide_ease(x+1, y, -1, 0, 0, 0, ROTATE_FRAMES/60, EASE)
	elseif dir == -1 then -- ccw
		local temp = board[x][y]
		board[x][y] = board[x+1][y]
		add_slide_ease(x, y, 1, 0, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y] = board[x+1][y+1]
		add_slide_ease(x+1, y, 0, 1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y+1] = board[x][y+1]
		add_slide_ease(x+1, y+1, -1, 0, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x][y+1] = temp
		add_slide_ease(x, y+1, 0, -1, 0, 0, ROTATE_FRAMES/60, EASE)
	else -- y'know what ill add a 180 button at some point
		local temp = board[x][y]
		board[x][y] = board[x+1][y+1]
		add_slide_ease(x, y, 1, 1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y+1] = temp
		add_slide_ease(x+1, y+1, -1, -1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		local temp = board[x][y+1]
		board[x][y+1] = board[x+1][y]
		add_slide_ease(x, y+1, 1, -1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y] = temp
		add_slide_ease(x+1, y, -1, 1, 0, 0, ROTATE_FRAMES/60, EASE)
	end
end



function find_all_squares()
	-- oh god here's the tough one. (note: rather, doing it efficiently would be tough. not doing it in general)
	-- i'm gonna brute force this for now but ill have to think about optimizations.
	-- also to make this run faster i think i am gonna bump the minimum up to 3x3 square
	found_squares = {} -- store as x,y,w,h
	for w = 3,board.size do
		for h = 3,board.size do
			for x = 1,board.size - w + 1 do
				for y = 1,board.size - h + 1 do
					-- ok
					-- uh how do i do this
					-- first check if all corners are the same, then the spaces between them? 
					-- i feel like that'll be faster in this instance since its unlikely for the corners to be set up already but thats just a gut instinct
					if board[x][y] ~= 0 and board[x][y] == board[x][y+h-1] and board[x][y] == board[x+w-1][y] and board[x][y] == board[x+w-1][y+h-1] then
						-- ok we have a candidate
						local col = board[x][y]
						local continue = true
						-- now check dx = 0 and dx = w-1...
						for dy = 1,h-2 do
							if continue then
								if board[x][y+dy] ~= col or board[x + w-1][y+dy] ~= col then
									continue = false
								end
							end
						end
						-- and dy = 0 and dy = h-1:
						for dx = 1,w-2 do
							if continue then
								if board[x+dx][y] ~= col or board[x+dx][y + h-1] ~= col then
									continue = false
								end
							end
						end
						-- if continue is still active, then we found it.
						if continue then
							table.insert(found_squares, {x, y, w, h, color=board[x][y]})
						end -- END CASCADE
					end
				end
			end
		end
	end
	return found_squares
end



function add_slide_ease(x, y, start_dx, start_dy, end_dx, end_dy, length, ease_func)
	-- slide eases - simple movement of a tile
	-- sx, sy, ex, ey, l (all self-explainatory), el (elapsed time), es
	board.eases[x][y].slide = {sx = start_dx, sy = start_dy, ex = end_dx, ey = end_dy, l = length, el = 0, es = ease_func}
end