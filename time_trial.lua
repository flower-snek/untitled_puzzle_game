
-- time trial mode functions

end_time = 0

function init_time_trial(length)
	init_board(BOARD_SIZE)
	end_time = love.timer.getTime() + length
end

function get_remaining_time()
	return end_time - love.timer.getTime()
end

function time_trial_active()
	return love.timer.getTime() < end_time
end