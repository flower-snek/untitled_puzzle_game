
function linear(start, ending, cur_time)
	return (cur_time - start) / (ending - start)
end

function outSine(start, ending, cur_time)
	local x = (cur_time - start) / (ending - start)
	return math.sin((x * math.pi)/2)
end

function outQuad(start, ending, cur_time)
	local x = (cur_time - start) / (ending - start)
	return 1 - math.pow(1-x, 2)
end

function outCubic(start, ending, cur_time)
	local x = (cur_time - start) / (ending - start)
	return 1 - math.pow(1-x, 3)
end