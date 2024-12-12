# aduli-led

Auto-calibrating Display using Unconstrained Layouts of Individually-addressable LEDs

### Hardware Used
- AMD Spartan-7 FPGA
- WS2812b LED strands: sequentially addressed LEDs used to display content.
- OV5640 Camera Module: used both for calibration and input data for displaying on the LED display.
- HW-221 level shifter: drives the 5V logic from the 3.3v logic of the Urbana board.

### Useful commands:

#### Build on Vivado farm

```
lab-bc run ./ obj
```

#### Flash to FPGA

```
openFPGALoader -b arty_s7_50 obj/final.bit
```
