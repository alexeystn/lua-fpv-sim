-- FPV drone simulator for OpenTX
-- Author: Alexey Stankevich @AlexeyStn

local drone = {x = 0, y = 0, z = 0}
local speed = {x = 0, y = 0, z = 0}

local lowFps = false
local fpsCounter = 0

local gate = {w = 30, h = 30}
local flag = {w = 6, h = 30}
local track = {w = 50, h = 80}

local rollScale = 30
local pitchScale = 5
local throttleScale = 40

local minSpeed = 3

local objectsN = 2
local objects = {}
local zObjectsStep = 1500

local zScale = 300

local raceTime = 30
local startTime
local finishTime
local countDown

local raceStarted = false
local startTonePlayed = false
local counter = nil

local objectCounter = 0
local bestResultPath = "/SCRIPTS/simulator.txt"
local isNewBest = false


local function loadBestResult()
  local f = io.open(bestResultPath, "r")
  if f == nil then
    return nil
  end
  result = tonumber(io.read(f, 3))
  return result
end

local function saveBestResult(result)
  local f = io.open(bestResultPath, "w")
  io.write(f, string.format("%3d", result))
  io.close(f)
end

local function drawBorder(x1, y1, x2, y2) -- 1 far, 2 close
  if x1 == x2 then -- vertical
    if y2 >= LCD_H then y2 = LCD_H - 1 end
  else -- diagonal
    a = (y2 - y1) / (x2 - x1)
    b = (y1 * x2 - y2 * x1) / (x2 - x1)
    x0 = 0
    y0 = x0 * a + b
    if a < 0 and y0 < LCD_H and y0 >= (LCD_H/2 + 1) then -- left side
      x2 = x0
      y2 = y0
    else
      x0 = (LCD_W - 1)
      y0 = x0 * a + b
      if a > 0 and y0 < LCD_H and y0 >= (LCD_H/2 + 1) then -- right side
        x2 = x0
        y2 = y0
      else -- bottom side
        p = (LCD_H - 1 - y1) / (y2 - y1)
        y2 = LCD_H - 1
        x2 = x1 + (x2 - x1) * p
        if x2 < 0 then x2 = 0 end
        if x2 >= LCD_W then x2 = LCD_W - 1 end
      end
    end
  end
  lcd.drawLine(x1, y1, x2, y2, DOTTED, FORCE)
end

local function drawLandscape()
  z = zObjectsStep / 5
  w = track.w * 2
  yDispFar = LCD_H / 2 + 1
  yDispClose = (- drone.y * zScale) / z + LCD_H / 2 - 1
  xDispFar = LCD_W / 2 + 1
  xDispClose = ((w - drone.x) * zScale) / z + LCD_W / 2
  drawBorder(xDispFar, yDispFar, xDispClose, yDispClose)
  xDispFar = LCD_W / 2 - 1
  xDispClose = ((- w - drone.x) * zScale) / z + LCD_W / 2
  drawBorder(xDispFar, yDispFar, xDispClose, yDispClose)  
  lcd.drawLine(0, LCD_H/2 + 1, LCD_W - 1, LCD_H/2 + 1, DOTTED, FORCE) -- horizon
end

local function drawLine(x1, y1, x2, y2, flag) 
  if flag == 'h' then
    if y1 < 0 or y1 > LCD_H then return 0 end
    if x1 < 0 and x2 < 0 then return 0 end
    if x1 >= LCD_W and x2 >= LCD_W then return 0 end
    if x1 < 0 then x1 = 0 end
    if x2 < 0 then x2 = 0 end
    if x1 >= LCD_W then x1 = LCD_W - 1 end
    if x2 >= LCD_W then x2 = LCD_W - 1 end
    lcd.drawLine(x1, y1, x2, y2, SOLID, FORCE)
    return 0
  end
  if flag == 'v' then
    if x1 < 0 or x1 > LCD_W then return 0 end
    if y1 < 0 and y2 < 0 then return 0 end
    if y1 >= LCD_H and y2 >= LCD_H then return 0 end
    if y1 < 0 then y1 = 0 end
    if y2 < 0 then y2 = 0 end
    if y1 >= LCD_H then y1 = LCD_H - 1 end
    if y2 >= LCD_H then y2 = LCD_H - 1 end
    lcd.drawLine(x1, y1, x2, y2, SOLID, FORCE)
    return 0
  end
end

local function drawMarker(x, y)
  if x < 0 then x = 1 end
  if x >= LCD_W then x = LCD_W - 2 end
  if y < 0 then yP = 1 end
  if y >= LCD_W then y = LCD_H - 2 end
  lcd.drawLine(x - 1, y - 1, x - 1, y + 1, SOLID, FORCE)
  lcd.drawLine(x    , y - 1, x    , y + 1, SOLID, FORCE)
  lcd.drawLine(x + 1, y - 1, x + 1, y + 1, SOLID, FORCE)
end

local function drawObject(object, markerFlag)
  x = object.x - drone.x
  y = object.y - drone.y
  z = object.z - drone.z
  if object.t == "gateGround" then
    xDispLeft = ((x - gate.w/2) * zScale) / z + LCD_W/2
    xDispRight = ((x + gate.w/2) * zScale) / z + LCD_W/2
    yDispTop = ((y - gate.h) * zScale) / z + LCD_H/2
    yDispBottom = ((y + 0) * zScale) / z + LCD_H/2
    xDispMarker = (x * zScale) / z + LCD_W/2
    yDispMarker = ((y - gate.h/2) * zScale) / z + LCD_H/2
    drawLine(xDispLeft, yDispBottom, xDispLeft, yDispTop, 'v')
    drawLine(xDispRight, yDispBottom, xDispRight, yDispTop, 'v')
    drawLine(xDispLeft, yDispTop, xDispRight, yDispTop, 'h')
  elseif object.t == "gateAir" then
    xDispLeft = ((x - gate.w/2) * zScale) / z + LCD_W/2
    xDispRight = ((x + gate.w/2) * zScale) / z + LCD_W/2
    yDispTop = ((y - gate.h*2) * zScale) / z + LCD_H/2
    yDispMid = ((y - gate.h) * zScale) / z + LCD_H/2
    yDispBottom = ((y + 0) * zScale) / z + LCD_H/2
    xDispMarker = (x * zScale) / z + LCD_W/2
    yDispMarker = ((y - gate.h*3/2) * zScale) / z + LCD_H/2
    drawLine(xDispLeft, yDispBottom, xDispLeft, yDispTop, 'v')
    drawLine(xDispRight, yDispBottom, xDispRight, yDispTop, 'v')
    drawLine(xDispLeft, yDispTop, xDispRight, yDispTop, 'h')
    drawLine(xDispLeft, yDispMid, xDispRight, yDispMid, 'h')
  elseif object.t == "flagLeft" then
    xDispLeft = ((x - flag.w/2) * zScale) / z + LCD_W/2
    xDispRight = ((x + flag.w/2) * zScale) / z + LCD_W/2
    yDispTop = ((y - gate.h*2) * zScale) / z + LCD_H/2
    yDispMid = ((y - gate.h) * zScale) / z + LCD_H/2
    yDispBottom = ((y + 0) * zScale) / z + LCD_H/2
    xDispMarker = ((x + flag.w*2) * zScale) / z + LCD_W/2
    yDispMarker = ((y - gate.h*3/2) * zScale) / z + LCD_H/2
    drawLine(xDispLeft, yDispMid, xDispLeft, yDispTop, 'v')
    drawLine(xDispRight, yDispBottom, xDispRight, yDispTop, 'v')
    drawLine(xDispLeft, yDispTop, xDispRight, yDispTop, 'h')
    drawLine(xDispLeft, yDispMid, xDispRight, yDispMid, 'h')
  elseif object.t == "flagRight" then
    xDispLeft = ((x - flag.w/2) * zScale) / z + LCD_W/2
    xDispRight = ((x + flag.w/2) * zScale) / z + LCD_W/2
    yDispTop = ((y - gate.h*2) * zScale) / z + LCD_H/2
    yDispMid = ((y - gate.h) * zScale) / z + LCD_H/2
    yDispBottom = ((y + 0) * zScale) / z + LCD_H/2
    xDispMarker = ((x - flag.w*2) * zScale) / z + LCD_W/2
    yDispMarker = ((y - gate.h*3/2) * zScale) / z + LCD_H/2
    drawLine(xDispLeft, yDispBottom, xDispLeft, yDispTop, 'v')
    drawLine(xDispRight, yDispMid, xDispRight, yDispTop, 'v')
    drawLine(xDispLeft, yDispTop, xDispRight, yDispTop, 'h')
    drawLine(xDispLeft, yDispMid, xDispRight, yDispMid, 'h')
  end	
  if markerFlag then 
    drawMarker(xDispMarker, yDispMarker)
  end
end

local function generateObject()
  objectCounter = objectCounter + 1
  distance = objectCounter * zObjectsStep
  object = {x = math.random(-track.w, track.w), y = 0, z = distance}
  typeId = math.random(1,6)
  if typeId == 1 or typeId == 2 then
    object.t = "gateGround"
  elseif typeId == 3 or typeId == 4 then	
    object.t = "gateAir"		
  elseif typeId == 5 then	
    object.t = "flagRight"
    object.x = - math.abs(object.x) - track.w
  elseif typeId == 6 then	
    object.t = "flagLeft"
    object.x = math.abs(object.x) + track.w
  end
  return object
end

local function init_func()
  if lowFps then
    rollScale = rollScale / 2
    pitchScale = pitchScale / 2
    throttleScale = throttleScale / 2
  end
  bestResult = loadBestResult()
end

local function run_func(event)
  if not raceStarted then
    lcd.clear()
    lcd.drawText(LCD_W/2 - 59, 54, "Press [Enter] to start")
    if counter then
      lcd.drawText(LCD_W/2 - 27, 28, "Result:")
      lcd.drawNumber(LCD_W/2 + 12, 28, counter, BOLD)
      if isNewBest then
        lcd.drawText(LCD_W/2 - 42, 2, "New best score!")
      else
        lcd.drawText(LCD_W/2 - 37, 2, "Best score:")
        lcd.drawNumber(LCD_W/2 + 26, 2, bestResult)
      end
    else
      lcd.drawText(LCD_W/2 - 47, 28, "Lua FPV Simulator", BOLD)
    end
    if event == EVT_ENTER_BREAK then 
      drone.x = 0
      drone.y = 0
      drone.z = 0
      objectCounter = 0
      for i = 1, objectsN do
        objects[i] = generateObject(zObjectsStep * i) 
      end
      counter = 0
      countDown = 3
      startTime = getTime() + countDown * 100
      finishTime = getTime() + (raceTime + countDown) * 100
      countDown = countDown + 1
      startTonePlayed = false
      raceStarted = true
      isNewBest = false
    end
  else
    if lowFps then
      fpsCounter = fpsCounter + 1
      if fpsCounter == 2 then
        fpsCounter = 0
        return 0
      end
    end    
    lcd.clear()
    currentTime = getTime()
    if currentTime < startTime then
      local cnt = (startTime - currentTime) / 100 + 1
      if cnt < countDown then 
        playTone(1500, 100, 0)
        countDown = countDown - 1
      end
      lcd.drawNumber(LCD_W/2 - 2, 48, cnt, BOLD)
    elseif currentTime < finishTime then
      if (currentTime - startTime) < 100 then
        lcd.drawText(LCD_W/2 - 6, 48, 'GO!', BOLD)
        if not startTonePlayed then
          playTone(2250, 500, 0)
          startTonePlayed = true
        end
      end
      speed.x = getValue('ail') / rollScale
      speed.z = getValue('ele') / pitchScale + minSpeed
      speed.y = getValue('thr') / throttleScale
      if speed.z < 0 then speed.z = 0 end
      drone.y = drone.y - speed.y
      if drone.y >= 0 then 
        drone.y = 0 
        speed.z = 0
        speed.x = 0
      end     
      drone.z = drone.z + speed.z
      drone.x = drone.x + speed.x
      if drone.x > track.w * 3 then drone.x = track.w * 3 end
      if drone.x < -track.w * 3 then drone.x = -track.w * 3 end
      if drone.y < -track.h then drone.y = -track.h end
    else
      if (not bestResult) or (counter > bestResult) then
        isNewBest = true
        saveBestResult(counter)
        bestResult = counter
      end
      raceStarted = false
    end
    remainingTime = (finishTime - currentTime)/100 + 1
    if remainingTime > raceTime then remainingTime = raceTime end
    lcd.drawTimer(LCD_W - 25, 2, remainingTime)
    local closestDist = drone.z + zObjectsStep * objectsN
    for i = 1, objectsN do
      if objects[i].z < closestDist and objects[i].z > (drone.z + speed.z) then
        closestN = i
        closestDist = objects[i].z
      end
    end
    for i = 1, objectsN do
      if drone.z >= objects[i].z then
        success = false
        if objects[i].t == "gateGround" then 
          if (math.abs(objects[i].x - drone.x) <= gate.w/2) and (drone.y > -gate.h) then
            success = true
          end
        elseif objects[i].t == "gateAir" then 
          if (math.abs(objects[i].x - drone.x) <= gate.w/2) and (drone.y < -gate.h) and (drone.y > -2*gate.h) then
            success = true
          end
        elseif objects[i].t == "flagLeft" then 				
          if (objects[i].x < drone.x) and (drone.y > -2*gate.h) then 
            success = true
          end
        elseif objects[i].t == "flagRight" then 				
          if (objects[i].x > drone.x) and (drone.y > -2*gate.h) then 
            success = true
          end				
        end
        if success then
          counter = counter + 1
          playTone(1000, 100, 0)
        else
          counter = counter - 1
          playTone(500, 300, 0)
        end
        objects[i] = generateObject()
      else
        drawObject(objects[i], i == closestN)
      end	
    end
    drawLandscape()
    lcd.drawNumber(3, 2, counter)
    if event == EVT_EXIT_BREAK then 
      raceStarted = false
      counter = nil
    end
  end
  return 0
end

return { init=init_func, run=run_func }
