{BME280 low power pressure, temperature, and humidity sensor
 using the I2C Bus specification.

┌──────────────────────────────────────────┐
│ BME280                                   │
│ Author: James Rike                       │
│ Copyright (c) 2022 Seapoint Software     │
│ See end of file for terms of use.        │
└──────────────────────────────────────────┘

}


CON
  _clkmode = xtal1 + pll16x      'Standard clock mode * crystal frequency = 80 MHz
  _xinfreq = 5_000_000

  SDA_pin = 18
  SCL_pin = 17

VAR
  long digT1, digT2, digT3
  long digP1, digP2, digP3, digP4, digP5, digP6, digP7, digP8, digP9
  long digH1, digH2, digH3, digH4, digH5, digH6, adc_T, adc_P, adc_H
  long t_fine
  long semID
  byte cog

OBJ
  num   :       "Simple_Numbers"
  'lcd   :       "Serial_Lcd"
  pst   :       "Parallax Serial Terminal"
  'dbg   :       "PASDebug"      '<---- Add for Debugger

PUB Start                       'Cog start method
  if not semID := locknew    'If checked out a lock
    cog := cognew(@_entry, @digT1) + 1
    'dbg.start(31,30,@_entry)     '<---- Add for Debugger
    PrintData

PUB Stop                        'Cog stop method
    if cog
      lockret(semID)
      cogstop(cog~ - 1)

PRI PrintData  | T, H, P, tf

  pst.Start(115_200)
  pst.char(0)
  pst.str(string("*-----Initializing-----*"))

  repeat
    ThirtySecInterval(2)
    repeat until not lockset(semID)
    pst.char(0)
    pst.str(string("*-------------------*"))
    pst.NewLine
    pst.str(string("Temp: "))
    T := BME280_compensate_T
    pst.str(num.dec(T/100))
    pst.str(string("."))
    pst.str(num.dec(T//100))
    pst.str(string(" C"))
    pst.NewLine
    tf := gettempf(T)
    pst.str(string("      "))
    pst.str(num.dec(tf/100))
    pst.str(string("."))
    pst.str(num.dec(tf//100))
    pst.str(string(" F"))
    pst.NewLine
    pst.str(string("RH:   "))
    H := BME280_compensate_H
    pst.str(num.dec(H/1000))
    pst.str(string("."))
    pst.str(num.dec(H//1000))
    pst.str(string(" %"))
    pst.NewLine
    pst.str(string("Pressure: "))
    P := BME280_compensate_P
    pst.str(num.dec(P/100))
    pst.str(string("."))
    pst.str(num.decf(P//100, 2))
    pst.str(string(" hPa"))
    lockclr(semID)
PRI ThirtySecInterval(t)

repeat t
  waitcnt (clkfreq * 30 + cnt)
return

PRI BME280_compensate_T :T | var1, var2

' Returns temperature in DegC, resolution is 0.01 DegC. Output value of 5123 equals 51.23 DegC.
' t_fine carries fine temperature as global value

var1 := ((((adc_T >> 3) - (digT1 << 1))) * digT2) >> 11
var2 := (((((adc_T >> 4) - digT1) * ((adc_T >> 4) - digT1)) >> 12) * digT3) >> 14
t_fine := var1 + var2
T := (t_fine * 5 + 128) >> 8
return T

PRI bme280_compensate_H :H

'Returns humidity in %RH as unsigned 32 bit integer in Q22.10 format
' (22 integer and 10 fractional bits).
'Output value of 47445 represents 47445/1024 = 46.333 %RH

H := (t_fine - 76800)
H := (((((adc_H << 14) - (digH4 << 20) - (digH5 * H)) + 16384) >> 15) * (((((((H * digH6) >> 10) * (((H * digH3) >> 11) + 32768)) >> 10) + 2097152) * digH2 + 8192) >> 14))
H := (H - (((((H >> 15) * (H >> 15)) >> 7) * digH1) >> 4))

if (H < 0)
  H := 0

if (H > 419430400)
  H := 419430400

return (H >> 12)

PRI BME280_compensate_P :p | var1, var2

' Returns pressure in Pa as unsigned 32 bit integer.
'Output value of 96386 equals 96386 Pa = 963.86 hPa

var1 := ((t_fine)>>1) - 64000
var2 := (((var1>>2) * (var1>>2)) >> 11 ) * (digP6)
var2 := var2 + ((var1*(digP5))<<1)
var2 := (var2>>2)+((digP4)<<16)
var1 := (((digP3 * (((var1>>2) * (var1>>2)) >> 13 )) >> 3) + (((digP2) * var1)>>1))>>18
var1 :=((((32768+var1))*(digP1))>>15)
if (var1 == 0)
  return 0                      'avoid exception caused by division by zero

p := ((((1048576)-adc_P)-(var2>>12)))*3125

if (p < $80000000)
  p := (p << 1) / (var1)
else
  p := (p / var1) * 2

var1 := ((digP9) * ((((p>>3) * (p>>3))>>13)))>>12
var2 := (((p>>2)) * (digP8))>>13
p := (p + ((var1 + var2 + digP7) >> 4)) + 32768
return p

PRI gettempf(t) | tf

  tf := t * 9 / 5 + 3200

  return tf

' Returns humidity in %RH as unsigned 32 bit integer in Q22.10 format (22 integer and 10 fractional bits).
' Output value of 47445 represents 47445 / 1024 = 46.333 %RH

PRI gethumidity(h) | th

  th := h
  return th

DAT
        org 0
_entry

{
'  --------- Debugger Kernel add this at Entry (Addr 0) ---------
   long $34FC1202,$6CE81201,$83C120B,$8BC0E0A,$E87C0E03,$8BC0E0A
   long $EC7C0E05,$A0BC1207,$5C7C0003,$5C7C0003,$7FFC,$7FF8
'  --------------------------------------------------------------
}
        rdlong sfreq, #0

       '****************Soft Reset**************
        call #starts                            'Send START to the sensor (rx), sets clock and data pins low
        call #sladrw                            'Write to device address 0x77
        call #acks

        mov counter, #8
        mov tmp, reset_addr
        rev tmp, #0
        shr tmp, #24

        call #data_out

        call #acks

        mov counter, #8
        mov tmp, reset
        rev tmp, #0
        shr tmp, #24

        call #data_out

        call #nackm
        call #stops
        '****************End of soft reset*****************

        waitcnt sfreq/100, 0

        '**************Start of read device ID*************
        call #starts
        call #sladrw                            'Write to device address 0x77
        call #acks                              'End of WRITE


        mov counter, #8                         'Send the ID register address: $D0
        mov tmp, id_addr                        'ID register = $D0
        rev tmp, #0                             'Reverse order of id
        shr tmp, #24                            'MSB first

        call #data_out
        call #acks

        call #starts
        call #sladrr
        call #acks

        call #read_in
        mov id_data, data_byte                  'Device ID data = 0x60
        call #nackm
        call #stops

        '********************Get calibration data*************

        call #starts
        call #sladrw                            'Write to device address 0x77
        call #acks

        'Address to read

        mov counter, #8
        mov tmp, cal_addr                       'Lower byte of digi_T1 at 0x88
        rev tmp, #0                             'Reverse the bit order
        shr tmp, #24                            'MSB first

        call #data_out                          'Write the data byte

        call #acks

        call #starts                            'Start the burst read at address 0x88
        call #sladrr
        call #acks

        call #read_in
        call #ackm
        mov digi_T1, data_byte                  'Move the contents of register 0x88 to digi_T1 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x89 to temp data
        shl tmp, #8
        or digi_T1, tmp                         'Move the upper byte into digi_T1 parameter

        call #read_in
        call #ackm
        mov digi_T2, data_byte                  'Move the contents of register 0x8a to digi_T2 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x8b to temp data
        shl tmp, #8
        or digi_T2, tmp                         'Move the upper byte into digi_T2 parameter

        call #read_in
        call #ackm
        mov digi_T3, data_byte                  'Move the contents of register 0x8c to digi_T3 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x8d to temp data
        shl tmp, #8
        or digi_T3, tmp                         'Move the upper byte into digi_T3 parameter

        call #read_in
        call #ackm
        mov digi_P1, data_byte                  'Move the contents of register 0x8e to digi_P1 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x8f to temp data
        shl tmp, #8
        or digi_P1, tmp                         'Move the upper byte into digi_P1 parameter

        call #read_in
        call #ackm
        mov digi_P2, data_byte                  'Move the contents of register 0x90 to digi_P2 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x91 to temp data
        shl tmp, #8
        or digi_P2, tmp                         'Move the upper byte into digi_P2 parameter

        call #read_in
        call #ackm
        mov digi_P3, data_byte                  'Move the contents of register 0x92 to digi_P3 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x93 to temp data
        shl tmp, #8
        or digi_P3, tmp                         'Move the upper byte into digi_P3 parameter

        call #read_in
        call #ackm
        mov digi_P4, data_byte                  'Move the contents of register 0x94 to digi_P4 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x95 to temp data
        shl tmp, #8
        or digi_P4, tmp                         'Move the upper byte into digi_P4 parameter

        call #read_in
        call #ackm
        mov digi_P5, data_byte                  'Move the contents of register 0x96 to digi_P5 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x97 to temp data
        shl tmp, #8
        or digi_P5, tmp                         'Move the upper byte into digi_P5 parameter

        call #read_in
        call #ackm
        mov digi_P6, data_byte                  'Move the contents of register 0x98 to digi_P6 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x99 to temp data
        shl tmp, #8
        or digi_P6, tmp                         'Move the upper byte into digi_P6 parameter

        call #read_in
        call #ackm
        mov digi_P7, data_byte                  'Move the contents of register 0x9a to digi_P7 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x9b to temp data
        shl tmp, #8
        or digi_P7, tmp                         'Move the upper byte into digi_P7 parameter

        call #read_in
        call #ackm
        mov digi_P8, data_byte                  'Move the contents of register 0x9c to digi_P8 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x9d to temp data
        shl tmp, #8
        or digi_P8, tmp                         'Move the upper byte into digi_P8 parameter

        call #read_in
        call #ackm
        mov digi_P9, data_byte                  'Move the contents of register 0x9e to digi_P2 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x9f to temp data
        shl tmp, #8
        or digi_P9, tmp                         'Move the upper byte into digi_P2 parameter

        call #read_in
        call #nackm
        call #stops
        mov digi_H1, data_byte                  'Move the contents of register 0xA0 to digi_H1 parameter

        {*******Get the last part of humidity calibration data starting at $E1******}

        call #starts
        call #sladrw                            'Write to device address 0x77
        call #acks                              'End of WRITE

        mov counter, #8                         'Register address: $E1
        mov tmp, calH_addr                      'Humidity calibration register = $E1
        rev tmp, #0                             'Reverse order of id
        shr tmp, #24                            'MSB first

        call #data_out
        call #acks

        call #starts
        call #sladrr
        call #acks

        call #read_in
        call #ackm
        mov digi_H2, data_byte                  'Move the contents of register 0xE2 to digi_H2 parameter

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xE3 to temp data
        shl tmp, #8
        or digi_H2, tmp                         'Move the upper byte into digi_H2 parameter

        call #read_in
        call #ackm
        mov digi_H3, data_byte                  'Move the contents of register 0xH3 to digi_H3 parameter

        call #read_in
        call #ackm
        mov digi_H4, data_byte                  'Move contents of register 0xE4 to digi_H4 bits[11:4]
        shl digi_H4, #4

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xE5 to temp data
        and tmp, $0F
        or digi_H4, tmp                         'Move bits[3:0] into digi_H4 parameter

        mov tmp, data_byte                      'Move the contents of register 0xE5 to temp data
        and tmp, $F0                            'Move bits[7:4] into digi_H5 bits[3:0]
        shr tmp, #4
        or digi_H5, tmp

        call #read_in
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xE6 to digi_H5 bits[11:4]
        shl tmp, #4
        or digi_H5, tmp

        call #read_in
        mov digi_H6, data_byte                  'Move the contents of register 0xH3 to digi_H3 parameter
        call #nackm
        call #stops

{************* Copy shared memory address and get the lock ID ************}

        mov shared_mem, par
        rdlong lockID, shared_mem

{************************** Configure the sensor *************************}

sample  call #starts
        call #sladrw                            'Write to device address 0x77
        call #acks                              'End of WRITE

        mov counter, #8                         'Register address: $F2
        mov tmp, ctl_hum
        rev tmp, #0                             'Reverse order of id
        shr tmp, #24                            'MSB first

        call #data_out
        call #acks

        mov counter, #8                         'Write to register $F2
        mov tmp, ctl_hum_data                   'Set sampling and mode
        rev tmp, #0                             'Reverse order of id
        shr tmp, #24                            'MSB first

        call #data_out
        call #nackm
        call #stops

        call #starts
        call #sladrw                            'Write to device address 0x77
        call #acks                              'End of WRITE

        mov counter, #8                         'Register address: $F4
        mov tmp, ctl_meas
        rev tmp, #0                             'Reverse order of id
        shr tmp, #24                            'MSB first

        call #data_out
        call #acks

        mov counter, #8                         'Write to register $F4
        mov tmp, ctl_meas_data                  'Set sampling and mode
        rev tmp, #0                             'Reverse order of id
        shr tmp, #24                            'MSB first

        call #data_out
        call #acks

        mov counter, #8                         'Register address: $F5
        mov tmp, config
        rev tmp, #0                             'Reverse order of id
        shr tmp, #24                            'MSB first

        call #data_out
        call #acks

        mov counter, #8                         'Write to register address: $F5
        mov tmp, config_data
        rev tmp, #0                             'Reverse order of id
        shr tmp, #24                            'MSB first

        call #data_out
        call #nackm
        call #stops

{*********************** Read the raw sensor data for P, T, and H ********************}

        call #starts
        call #sladrw                            'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, tph_msb                        'Pressure MSB register = $F7
        rev tmp, #0                             'Reverse order of address bits
        shr tmp, #24                            'MSB first

        call #data_out
        call #acks

        call #starts
        call #sladrr
        call #acks

        call #read_in
        call #ackm
        mov p_data, data_byte                   'Move the contents of register 0xF7 MSB of raw data
        shl p_data, #8                          'Make room for the next byte

        call #read_in
        call #ackm
        or p_data, data_byte                    'Move the contents of register 0xF8
        shl p_data, #8                          'Make room for the first bit of the next byte

        call #read_in
        call #ackm
        or p_data, data_byte                    'Move the contents of register 0xF9
        shr p_data, #4                          '20 bit format

        call #read_in
        call #ackm
        mov t_data, data_byte                   'Move the contents of register 0xFA MSB of raw data
        shl t_data, #8                          'Make room for the next byte

        call #read_in
        call #ackm
        or t_data, data_byte                    'Move the contents of register 0xFB
        shl t_data, #8                          'Make room for the first bit of the next byte

        call #read_in
        call #ackm
        or t_data, data_byte                    'Move the contents of register 0xFC
        shr t_data, #4                          '20 bit format

        call #read_in
        call #ackm
        mov h_data, data_byte                   'Move the contents of register 0xFD MSB of raw data
        shl h_data, #8                          'Make room for the LSB

        call #read_in
        or h_data, data_byte                    'Move the contents of register 0xFE
        call #ackm
        call #stops

{********************* Move the calibration data to shared memory ***************}

lock    lockset lockID wr,wc                    'Check the lock & get the lock
   if_c jmp #lock

        mov shared_mem, par
        wrlong digi_T1, shared_mem

        add shared_mem, #4
        wrlong digi_T2, shared_mem

        add shared_mem, #4
        wrlong digi_T3, shared_mem

        add shared_mem, #4
        wrlong digi_P1, shared_mem

        add shared_mem, #4
        wrlong digi_P2, shared_mem

        add shared_mem, #4
        wrlong digi_P3, shared_mem

        add shared_mem, #4
        wrlong digi_P4, shared_mem

        add shared_mem, #4
        wrlong digi_P5, shared_mem

        add shared_mem, #4
        wrlong digi_P6, shared_mem

        add shared_mem, #4
        wrlong digi_P7, shared_mem

        add shared_mem, #4
        wrlong digi_P8, shared_mem

        add shared_mem, #4
        wrlong digi_P9, shared_mem

        add shared_mem, #4
        wrlong digi_H1, shared_mem

        add shared_mem, #4
        wrlong digi_H2, shared_mem

        add shared_mem, #4
        wrlong digi_H3, shared_mem

        add shared_mem, #4
        wrlong digi_H4, shared_mem

        add shared_mem, #4
        wrlong digi_H5, shared_mem

        add shared_mem, #4
        wrlong digi_H6, shared_mem

        add shared_mem, #4
        wrlong t_data, shared_mem

        add shared_mem, #4
        wrlong p_data, shared_mem

        add shared_mem, #4
        wrlong h_data, shared_mem

        lockclr lockID

        waitcnt one_min, 0
        jmp #sample

{***************************Data and subroutine section***********************}

starts  or dira, data_pin                       'Set data pin to output
        or outa, data_pin                       'Set SDA HIGH
        waitpeq clk_pin, clk_pin
        andn outa, data_pin                     'Set SDA LOW
        waitpne clk_pin, clk_pin
starts_ret     ret

acks    andn dira, data_pin                     'set SDA to input
        waitpeq clk_pin, clk_pin
        waitpne clk_pin, clk_pin
        or dira, data_pin                       'set data_pin to output
acks_ret      ret

ackm    or dira, data_pin                       'ACKM - Set SDA to output
        andn outa, data_pin                     'Set SDA LOW
        waitpeq clk_pin, clk_pin
        waitpne clk_pin, clk_pin
ackm_ret      ret

nackm   or dira, data_pin                       'ACKM - Set SDA to output
        or outa, data_pin                       'Set SDA LOW
        waitpeq clk_pin, clk_pin
        waitpne clk_pin, clk_pin
        andn outa, data_pin
nackm_ret     ret

stops   or dira, data_pin
        andn outa, data_pin                     'STOP - Set SDA LOW
        waitpeq clk_pin, clk_pin
        or outa, data_pin                       'Set SDA HIGH
        waitpne clk_pin, clk_pin
        andn outa, data_pin
stops_ret     ret

sladrw  mov counter, #8                         'rx address 11101110 for BMEX80
        mov tmp, rx_addr_w                      'Copy the rx device address to working memory location
        rev tmp, #0                             'Reverse the order of rx address
        shr tmp, #24                            'Shift to LSBs for transmission

sla     test tmp, #1 wz
  if_nz or outa, data_pin                       'Send slave address
        shr tmp, #1
        waitpeq clk_pin, clk_pin
        waitpne clk_pin, clk_pin
        andn outa, data_pin                     'set SDA low
        djnz counter, #sla
sladrw_ret    ret


sladrr  mov counter, #8                         'rx address 11101110 for BME680
        mov tmp, rx_addr_r                      'Copy the rx device address to working memory location
        rev tmp, #0                             'Reverse the order of rx address
        shr tmp, #24                            'Shift to LSBs for transmission

sladr   test tmp, #1 wz
  if_nz or outa, data_pin                       'Send rx address
        shr tmp, #1
        waitpeq clk_pin, clk_pin
        waitpne clk_pin, clk_pin
        andn outa, data_pin                     'set SDA low
        djnz counter, #sladr
sladrr_ret   ret

read_in mov data_byte, #0
        mov counter, #8
        andn dira, data_pin                      'Set data_pin to input

read    waitpeq clk_pin, clk_pin
        mov tmp, ina
        test tmp, data_pin wz
  if_nz add data_byte, #1
        waitpne clk_pin, clk_pin
        cmp counter, #1 wz
  if_nz shl data_byte, #1
        djnz counter, #read
read_in_ret   ret

data_out mov counter, #8                        'Send the ID register address: $D0

datadrw test tmp, #1 wz
  if_nz or outa, data_pin                       'If bit 0 = 1 preset Data Pin HIGH
        shr tmp, #1
        waitpeq clk_pin, clk_pin
        waitpne clk_pin, clk_pin
        andn outa, data_pin                     'Set data pin LOW
        djnz counter, #datadrw
data_out_ret   ret


clk_pin       long  |<SCL_pin
data_pin      long  |<SDA_pin
sfreq         long  0
tmp           long  0
counter       long  0
rx_addr_w     long  %1110_1110                  'rx_addr WRITE mode
rx_addr_r     long  %1110_1111                  'rx_addr READ mode
reset_addr    long  %1110_0000                  '0xE0 Reset register address
reset         long  %1011_0110                  '0xB6 reset command
id_addr       long  %1101_0000                  'Device ID register address 0xD0
id_data       long  0
cal_addr      long  %1000_1000                  'Calibration data starting register address 0x88
calH_addr     long  %1110_0001                  'Calibration data for the remaining humidity 0xE1
digi_T1       long  0
digi_T2       long  0
digi_T3       long  0
digi_P1       long  0
digi_P2       long  0
digi_P3       long  0
digi_P4       long  0
digi_P5       long  0
digi_P6       long  0
digi_P7       long  0
digi_P8       long  0
digi_P9       long  0
digi_H1       long  0
digi_H2       long  0
digi_H3       long  0
digi_H4       long  0
digi_H5       long  0
digi_H6       long  0
ctl_meas      long  %1111_0100                  'Control measurement configuration register address 0xF4
ctl_meas_data long  %0010_0101
config        long  %1111_0101                  'Device configuration register address 0xF5
config_data   long  %0000_0000
ctl_hum       long  %1111_0010                  'Control humidity configuration register 0xF2
ctl_hum_data  long  %0000_0001
tph_msb       long  %1111_0111                  'Temp msb register address 0xF7
t_data        long  0
p_data        long  0
h_data        long  0
data_byte     long  0
one_min       long  sfreq * 60
lockID        long  0
shared_mem    long  0[21]
fit

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}