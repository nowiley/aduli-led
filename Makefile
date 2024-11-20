default: build

build:
	lab-bc run ./ obj

flash:
	openFPGALoader -b arty_s7_50 obj/final.bit
