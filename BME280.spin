{BME280 low power pressure, temperature, and humidity sensor
 using the I2C Bus specification.

 Version 2:
 Added timing parameters to closely adhere to the I2C specification.
 Optomized code by statically defining 8 bit addresses in reverse bit order and
 removing the code required to reverse and shift the address for MSB first transmission.

 Fixed the pressure compensation module

┌──────────────────────────────────────────┐
│ BME280                                   │
│ Author: James Rike                       │
│ Copyright (c) 2023 Seapoint Software     │
│ See end of file for terms of use.        │
└──────────────────────────────────────────┘

}


CON
  _clkmode = xtal1 + pll16x      'Standard clock mode * crystal frequency = 80 MHz
  _xinfreq = 5_000_000

  SDA_pin = 18
  SCL_pin = 17

  T_buf   = 65                  'Minimum of 1.3 usec
  T_su    = 48                  'Minimum of .6 usec
  T_hdSr  = 35                  'Minimum of .6 usec
  T_hdSa  = 25                  'Minimum of .6 usec
  T_suDat = 16                  'Minimum of .6 usec


VAR
  long parT1, parT2, parT3
  long parP1, parP2, parP3, parP4, parP5, parP6, parP7, parP8, parP9
  long parH1, parH2, parH3, parH4, parH5, parH6, adc_T, adc_P, adc_H
  long t_fine
  long semID
  byte cog

OBJ
  num   :       "Simple_Numbers"
  pst   :       "Parallax Serial Terminal"
  'dbg   :       "PASDebug"      '<---- Add for Debugger

PUB Start                       'Cog start method
  if not semID := locknew       'If checked out a lock
    parT1 := semID
    cog := cognew(@_entry, @parT1) + 1
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
    ThirtySecInterval(1)
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
    pst.str(num.decx(H//1000,2))
    pst.str(string(" %"))
    pst.NewLine
    pst.str(string("mBars: "))
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

var1 := ((((adc_T >> 3) - (parT1 << 1))) * parT2) >> 11
var2 := (((((adc_T >> 4) - parT1) * ((adc_T >> 4) - parT1)) >> 12) * parT3) >> 14
t_fine := var1 + var2
T := (t_fine * 5 + 128) >> 8
return T

PRI bme280_compensate_H :H

'Returns humidity in %RH as unsigned 32 bit integer in Q22.10 format
' (22 integer and 10 fractional bits).
'Output value of 47445 represents 47445/1024 = 46.333 %RH

H := (t_fine - 76800)
H := (((((adc_H << 14) - (parH4 << 20) - (parH5 * H)) + 16384) >> 15) * (((((((H * parH6) >> 10) * (((H * parH3) >> 11) + 32768)) >> 10) + 2097152) * parH2 + 8192) >> 14))
H := (H - (((((H >> 15) * (H >> 15)) >> 7) * parH1) >> 4))

if (H < 0)
  H := 0

if (H > 419430400)
  H := 419430400

return (H >> 12)

PRI BME280_compensate_P :p | var1, var2

' Returns pressure in Pa as unsigned 32 bit integer.
'Output value of 96386 equals 96386 Pa = 963.86 hPa

var1 := ((t_fine) ~> 1) - 64000
var2 := (((var1 ~> 2) * (var1 ~> 2)) ~> 11 ) * (~parP6)
var2 := var2 + ((var1 * (~~parP5)) << 1)
var2 := (var2 ~> 2) + ((~~parP4) << 16)
var1 := (((~parP3 * (((var1 ~> 2) * (var1 ~> 2)) ~> 13 )) ~> 3) + (((~~parP2) * var1) ~> 1)) ~> 18
var1 :=((((32768 + var1)) * (||parP1)) ~> 15)
if (var1 == 0)
  return 0                      'avoid exception caused by division by zero

p := ||(((((1048576) - adc_P) - (var2 >> 12))) * 3125)

if (p < $80000000)
  p := (||p << 1) / (var1)
else
  p := (||p / var1) * 2

var1 := ((~~parP9) * ((((||p >> 3) * (||p ~> 3)) ~> 13))) ~> 12
var2 := (((||p >> 2)) * (~~parP8)) ~> 13
p := (||p + ((var1 + var2 + ~parP7) ~> 4))
return ||p

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
        call #starts                            'Send START to the sensor (rx), sets clock and data pins low (26 + ticks)
        call #devadrw                           'Write to device address 0x77
        call #acks

        mov tmp, dev_adr_reset                  '0xE0 Reset register address
        call #data_out
        call #acks

        mov tmp, dev_reset                      '0xB6 reset command
        call #data_out
        call #acks
        call #stops
        call #Tbuf

        '****************End of soft reset*****************

        mov time, cnt
        add time, sfreq/500
        waitcnt time, 0

        '**************Start of read device ID*************

        call #starts                            'Send start
        call #devadrw                           'Write to device address 0x77
        call #acks                              'Bit 9 ACK - End of write

        mov tmp, dev_adr_id                     'Device ID register address 0xD0
        call #data_out                          'Send the address
        call #acks                              'Bit 9 ACK

        call #startr                            'Send start
        call #devadrr                           'Read from device address 0x77
        call #acks                              'Bit 9 ACK

        call #read_in                           'Read the data
        call #nackm                             'NACKM
        call #stops                             'End of transaction
        mov id_data, data_byte                  'Device ID data = 0x61
        call #Tbuf                              'Ensure proper delay between stop and start
'       wrlong id_data, shared_mem              'Write data to shared memory

        '********************Get calibration data*************

        call #starts                            'Send START
        call #devadrw                           'Write to device address 0x77
        call #acks                              'Bit 9 ACK - End of write

        mov tmp, cal_addr                       'Lower byte of p_T1 at 0x88
        call #data_out                          'Write the data byte
        call #acks                              'Bit 9 ACK - End of write

        call #startr                            'Start the burst read at address 0x88
        call #devadrr                           'Send the READ
        call #acks                              'Bit 9 ACK - End of write

        call #read_in                           'READ the data byte
        call #ackm                              'Bit 9 ACKM - End of write
        mov p_T1, data_byte                  'Move the contents of register 0x88 to p_T1 parameter

        call #read_in                            'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x89 to temp data
        shl tmp, #8
        or p_T1, tmp                         'Move the upper byte into p_T1 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_T2, data_byte                  'Move the contents of register 0x8a to p_T2 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x8b to temp data
        shl tmp, #8
        or p_T2, tmp                         'Move the upper byte into p_T2 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_T3, data_byte                  'Move the contents of register 0x8c to p_T3 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x8d to temp data
        shl tmp, #8
        or p_T3, tmp                         'Move the upper byte into p_T3 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P1, data_byte                  'Move the contents of register 0x8e to p_P1 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x8f to temp data
        shl tmp, #8
        or p_P1, tmp                         'Move the upper byte into p_P1 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P2, data_byte                  'Move the contents of register 0x90 to p_P2 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x91 to temp data
        shl tmp, #8
        or p_P2, tmp                         'Move the upper byte into p_P2 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P3, data_byte                  'Move the contents of register 0x92 to p_P3 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x93 to temp data
        shl tmp, #8
        or p_P3, tmp                         'Move the upper byte into p_P3 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P4, data_byte                  'Move the contents of register 0x94 to p_P4 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x95 to temp data
        shl tmp, #8
        or p_P4, tmp                         'Move the upper byte into p_P4 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P5, data_byte                  'Move the contents of register 0x96 to p_P5 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x97 to temp data
        shl tmp, #8
        or p_P5, tmp                         'Move the upper byte into p_P5 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P6, data_byte                  'Move the contents of register 0x98 to p_P6 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x99 to temp data
        shl tmp, #8
        or p_P6, tmp                         'Move the upper byte into p_P6 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P7, data_byte                  'Move the contents of register 0x9a to p_P7 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x9b to temp data
        shl tmp, #8
        or p_P7, tmp                         'Move the upper byte into p_P7 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P8, data_byte                  'Move the contents of register 0x9c to p_P8 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x9d to temp data
        shl tmp, #8
        or p_P8, tmp                         'Move the upper byte into p_P8 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_P9, data_byte                  'Move the contents of register 0x9e to p_P2 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0x9f to temp data
        shl tmp, #8
        or p_P9, tmp                         'Move the upper byte into p_P2 parameter

        call #read_in                           'READ the data byte
        call #nackm
        call #stops
        call #Tbuf
        mov p_H1, data_byte                  'Move the contents of register 0xA0 to p_H1 parameter

        {*******Get the last part of humidity calibration data starting at $E1******}

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, calH_addr                      'Humidity calibration register = $E1
        call #data_out
        call #acks

        call #startr
        call #devadrr
        call #acks
                                                'READ the data byte
        call #read_in
        call #ackm
        mov p_H2, data_byte                  'Move the contents of register 0xe1 to p_H2 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xe2 to temp data
        shl tmp, #8
        or p_H2, tmp                         'Move the upper byte into p_H2 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_H3, data_byte                  'Move the contents of register 0xe3 to p_H3 parameter

        call #read_in                           'READ the data byte
        call #ackm
        mov p_H4, data_byte                  'Move contents of register 0xe4 to p_H4 bits[11:4]
        shl p_H4, #4

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xe5 to temp data
        and tmp, $0F
        or p_H4, tmp                         'Move bits[3:0] into p_H4 parameter

        mov tmp, data_byte                      'Move the contents of register 0xe5 to temp data
        and tmp, $F0                            'Move bits[7:4] into p_H5 bits[3:0]
        shr tmp, #4
        or p_H5, tmp

        call #read_in                           'READ the data byte
        call #ackm
        mov tmp, data_byte                      'Move the contents of register 0xe6 to p_H5 bits[11:4]
        shl tmp, #4
        or p_H5, tmp

        call #read_in                           'READ the data byte
        mov p_H6, data_byte                  'Move the contents of register 0x6 to p_H6 parameter
        call #nackm
        call #stops
        call #Tbuf

{************* Copy shared memory address and get the lock ID ************}

        mov shared_mem, par
        rdlong lockID, shared_mem

{************************** Configure the sensor *************************}

sample  call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, ctl_hum                        'Register address: $F2
        call #data_out
        call #acks

        mov tmp, ctl_hum_data                   'Set sampling and mode
        call #data_out
        call #nackm
        call #stops
        call #Tbuf

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, ctl_meas                       'Register address: $F4
        call #data_out
        call #acks

        mov tmp, ctl_meas_data                  'Set sampling and mode
        call #data_out
        call #acks

        mov tmp, config                         'Register address: $F5
        call #data_out
        call #acks

        mov tmp, config_data
        call #data_out
        call #nackm
        call #stops
        call #Tbuf

{*********************** Read the raw sensor data for P, T, and H ********************}

        call #starts
        call #devadrw                           'Write to device address 0x77
        call #acks                              'End of WRITE

        mov tmp, tph_msb                        'Pressure MSB register = $F7
        call #data_out
        call #acks

        call #startr
        call #devadrr
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
        mov t_data, data_byte                   'Move the contents of register 0xFa MSB of raw data
        shl t_data, #8                          'Make room for the next byte

        call #read_in
        call #ackm
        or t_data, data_byte                    'Move the contents of register 0xFb
        shl t_data, #8                          'Make room for the first bit of the next byte

        call #read_in
        call #ackm
        or t_data, data_byte                    'Move the contents of register 0xFc
        shr t_data, #4                          '20 bit format

        call #read_in
        call #ackm
        mov h_data, data_byte                   'Move the contents of register 0xFd MSB of raw data
        shl h_data, #8                          'Make room for the LSB

        call #read_in
        or h_data, data_byte                    'Move the contents of register 0xFe
        call #ackm
        call #stops
        call #Tbuf

{********************* Move the calibration data to shared memory ***************}

lock    lockset lockID wr,wc                    'Check the lock & get the lock
   if_c jmp #lock

        mov shared_mem, par
        wrlong p_T1, shared_mem

        add shared_mem, #4
        wrlong p_T2, shared_mem

        add shared_mem, #4
        wrlong p_T3, shared_mem

        add shared_mem, #4
        wrlong p_P1, shared_mem

        add shared_mem, #4
        wrlong p_P2, shared_mem

        add shared_mem, #4
        wrlong p_P3, shared_mem

        add shared_mem, #4
        wrlong p_P4, shared_mem

        add shared_mem, #4
        wrlong p_P5, shared_mem

        add shared_mem, #4
        wrlong p_P6, shared_mem

        add shared_mem, #4
        wrlong p_P7, shared_mem

        add shared_mem, #4
        wrlong p_P8, shared_mem

        add shared_mem, #4
        wrlong p_P9, shared_mem

        add shared_mem, #4
        wrlong p_H1, shared_mem

        add shared_mem, #4
        wrlong p_H2, shared_mem

        add shared_mem, #4
        wrlong p_H3, shared_mem

        add shared_mem, #4
        wrlong p_H4, shared_mem

        add shared_mem, #4
        wrlong p_H5, shared_mem

        add shared_mem, #4
        wrlong p_H6, shared_mem

        add shared_mem, #4
        wrlong t_data, shared_mem

        add shared_mem, #4
        wrlong p_data, shared_mem

        add shared_mem, #4
        wrlong h_data, shared_mem

        lockclr lockID

        add delay, #60
timer   mov time, cnt
        add time, sfreq
        waitcnt time, time
        djnz delay, #timer
        jmp #sample

{***************************Data and subroutine section***********************}

starts  or dira, data_pin                       'Set data pin to output
        or outa, data_pin                       'Set SDA HIGH
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        call #ThdSa                             'ThdSta
        andn outa, data_pin                     'Set SDA
        call #ThdSa                             'ThdSta is same value as ThdSa delay
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
starts_ret     ret

startr  or dira, data_pin                       'Set data pin to output
        call #ThdSr                             'ThdSr
        or outa, data_pin                       'Set SDA HIGH
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        call #ThdSr                             'TsuSr
        andn outa, data_pin                     'Set SDA
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
startr_ret     ret

acks    andn dira, data_pin                     'set SDA to input
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        or dira, data_pin                       'Set SDA to output
acks_ret      ret

ackm    or dira, data_pin                       'ACKM - Set SDA to output
        andn outa, data_pin                     'Set SDA LOW
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
ackm_ret      ret

nackm   or dira, data_pin                       'ACKM - Set SDA to output
        or outa, data_pin                       'Set SDA LOW
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'Set SDA LOW
nackm_ret     ret

stops   or dira, data_pin                       'Set data pin to output
        andn outa, data_pin                     'Set SDA LOW
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        call #Tsu                               'TsuSto
        or outa, data_pin                       'Set SDA HIGH - STOP
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'Set SDA LOW
stops_ret     ret

devadrw mov counter, #8                         'Address %1110_1110 for device address 0x77 WRITE
        mov tmp, dev_adr_w                      'Copy the device address to tmp -> MSB first out

dev_w   test tmp, #1 wz                         'Test bit 1 and set wz
  if_nz or outa, data_pin                       'If bit 1 is not zero set data pin high
        call #TsuDat                            'TsuDat
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'Set SDA LOW
        shr tmp, #1                             'Shift tmp address register right 1 bit
        djnz counter, #dev_w                    'Check for end of byte
devadrw_ret    ret

devadrr mov counter, #8                         'Address %1110_1111 for device address 0x77 READ
        mov tmp, dev_adr_r                      'Copy the device address

devadr  test tmp, #1 wz
  if_nz or outa, data_pin                       'Send device address
        call #TsuDat                            'TsuDat
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'set SDA low
        shr tmp, #1                             'Shift tmp address register right 1 bit
        djnz counter, #devadr                   'Check for end of byte
devadrr_ret   ret

read_in mov data_byte, #0                       'Initialize the data destination byte
        mov counter, #8                         'Byte length
        andn dira, data_pin                     'Set data_pin to input

read    waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        mov tmp, ina                            'Read SDA pin
        test tmp, data_pin wz                   'Test bit read
  if_nz add data_byte, #1                       'Set bit
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        cmp counter, #1 wz                      'Check for end of byte
  if_nz shl data_byte, #1                       'Shift left if not end of byte
        djnz counter, #read                     'Loop back for next bit read or return
read_in_ret   ret

data_out mov counter, #8                        'Set bit counter to byte size

datadrw test tmp, #1 wz                         'Test bit 1 and set wz
  if_nz or outa, data_pin                       'If bit 0 = 1 set Data Pin HIGH
        shr tmp, #1                             'Shift tmp address register right 1 bit
        waitpeq clk_pin, clk_pin                'Wait for SCL HIGH
        waitpne clk_pin, clk_pin                'Wait for SCL LOW
        andn outa, data_pin                     'Set data pin LOW
        djnz counter, #datadrw                  'Check for end of byte
data_out_ret   ret

Tsu     mov time, cnt                           'Get current system clock time
        add time, Tsu_mem                       'Add 48 ticks to current time
        waitcnt time, Tsu_mem                   'Wait 48 clock ticks
Tsu_ret   ret

ThdSr   mov time, cnt                           'Get current system clock time (This delay is used for TsuSta)
        add time, ThdSr_mem                     'Add n ticks to current time
        waitcnt time, ThdSr_mem                 'Wait n clock ticks (See CON seetings for tick count)
ThdSr_ret ret

ThdSa   mov time, cnt                           'Get current system clock time (This delay is used for TsuSta)
        add time, ThdSr_mem                     'Add n ticks to current time
        waitcnt time, ThdSa_mem                 'Wait n clock ticks (See CON seetings for tick count)
ThdSa_ret ret

Tbuf    mov time, cnt                           'Get current system clock time
        add time, Tbuf_mem                      'Add 104 ticks to current time + 4 buffer
        waitcnt time, Tbuf_mem                  'Wait 104 clock ticks + 4 buffer
Tbuf_ret   ret

TsuDat  mov time, cnt                           'Get current system clock time
        add time, TsuDat_mem                    'Add 10 ticks to current time
        waitcnt time, TsuDat_mem                'Wait 10 clock ticks
TsuDat_ret ret

DAT

clk_pin       long  |<SCL_pin
data_pin      long  |<SDA_pin
sfreq         long  0
tmp           long  0
counter       long  0
dev_adr_reset long  %0000_0111                  '0xe0 reset address
dev_reset     long  %0110_1101                  '0xb6 reset command
dev_adr_w     long  %0111_0111                  '0x77 with r/w bit = 0 (write)
dev_adr_r     long  %1111_0111                  '0x77 with r/w bit = 1 (read)
dev_adr_id    long  %0000_1011                  '0xd0 id address
id_data       long  0
cal_addr      long  %0001_0001                  'Calibration data starting register address 0x88
calH_addr     long  %1000_0111                  'Calibration data for the remaining humidity 0xE1
p_T1       long  0
p_T2       long  0
p_T3       long  0
p_P1       long  0
p_P2       long  0
p_P3       long  0
p_P4       long  0
p_P5       long  0
p_P6       long  0
p_P7       long  0
p_P8       long  0
p_P9       long  0
p_H1       long  0
p_H2       long  0
p_H3       long  0
p_H4       long  0
p_H5       long  0
p_H6       long  0
ctl_meas      long  %0010_1111                  'Control measurement configuration register address 0xF4
ctl_meas_data long  %1010_0100
config        long  %1010_1111                  'Device configuration register address 0xF5
config_data   long  %0000_0000
ctl_hum       long  %0100_1111                  'Control humidity configuration register 0xF2
ctl_hum_data  long  %1000_0000
tph_msb       long  %1110_1111                  'Temp msb register address 0xF7
t_data        long  0
p_data        long  0
h_data        long  0
data_byte     long  0
lockID        long  0
time          long  0
delay         long  0
Tbuf_mem      long  T_buf
Tsu_mem       long  T_su
ThdSr_mem     long  T_hdSr
ThdSa_mem     long  T_hdSa
TsuDat_mem    long  T_suDat
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