local v = ...

if v == 0 then
  return '0,0,0,0'
elseif v < 0.75 then
  return '223,0,0'
elseif v < 1 then
  return '223,223,0'
else
  return '0,223,0'
end
