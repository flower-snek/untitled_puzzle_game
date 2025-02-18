------------------------------------------------------------



-- i dont like having code up here it feels weird



------------------------------------------------------------

-- handles logic with the board

require("ease")

function init_board(size)
	board = {}
	board.size = size
	board.recent_clears = {}
	board.chain = 0
	
	repeat
		if DEBUG then
			print("generating...")
		end
		for x = 1,size do
			board[x] = {}
			for y = 1,size do
				board[x][y] = {}
				board[x][y].col = math.random(1,3)
				board[x][y].fall = 0
				board[x][y].eases = {}
				board[x][y].locks = 0
				print(board[x][y].col)
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
			local n = board[x][y].col
			local p = pos_from_board(cx, cy, x, y)
			if n > 0 then
				local ease_dx = 0
				local ease_dy = 0
				if board[x][y].eases.slide then
					local ease = board[x][y].eases.slide
					local ease_val = ease.es(0, ease.l, ease.el)
					ease_dx = (((ease.ex - ease.sx) * ease_val) + ease.sx) * TILE_SIZE
					ease_dy = (((ease.ey - ease.sy) * ease_val) + ease.sy) * TILE_SIZE
					-- print(ease_dx .. " " .. ease_dy)
				end
				love.graphics.draw(gfx.tile_imgs[n], p[1] + ease_dx, p[2] + ease_dy)
				local l = board[x][y].locks
				if l > 0 then
					if l <= 5 then
						love.graphics.draw(gfx.tile_lock[l], p[1] + ease_dx, p[2] + ease_dy)
					else
						love.graphics.draw(gfx.tile_lock[5], p[1] + ease_dx, p[2] + ease_dy)
					end
				end
				if DEBUG then
					love.graphics.print(board.fall[x][y], p[1] + ease_dx, p[2] + ease_dy)
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
			falling_at_start[x][y] = (board[x][y].fall > 0)
		end
	end
	
	-- gravity loop
	-- (gotta get all these eases set up before eases are updated)
	for x = 1,board.size do
		for y = board.size,1,-1 do -- reverse order for gravity
			if y < board.size then
				if board[x][y].col > 0 and board[x][y+1].col == 0 and not board[x][y].eases.slide and not in_solid_clear(x, y+1) then
					-- do the thing
					board[x][y+1] = copy_block(board[x][y])
					board[x][y+1].fall = board[x][y+1].fall + 1
					board[x][y].col = 0
					board[x][y].fall = 0
					board[x][y].locks = 0
					add_slide_ease(x, y+1, 0, -1, 0, 0, FALL_FRAME_DATA[board[x][y+1].fall]/60, linear)
				elseif board[x][y].col > 0 and not board[x][y].eases.slide then
					board[x][y].fall = 0
				end
			elseif not board[x][y].eases.slide then
				board[x][y].fall = 0
				
			end
			-- and bring in new blocks along the top
			if y == 1 then
				if board[x][y].col == 0 and not in_solid_clear(x, y) then
					board[x][y].col = math.random(1, 3)
					board[x][y].fall = board[x][y+1].fall
					board[x][y].locks = 0
					if board[x][y].fall == 0 then
						board[x][y].fall = 1 -- i dont think this should ever happen but just in case...
					end
					add_slide_ease(x, y, 0, -1, 0, 0, FALL_FRAME_DATA[board[x][y].fall]/60, linear)
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
					if board[x][y].eases.slide then
						safe_clear = false
					end
				end
			end
		end
		-- if not, then clear
		if safe_clear then
			t.el = 0
			local tlx = t[1]
			local tly = t[2]
			local w = t[3]
			local h = t[4]
			
			local continues_chain = false
			for x = tlx,tlx+w-1 do
				for y = tly,tly+h-1 do
					board[x][y].col = 0
					board[x][y].fall = 0
					board[x][y].locks = 0
					if falling_at_start[x][y] then
						continues_chain = true
					end
				end
			end
			cleared_tiles = cleared_tiles + ((w-2) * (h-2))
			table.insert(board.recent_clears, t)
			
			-- basically: if this would continue the chain, change_chain = 1 (mark the chain to be incremented);
			-- if not, then set it to -1 (marks the chain to reset at 1), but chain-continues take precendence because thats what panel de pon does and its sick (lets a manual clear at the same time as a chain continue the chain)
			if continues_chain then
				change_chain = 1
			elseif change_chain == 0 then
				change_chain = -1
			end
			
			if DEBUG then
				print("  " .. w .. " x " .. h)
			end
			
			-- ok also now, remove locks from adjacent blocks
			for dy=0,h-1 do
				if tlx > 1 and board[tlx-1][tly+dy].locks > 0 then
					board[tlx-1][tly+dy].locks = board[tlx-1][tly+dy].locks - 1
				end
				if tlx+w <= board.size and board[tlx+w][tly+dy].locks > 0 then
					board[tlx+w][tly+dy].locks = board[tlx+w][tly+dy].locks - 1
				end
			end
			for dx=0,w-1 do
				if tly > 1 and board[tlx+dx][tly-1].locks > 0 then
					board[tlx+dx][tly-1].locks = board[tlx+dx][tly-1].locks - 1
				end
				if tly+h <= board.size and board[tlx+dx][tly+h].locks > 0 then
					board[tlx+dx][tly+h].locks = board[tlx+dx][tly+h].locks - 1
				end
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
			if board[x][y].eases.slide then
				board[x][y].eases.slide.el = board[x][y].eases.slide.el + dt
				
				if board[x][y].eases.slide.el > board[x][y].eases.slide.l then
					board[x][y].eases.slide = nil
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
	-- cant rotate falling tiles
	if board[x][y].fall ~= 0 or board[x][y+1].fall ~= 0 or board[x+1][y+1].fall ~= 0 or board[x+1][y].fall ~= 0 then
		return
	end
	-- cant rotate locked tiles
	if board[x][y].locks > 0 or board[x][y+1].locks > 0 or board[x+1][y+1].locks > 0 or board[x+1][y].locks > 0 then
		return
	end
	
	if dir == 1 then -- clockwise
		local temp = board[x][y].col
		board[x][y].col = board[x][y+1].col
		add_slide_ease(x, y, 0, 1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x][y+1].col = board[x+1][y+1].col
		add_slide_ease(x, y+1, 1, 0, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y+1].col = board[x+1][y].col
		add_slide_ease(x+1, y+1, 0, -1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y].col = temp
		add_slide_ease(x+1, y, -1, 0, 0, 0, ROTATE_FRAMES/60, EASE)
	elseif dir == -1 then -- ccw
		local temp = board[x][y].col
		board[x][y].col = board[x+1][y].col
		add_slide_ease(x, y, 1, 0, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y].col = board[x+1][y+1].col
		add_slide_ease(x+1, y, 0, 1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y+1].col = board[x][y+1].col
		add_slide_ease(x+1, y+1, -1, 0, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x][y+1].col = temp
		add_slide_ease(x, y+1, 0, -1, 0, 0, ROTATE_FRAMES/60, EASE)
	else -- y'know what ill add a 180 button at some point
		local temp = board[x][y].col
		board[x][y].col = board[x+1][y+1].col
		add_slide_ease(x, y, 1, 1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y+1].col = temp
		add_slide_ease(x+1, y+1, -1, -1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		local temp = board[x][y+1].col
		board[x][y+1].col = board[x+1][y].col
		add_slide_ease(x, y+1, 1, -1, 0, 0, ROTATE_FRAMES/60, EASE)
		
		board[x+1][y].col = temp
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
					if board[x][y].col ~= 0 and board[x][y].col == board[x][y+h-1].col and board[x][y].col == board[x+w-1][y].col and board[x][y].col == board[x+w-1][y+h-1].col then
						-- ok we have a candidate
						local col = board[x][y].col
						local continue = true
						-- now check dx = 0 and dx = w-1...
						-- print("a")
						for dy = 1,h-2 do
							-- print("b")
							if continue then
								if (not (col == board[x][y+dy].col)) or (not (col == board[x + w-1][y+dy].col)) then
									continue = false
								end
							end
						end
						-- and dy = 0 and dy = h-1:
						for dx = 1,w-2 do
							if continue then
								if (not (col == board[x+dx][y].col)) or (not (col == board[x+dx][y + h-1].col)) then
									continue = false
								end
							end
						end
						-- if continue is still active, then we found it.
						if continue then
							print(x .. " " .. y .. " " .. w .. " " .. h)
							table.insert(found_squares, {x, y, w, h, color=col})
						end -- END CASCADE
					end
				end
			end
		end
	end
	return found_squares
end



function equal_tiles(x1, y1, x2, y2)
	-- not necessary anymore and should probably be removed
	-- (this was a really hacky way of handling locks anyways)
	local t1 = board[x1][y1].col
	local t2 = board[x2][y2].col
	if t1 > 3 then
		t1 = t1 - 3
	end
	if t2 > 3 then
		t2 = t2 - 3
	end
	return t1 == t2
end



function add_slide_ease(x, y, start_dx, start_dy, end_dx, end_dy, length, ease_func)
	-- slide eases - simple movement of a tile
	-- sx, sy, ex, ey, l (all self-explainatory), el (elapsed time), es
	board[x][y].eases.slide = {sx = start_dx, sy = start_dy, ex = end_dx, ey = end_dy, l = length, el = 0, es = ease_func}
end


function deal_damage_rand_unlocked(n)
	-- deal damage to random spots that are unlocked - old system
	
	-- get list of all spots that are not already locked
	local locations = {}
	for x=1,board.size do
		for y=1,board.size do
			if board[x][y].locks == 0 then
				table.insert(locations, {x, y})
			end
		end
	end
	
	for i=1,n do
		if #locations > 0 then
			local new = math.random(1, #locations)
			board[locations[new][1]][locations[new][2]].locks = board[locations[new][1]][locations[new][2]].locks + 1
			table.remove(locations, new)
		end
	end
end

function deal_damage_rand(n)
	-- deal damage to random spots regardless of whether or not they have a lock
	
	for i=1,n do
		local x = math.random(1,board.size)
		local y = math.random(1,board.size)
		board[x][y].locks = board[x][y].locks + 1
	end
end

function copy_block(block)
	local new_block = {}
	new_block.col = block.col
	new_block.fall = block.fall
	new_block.locks = block.locks
	new_block.eases = {} -- i aint doing recursive copies
	return new_block
end