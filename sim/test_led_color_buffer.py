import os
import sys
from pathlib import Path
import typing
from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

NUM_LEDS = 90
LED_ADDRED_WIDTH = 10
CAMERA_COLOR_WIDTH = 16

@cocotb.test()
async def test_a(dut):
    """Test for driving first pixel a correct color"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_pixel, 14, units="ns").start())
    cocotb.start_soon(Clock(dut.clk_led, 10, units="ns").start())

    await ClockCycles(dut.clk_pixel, 2)  # check the pre-reset behavior

    # Reset
    dut.rst.value = 1
    await ClockCycles(dut.clk_pixel, 3)
    await FallingEdge(dut.clk_pixel)
    dut.rst.value = 0

    # Writing to all pixels
    for i in range(NUM_LEDS):
        dut.camera_color.value = 0xAAAA
        dut.led_lookup_address.value = i
        dut.led_color_buffer_update_enable.value = 1
        await ClockCycles(dut.clk_pixel, 1)
    
    # Check that if led_color_buffer_update_enable is low, buffer is not updated
    for i in range(NUM_LEDS):
        dut.camera_color.value = 0x5555 
        dut.led_color_buffer_update_enable.value = 0
        dut.led_lookup_address.value = i
        await ClockCycles(dut.clk_pixel, 1)

    # Updating selected pixels, also test for out of bounds address
    addresses = [50,  0,  1, 99, 80, 95, 26,  3, 90, 26]
    colors    = [37, 37, 37, 37, 37, 99, 37, 37, 37, 37]
    for addr, color in zip(addresses, colors):
        dut.camera_color.value = color
        dut.led_lookup_address.value = addr
        dut.led_color_buffer_update_enable.value = 1
        await ClockCycles(dut.clk_pixel, 1)

    ## READING OUT BUFFER
    for i in range(NUM_LEDS):
        dut.led_lookup_address.value = i
        await ClockCycles(dut.clk_led, 1)
        if i in addresses:
            assert dut.led_color.value == colors[addresses.index(i)], f"Error at address {i}"
        else:
            assert dut.led_color.value == 0xAAAA, f"Error at address {i}, expected 0xAAAA, got {dut.led_color.value:x}"

    

def is_runner():
    """Moving pixel tester"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "calibration" / "led_color_buffer.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "NUM_LEDS": NUM_LEDS,
        "LED_ADDRED_WIDTH": LED_ADDRED_WIDTH,
        "CAMERA_COLOR_WIDTH": CAMERA_COLOR_WIDTH
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="led_color_buffer",
        includes=[proj_path / "hdl"],
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="led_color_buffer",
        test_module="test_led_color_buffer",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()