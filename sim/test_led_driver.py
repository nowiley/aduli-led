import os
import sys
from pathlib import Path
import typing
from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

class FakeStrand():
    def __init__(self, strand_length: int):
        self.sampled_data = []
        self.num_pixels = strand_length
        self.translated_bits = []
        self.colors = []

    def add_sample(self, data):
        self.per_clock_data.append(data)
        return
    
    def clear_samples(self):
        self.per_clock_data = []
        return
    
    def translate(self):
        """Translates the sampled data into bits
        !!! assumes clock is 100MHz and samples are taken at 10ns intervals
        0 bit = 0.4us high, 0.85us low -> 40 cycles high, 85 cycles low
        1 bit = 0.8us high, 0.45us low -> 80 cycles high, 45 cycles low
        reset = >=50us low
        """
        #clear any previous data
        self.translated_bits = []
        #remove initial low samples RESET
        while self.sampled_data[0] == 0:
            self.sampled_data = self.sampled_data[1:]

        #begin translating
        while self.sampled_data:
            if len(self.sampled_data) < 125:
                print("Not enough for a bit, rest of the data is: ", self.sampled_data)
                break
            cur_segment = self.sampled_data[:125] # Grab the first 125 samples
            self.sampled_data = self.sampled_data[125:]
            #check if segment is a 1 bit
            if cur_segment[:80] == [1]*80:
                if cur_segment[80:] == [0]*45:
                    self.translated_bits.append(1)
                else:
                    print("Invalid 1 bit segment: ", cur_segment)
                    self.translated_bits.append("X")
            #check if segment is a 0 bit
            elif cur_segment[:40] == [1]*40:
                if cur_segment[40:] == [0]*85:
                    self.translated_bits.append(0)
                else:
                    print("Invalid 0 bit segment: ", cur_segment)
                    self.translated_bits.append("X")
            #check if segment is a reset
            elif cur_segment[:50] == [0]*50:
                self.translated_bits.append("R")
            #invalid segment
            else:
                print("Invalid segment: ", cur_segment)
                self.translated_bits.append("X")
        print ("Translated bits: ", self.translated_bits)
        return

    def translate_to_color(self):
        """Translates the bits into colors
        returns list of tuples [(G_1, R_1, B_1), (G_2, R_2, B_2), ...]
        """
        #clear any previous
        self.colors = []

        while self.translated_bits:
            if len(self.translated_bits) < 24:
                print("Not enough for a color, rest of the data is: ", self.translated_bits)
                break
            cur_color = self.translated_bits[:24]
            self.translated_bits = self.translated_bits[24:]
            green = hex("".join([str(x) for x in cur_color[:8]]))
            red = hex("".join([str(x) for x in cur_color[8:16]]))
            blue = hex("".join([str(x) for x in cur_color[16:24]]))
            self.colors.append((green, red, blue))
        print("Colors: ", self.colors)
        return
            


@cocotb.test()
async def test_a(dut):
    """Test for driving first pixel a correct color"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 3)
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0
    dut.green_in.value = 0x00
    dut.red_in.value = 0xAA
    dut.blue_in.value = 0x00
    dut._log.info("Setting color to G00 RAA B00")
    dut._log.info("Ready to be high")
    await RisingEdge(dut.clk_in)
    assert dut.ready_out.value == 1, "Ready should be high after reset"
    await ClockCycles(dut.clk_in, 3)
    assert dut.ready_out.value == 1, "Should still be ready after a few cycles"
    assert dut.strand_out.value == 0, "Strand should be low if not sending data"
    dut.data_in.valid = 1  # start sending data
    await ClockCycles(dut.clk_in, 1)
    dut.data_in.valid = 0
    dut._log.info("Checking correct protocol")
    bitstring = 0b00000000_10101010_00000000
    # // Assuming 100MHz clock, 10ns period ->
    # // 0 bit = 0.4us high, 0.85us low -> 40 cycles high, 85 cycles low
    # // 1 bit = 0.8us high, 0.45us low -> 80 cycles high, 45 cycles low
    # // reset = 50us low
    assert (
        dut.strand_out.value == 1
    ), "Strand should be high immediately after valid data in"
    for i in range(25):
        cur_bit = (bitstring >> (24 - i)) & 0x01
        dut._log.info(f"Checking bit {i} = {cur_bit}")
        assert dut.strand_out.value == 1, "Strand should be high at the start"
        if cur_bit == 0:
            dut._log.info("Checking T0H 40 cycles high")
            for j in range(40):
                await ClockCycles(dut.clk_in, 1)
                assert dut.data_out.value == 1, "Data should be high in T0H period"
            dut._log.info("Checking T0L 85 cycles low")
            for j in range(85):
                await ClockCycles(dut.clk_in, 1)
                assert dut.data_out.value == 0, "Data should be low in T0L period"
        else:
            dut._log.info("Checking T1H 80 cycles high")
            for j in range(80):
                await ClockCycles(dut.clk_in, 1)
                assert dut.data_out.value == 1, "Data should be high in T1H period"
            dut._log.info("Checking T1L 45 cycles low")
            for j in range(45):
                await ClockCycles(dut.clk_in, 1)
                assert dut.data_out.value == 0, "Data should be low in T1L period"

@cocotb.test()
async def test_b(dut):
    """Test for driving multiple pixels with correct color less info"""
    fs = FakeStrand(5)
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 3)
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0
    color_cycle = [[0xAA, 0x00, 0x00], 
                   [0x00, 0xAA, 0x00], 
                   [0x00, 0x00, 0xAA], 
                   [0xAA, 0xAA, 0xAA], 
                   [0x00, 0x00, 0x00]]
    for color in color_cycle:
        dut.green_in.value = color[0]
        dut.red_in.value = color[1]
        dut.blue_in.value = color[2]
        dut.data_in.valid = 1
        dut._log.info(f"Setting color to G{color[0]:02X} R{color[1]:02X} B{color[2]:02X}")
        await RisingEdge(dut.clk_in)
        dut.data_in.valid = 0
        for i in range(24):
            await RisingEdge(dut.clk_in)
            fs.add_sample(dut.data_out.value)
    
    fs.translate()
    fs.translate_to_color()
            


def is_runner():
    """LED Driver Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "led_driver.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="led_driver",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="led_driver",
        test_module="test_led_driver",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
