local M = {}

M.clip_val = function(min, val, max)
  if val < min then
    val = min
  end
  if val > max then
    val = max
  end
  return val
end

return M
