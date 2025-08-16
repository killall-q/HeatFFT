function Initialize()
  mFFT, FFTd, grad = {}, {}, {}
  mode = SKIN:GetVariable('Mode') == '1'
  heat = tonumber(SKIN:GetVariable('Heat')) -- growth rate of FFT values
  cool = tonumber(SKIN:GetVariable('Cool')) -- decay rate of FFT values
  bands = tonumber(SKIN:GetVariable('Bands')) -- number of FFT bands
  res = math.floor(tonumber(SKIN:GetVariable('Height')) / tonumber(SKIN:GetVariable('BlurH'))) - 2
  barH = tonumber(SKIN:GetVariable('BarH'))
  dGap = (barH + 1) / (res - barH) -- makes multi-frame deltas exactly contiguous
  scroll = 0 -- preset selection list scroll position
  isLocked = false -- lock hiding of mouseover controls
  if bands > 1 and not SKIN:GetMeasure('mFFT1') then
    GenMeasures()
    SKIN:Bang('!Refresh')
    return
  end
  os.remove(SKIN:GetVariable('@')..'Measures.inc')
  SetChannel(SKIN:GetVariable('Channel'))
  SetOrder(tonumber(SKIN:GetVariable('Order')), true)
  LoadPreset()
  local width = tonumber(SKIN:GetVariable('Width'))
  local blurW = math.min(tonumber(SKIN:GetVariable('BlurW')), width / (bands * 2))
  local barG = math.min(tonumber(SKIN:GetVariable('BarG')), width / (bands - 1) - blurW * 2)
  local barW = (width - barG * (bands - 1)) / bands
  local resMax = tonumber(SKIN:GetVariable('Height')) - 2
  for b = 1, bands do
    mFFT[b], FFTd[b] = SKIN:GetMeasure('mFFT'..(b - 1)), {}
    for i = 0, resMax do
      FFTd[b][i] = 0
    end
    FFTd[b].prev = 0
    SKIN:Bang('!SetOption Render Shape'..(b ~= 1 and b or '')..' "Rectangle '..((barW + barG) * (b - 1))..',0,'..barW..',#Height#|Fill LinearGradient Grad'..b..'|Extend Attr"')
    grad[b] = '00000000;'..((barW + barG) * (b - 1) / width)..'|000000;'..(((barW + barG) * (b - 1) + blurW) / width)..'|000000;'..(((barW + barG) * b - barG - blurW) / width)..'|00000000;'..(((barW + barG) * b - barG) / width)
  end
  SKIN:Bang('[!SetOption Mask Grad "0|'..table.concat(grad, '|')..'"][!SetOption Mode'..(mode and 1 or 0)..' SolidColor FF0000][!SetOption Mode'..(mode and 1 or 0)..' MouseLeaveAction "!SetOption #*CURRENTSECTION*# SolidColor FF0000"][!SetOption HeatSlider X '..(heat * 100 - 2)..'r][!SetOption HeatVal Text '..(heat * 100)..'%][!SetOption CoolSlider X '..(cool * 200 - 2)..'r][!SetOption CoolVal Text '..(cool * 100)..'%][!SetOption BarHSlider X '..(barH * 2)..'r][!SetOption BarGSlider X '..(barG * 2)..'r][!SetOption BlurWSlider X '..(blurW * 2)..'r][!SetOption BlurHSlider X '..(tonumber(SKIN:GetVariable('BlurH')) * 2 - 2)..'r][!SetOption SensSlider X '..(tonumber(SKIN:GetVariable('Sens')) * 0.9)..'r]')
  Update()
end

function Update()
  for b = 1, bands do
    local FFT = mFFT[b]:GetValue()
    local dMin, dMax = mode and 0 or math.floor(math.min(FFT, FFTd[b].prev + dGap) * (res - barH)), math.floor((mode and FFT or math.max(FFT, FFTd[b].prev - dGap)) * (res - barH) + barH)
    FFTd[b].prev = FFT
    -- Cool entire band
    for i = 0, res do
      FFTd[b][i] = math.max(FFTd[b][i] - cool, 0)
    end
    -- Heat delta range
    for i = dMin, dMax do
      FFTd[b][i] = math.min(FFTd[b][i] + heat, 1)
    end
    for i = 0, res do
      -- Only set gradient if value differs from adjacent values
      if (i ~= 0 and FFTd[b][i - 1] ~= FFTd[b][i]) or (i ~= res and FFTd[b][i] ~= FFTd[b][i + 1]) or (i == 0 or i == res and FFTd[b][i] ~= 0) then
        grad[#grad + 1] = Preset(FFTd[b][i])..';'..((i + 1) / (res + 2))
      end
    end
    SKIN:Bang('!SetOption', 'Render', 'Grad'..b, '90|'..Preset(0)..';0|'..table.concat(grad, '|')..'|'..Preset(0)..';1')
    grad = {}
  end
end

function ShowHover()
  if SKIN:GetMeter('Handle'):GetW() > 0 then return end
  SKIN:Bang('!SetOption Hover SolidColor 80808050')
end

function ShowSettings()
  SKIN:Bang('[!SetOption Handle W '..math.max(tonumber(SKIN:GetVariable('Width')), 216)..'][!SetOption Handle H '..math.max(tonumber(SKIN:GetVariable('Height')), 368)..'][!SetOptionGroup Label X 12][!MoveMeter 12 12 ModeLabel][!MoveMeter 66 37 PresetBG][!MoveMeter 83 137 ChannelBG][!ShowMeterGroup Set][!SetOption Hover SolidColor 00000001]')
end

function HideSettings()
  if isLocked then return end
  SKIN:Bang('[!SetOptionGroup Label X -220][!MoveMeter -220 -350 ModeLabel][!MoveMeter -220 -350 PresetBG][!MoveMeter -220 -350 ChannelBG][!HideMeterGroup Set][!SetOption Hover SolidColor 00000001]')
end

function GenMeasures()
  local file = io.open(SKIN:GetVariable('@')..'Measures.inc', 'w')
  for b = 1, bands - 1 do
    file:write('[mFFT'..b..']\nMeasure=Plugin\nPlugin=AudioLevel\nParent=mFFT0\nType=Band\nBandIdx='..b..'\nGroup=mFFT\n')
  end
  file:close()
end

function SetMode(n)
  if n == (mode and 1 or 0) then return end
  mode = n == 1
  SKIN:Bang('[!SetOption Mode'..(n == 1 and 0 or 1)..' SolidColor 505050E0][!SetOption Mode'..(n == 1 and 0 or 1)..' MouseLeaveAction "!SetOption #*CURRENTSECTION*# SolidColor 505050E0"][!SetOption Mode'..(n == 1 and 1 or 0)..' SolidColor FF0000][!SetOption Mode'..(n == 1 and 1 or 0)..' MouseLeaveAction "!SetOption #*CURRENTSECTION*# SolidColor FF0000"][!WriteKeyValue Variables Mode '..n..' "#@#Settings.inc"]')
end

function LoadPreset(n)
  local file
  if n then
    file = SKIN:GetMeasure('mPreset'..n):GetStringValue()
    SKIN:Bang('[!SetOption PresetSet Text "'..file..'"][!SetVariable Preset "'..file..'"][!WriteKeyValue Variables Preset "'..file..'" "#@#Settings.inc"]')
  else
    file = SKIN:GetVariable('Preset')
  end
  -- Create function from file
  Preset = assert(loadfile(SKIN:GetVariable('@')..'Presets\\'..file..'.lua'))
end

function InitScroll()
  presetCount = SKIN:GetMeasure('mPresetCount'):GetValue()
  SKIN:GetMeter('PresetScroll'):SetH(math.min(186, 1900 / presetCount - 4))
end

function ScrollList(n, m)
  if m then
    local n = m * 0.01 > (scroll + 5) / presetCount and 1 or -1
    for i = 1, 3 do
      ScrollList(n)
    end
  elseif 0 <= scroll + n and scroll + n + 10 <= presetCount then
    scroll = scroll + n
    SKIN:Bang('[!SetOption PresetScroll Y '..(190 / (presetCount - 10) * (1 - 10 / presetCount) * scroll + 2)..'r][!UpdateMeter PresetScroll][!CommandMeasure mPreset1 Index'..(n > 0 and 'Down' or 'Up')..']')
  end
end

function SetHeat(n, m)
  if m then
    heat = math.min((math.floor(m * 0.5) + 1) * 0.02, 1)
  elseif 0.02 <= heat + n and heat + n <= 1 then
    heat = math.floor((heat + n) * 100 + 0.5) * 0.01
  else return end
  SKIN:Bang('[!SetOption HeatSlider X '..(heat * 100 - 2)..'r][!SetOption HeatVal Text '..(heat * 100)..'%][!WriteKeyValue Variables Heat '..heat..' "#@#Settings.inc"]')
end

function SetCool(n, m)
  if m then
    cool = math.min((math.floor(m * 0.5) + 1) * 0.01, 0.5)
  elseif 0.01 <= cool + n and cool + n <= 0.5 then
    cool = math.floor((cool + n) * 100 + 0.5) * 0.01
  else return end
  SKIN:Bang('[!SetOption CoolSlider X '..(cool * 200 - 2)..'r][!SetOption CoolVal Text '..(cool * 100)..'%][!WriteKeyValue Variables Cool '..cool..' "#@#Settings.inc"]')
end

function SetSens(n, m)
  local sens = tonumber(SKIN:GetVariable('Sens'))
  if m then
    sens = math.min(math.floor(m * 0.11) * 10, 100)
  elseif 0 <= sens + n and sens + n <= 100 then
    sens = math.floor((sens + n) * 0.1 + 0.5) * 10
  else return end
  SKIN:Bang('[!SetOption mFFT0 Sensitivity '..sens..'][!SetOption SensSlider X '..(sens * 0.9)..'r][!SetOption SensVal Text '..sens..'][!SetVariable Sens '..sens..'][!WriteKeyValue Variables Sens '..sens..' "#@#Settings.inc"]')
end

function SetChannel(n)
  local name = {[0]='Left','Right','Center','Subwoofer','Back Left','Back Right','Side Left','Side Right'}
  if n == 'Stereo' then
    -- Split bands between L and R channels
    for b = 0, bands / 2 - 1 do
      SKIN:Bang('[!SetOption mFFT'..b..' Channel L][!SetOption mFFT'..b..' BandIdx '..(bands - b * 2 - 2)..']')
    end
    for b = bands / 2, bands - 1 do
      SKIN:Bang('[!SetOption mFFT'..b..' Channel R][!SetOption mFFT'..b..' BandIdx '..(b * 2 - bands - 2)..']')
    end
  else
    SKIN:Bang('!SetOptionGroup mFFT Channel '..n)
    for b = 0, bands - 1 do
      SKIN:Bang('!SetOption mFFT'..b..' BandIdx '..b)
    end
  end
  SKIN:Bang('[!SetOption ChannelSet Text "'..(name[tonumber(n)] or n)..'"][!SetVariable Channel '..n..'][!WriteKeyValue Variables Channel '..n..' "#@#Settings.inc"]')
end

function SetBands()
  isLocked = false
  local set = math.floor(tonumber(SKIN:GetVariable('Set')) or 0)
  if set <= 0 then return end
  SKIN:Bang('[!WriteKeyValue Variables Bands '..set..' "#@#Settings.inc"][!WriteKeyValue Variables ShowSet 1 "#@#Settings.inc"][!Refresh]')
end

function SetOrder(n, init)
  if n ~= tonumber(SKIN:GetVariable('Order')) or init and n == 1 then
    for b = 0, bands / 2 - 1 do
      mFFT[b], mFFT[bands - b - 1] = mFFT[bands - b - 1], mFFT[b]
    end
  end
  SKIN:Bang('[!SetOption Order'..(n == 1 and 'Right' or 'Left')..' SolidColor 505050E0][!SetOption Order'..(n == 1 and 'Right' or 'Left')..' MouseLeaveAction "!SetOption #*CURRENTSECTION*# SolidColor 505050E0"][!SetOption Order'..(n == 1 and 'Left' or 'Right')..' SolidColor FF0000][!SetOption Order'..(n == 1 and 'Left' or 'Right')..' MouseLeaveAction "!SetOption #*CURRENTSECTION*# SolidColor FF0000"][!SetVariable Order '..n..'][!WriteKeyValue Variables Order '..n..' "#@#Settings.inc"]')
end

function SetVar(var, min)
  isLocked = false
  local set = math.floor(tonumber(SKIN:GetVariable('Set')) or 0)
  if set < min then return end
  local width = var == 'Width' and set or tonumber(SKIN:GetVariable('Width'))
  local height = var == 'Height' and set or tonumber(SKIN:GetVariable('Height'))
  local blurW = math.min(tonumber(SKIN:GetVariable('BlurW')), width / (bands * 2))
  local barG = math.min(tonumber(SKIN:GetVariable('BarG')), width / (bands - 1) - blurW * 2)
  local barW = (width - barG * (bands - 1)) / bands
  if var == 'Width' then
    SKIN:GetMeter('Hover'):SetW(width)
  elseif var == 'Height' then
    res = math.floor(height / tonumber(SKIN:GetVariable('BlurH'))) - 2
    dGap = (barH + 1) / (res - barH)
    for b = 1, bands do
      for i = 0, height - 2 do
        FFTd[b][i] = 0
      end
    end
    SKIN:GetMeter('Hover'):SetH(height)
  end
  for b = 1, bands do
    SKIN:Bang('!SetOption Render Shape'..(b ~= 1 and b or '')..' "Rectangle '..((barW + barG) * (b - 1))..',0,'..barW..','..height..'|Fill LinearGradient Grad'..b..'|Extend Attr"')
    grad[b] = '00000000;'..((barW + barG) * (b - 1) / width)..'|000000;'..(((barW + barG) * (b - 1) + blurW) / width)..'|000000;'..(((barW + barG) * b - barG - blurW) / width)..'|00000000;'..(((barW + barG) * b - barG) / width)
  end
  SKIN:Bang('[!SetOption Mask Shape "Rectangle 0,0,'..width..','..height..'|Fill LinearGradient Grad|StrokeWidth 0"][!SetOption Mask Grad "0|'..table.concat(grad, '|')..'"][!SetOption '..var..'Set Text "'..set..' px"][!SetVariable '..var..' '..set..'][!WriteKeyValue Variables '..var..' '..set..' "#@#Settings.inc"]')
end

function SetBarH(n, m)
  if m then
    barH = math.min(math.floor(m * 0.51), 50)
  elseif 0 <= barH + n and barH + n <= 50 then
    barH = math.floor(barH + n + 0.5)
  else return end
  dGap = (barH + 1) / (res - barH)
  SKIN:Bang('[!SetOption BarHSlider X '..(barH * 2)..'r][!SetOption BarHVal Text '..barH..'][!WriteKeyValue Variables BarH '..barH..' "#@#Settings.inc"]')
end

function SetBarG(n, m)
  local width = tonumber(SKIN:GetVariable('Width'))
  local blurW = math.min(tonumber(SKIN:GetVariable('BlurW')), width / (bands * 2))
  local barG = math.min(tonumber(SKIN:GetVariable('BarG')), width / (bands - 1) - blurW * 2)
  if m then
    barG = math.min(math.floor(m * 0.51), 50)
  elseif 0 <= barG + n and barG + n <= 50 then
    barG = math.floor(barG + n + 0.5)
  else return end
  local barW = (width - barG * (bands - 1)) / bands
  for b = 1, bands do
    SKIN:Bang('!SetOption Render Shape'..(b ~= 1 and b or '')..' "Rectangle '..((barW + barG) * (b - 1))..',0,'..barW..',#Height#|Fill LinearGradient Grad'..b..'|Extend Attr"')
    grad[b] = '00000000;'..((barW + barG) * (b - 1) / width)..'|000000;'..(((barW + barG) * (b - 1) + blurW) / width)..'|000000;'..(((barW + barG) * b - barG - blurW) / width)..'|00000000;'..(((barW + barG) * b - barG) / width)
  end
  SKIN:Bang('[!SetOption Mask Grad "0|'..table.concat(grad, '|')..'"][!SetOption BarGSlider X '..(barG * 2)..'r][!SetOption BarGVal Text "'..barG..' px"][!SetVariable BarG '..barG..'][!WriteKeyValue Variables BarG '..barG..' "#@#Settings.inc"]')
end

function SetBlurW(n, m)
  local width = tonumber(SKIN:GetVariable('Width'))
  local blurW = math.min(tonumber(SKIN:GetVariable('BlurW')), width / (bands * 2))
  if m then
    blurW = math.min(math.floor(m * 0.51), 50)
  elseif 0 <= blurW + n and blurW + n <= 50 then
    blurW = math.floor(blurW + n + 0.5)
  else return end
  local barG = math.min(tonumber(SKIN:GetVariable('BarG')), width / (bands - 1) - blurW * 2)
  local barW = (width - barG * (bands - 1)) / bands
  for b = 1, bands do
    SKIN:Bang('!SetOption Render Shape'..(b ~= 1 and b or '')..' "Rectangle '..((barW + barG) * (b - 1))..',0,'..barW..',#Height#|Fill LinearGradient Grad'..b..'|Extend Attr"')
    grad[b] = '00000000;'..((barW + barG) * (b - 1) / width)..'|000000;'..(((barW + barG) * (b - 1) + blurW) / width)..'|000000;'..(((barW + barG) * b - barG - blurW) / width)..'|00000000;'..(((barW + barG) * b - barG) / width)
  end
  SKIN:Bang('[!SetOption Mask Grad "0|'..table.concat(grad, '|')..'"][!SetOption BlurWSlider X '..(blurW * 2)..'r][!SetOption BlurWVal Text "'..blurW..' px"][!SetVariable BlurW '..blurW..'][!WriteKeyValue Variables BlurW '..blurW..' "#@#Settings.inc"]')
end

function SetBlurH(n, m)
  local blurH = tonumber(SKIN:GetVariable('BlurH'))
  if m then
    blurH = math.min(math.floor(m * 0.51), 50)
  elseif 1 <= blurH + n and blurH + n <= 50 then
    blurH = math.floor(blurH + n + 0.5)
  else return end
  res = math.floor(tonumber(SKIN:GetVariable('Height')) / blurH) - 2
  SKIN:Bang('[!SetOption BlurHSlider X '..(blurH * 2 - 2)..'r][!SetOption BlurHVal Text "'..blurH..' px"][!SetVariable BlurH '..blurH..'][!WriteKeyValue Variables BlurH '..blurH..' "#@#Settings.inc"]')
end
