-- Copy table and nested tables
function table.deepcopy(t)
  local t2 = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      t2[k] = table.deepcopy(v)
    else
      t2[k] = v
    end
  end
  return t2
end

-- Create empty table with x columns and y rows
function table.empty(x, y)
  t = {}
  for i=1, y do
    t[i] = {}
    for j=1, x do
      t[i][j] = 0
    end
  end
  return t
end

-- Mix given color with white
function make_brighter(color, amount)
  color = table.deepcopy(color)
  amount = amount or 0.5
  amount = math.min(amount, 1)
  for i=1, #color do
    color[i] = color[i]*(1-amount)+255*amount
  end
  return color
end
