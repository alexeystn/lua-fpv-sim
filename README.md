# Lua FPV Simulator

![](https://raw.githubusercontent.com/alexeystn/lua-fpv-sim/master/images/scr1.png)
![](https://raw.githubusercontent.com/alexeystn/lua-fpv-sim/master/images/scr2.png)
![](https://raw.githubusercontent.com/alexeystn/lua-fpv-sim/master/images/scr3.png)

The fisrt FPV drone simulator running directly on OpenTX transmitters! 

April Fools' joke which is not actually a joke 😉

https://youtu.be/shNwYKozE4o

#### Requirements:
* Any OpenTX / EdgeTX radio
* SD card

#### How to play:
* Control your drone with throttle, pitch and roll sticks, just as you control your real drone.
* Get as many points as you can in 30 seconds.

#### How to install:
* Copy [`SCRIPTS/simulator.lua`](https://raw.githubusercontent.com/alexeystn/lua-fpv-sim/master/SCRIPTS/simulator.lua) file from this repository to `SCRIPTS` directory of your SD card.
* Long press `Menu` button to enter Radio Setup. Navigate to SD-card page (2/9). Find the simulator file. Long press `Enter` button and choose `Execute`.

If sim looks blurry at high speed, change the value in line #7: `local lowFps = false` from `false` to `true`.
Most transmitters LCDs have a very slow response time. They are not intended to display dynamic scenes with high FPS.
