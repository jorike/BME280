{Top Object - Main BME280 sensor method}

CON
  _clkmode = xtal1 + pll16x         'Standard clock mode * crystal frequency = 80 MHz
  _xinfreq = 5_000_000

VAR

OBJ
  clockObj : "i2cClock"
  bme280Obj : "BME280"

PUB Main | clk_success, reset_success, bme280_success
  {Call the clock cog start method}
  clk_success := clockObj.Start
  {Call the bme280 cog start method}
  bme280_success := bme280Obj.Start