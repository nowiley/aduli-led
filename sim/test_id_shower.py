import os
import sys
from pathlib import Path
import typing
from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

NUM_LEDS = 50
NUM_FRAMES = 10

@cocotb.test()
async def test_a(dut):
    """Test for driving first pixel a correct color"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await ClockCycles(dut.clk, 2)  # check the pre-reset behavior

    # Reset
    dut.rst.value = 1
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    dut.rst.value = 0

    # Start Driving
    for frame in range(NUM_FRAMES):
        dut._log.info(f"#####Frame###### {frame}")
        for pix in range(NUM_LEDS):
            dut.next_led_request.value = pix

            if pix == 2 and frame == 3:
                dut._log.info("Pressing Button 1")
                dut.btn = 0b0010
            await ClockCycles(dut.clk, 1)

            # assert dut.color_valid.value == 0, "ColorValid should be 0 when recieving a new pixel request"
            await ClockCycles(dut.clk, 10)
            dut._log.info(f"Pixel# {pix}, GreenOut: {hex(dut.green_out.value)}, RedOut: {hex(dut.red_out.value)}, BlueOut: {hex(dut.blue_out.value)}, ColorValid: {dut.color_valid.value}, DisplayedFrameValid: {dut.displayed_frame_valid.value}")

def is_runner():
    """Moving pixel tester"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "calibration" / "id_shower.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "NUM_LEDS": NUM_LEDS,
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="id_shower",
        includes=[proj_path / "hdl"],
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="id_shower",
        test_module="test_id_shower",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()