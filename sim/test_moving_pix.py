import os
import sys
from pathlib import Path
import typing
from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

NUM_LEDS = 5
NUM_FRAMES_PER_LED = 3


@cocotb.test()
async def test_a(dut):
    """Test for driving first pixel a correct color"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    await ClockCycles(dut.clk_in, 2)  # check the pre-reset behavior

    # Reset
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 3)
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0
    dut.next_led_request.value = 0

    # Start Driving
    for pix in range(NUM_LEDS):
        for frame in range(NUM_FRAMES_PER_LED):
            for request in range(NUM_LEDS):
                # Iterate through the strand
                await FallingEdge(dut.clk_in)
                dut.next_led_request.value = request
                await FallingEdge(dut.clk_in)
                if pix == request:
                    assert dut.green_out.value == 0xFF
                    assert dut.red_out.value == 0xFF
                    assert dut.blue_out.value == 0xFF
                else:
                    assert dut.green_out.value == 0
                    assert dut.red_out.value == 0
                    assert dut.blue_out.value == 0
                

def is_runner():
    """Moving pixel tester"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "driver" / "moving_pix.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "NUM_LEDS": NUM_LEDS,
        "FRAMES_PER_LED": NUM_FRAMES_PER_LED,
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="moving_pix",
        includes=[proj_path / "hdl"],
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="moving_pix",
        test_module="test_moving_pix",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
