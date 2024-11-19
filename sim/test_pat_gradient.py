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


@cocotb.test()
async def test_a(dut):
    """Test for driving first pixel a correct color"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    await ClockCycles(dut.clk_in, 2)  # check the pre-reset behavior

    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 3)
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0

    dut.next_led_request.value = 0

    assert dut.red_out.value == 0, "Red should be 0"
    assert dut.green_out.value == 0, "Green should be 0"
    assert dut.blue_out.value == 0, "Blue should be 0"
    assert dut.color_valid.value == 0, "Color valid should be 0"

    await ClockCycles(dut.clk_in, 1)
    dut._log.info("Setup complete")

    # // Assuming 100MHz clock, 10ns period ->
    # // 0 bit = 0.4us high, 0.85us low -> 40 cycles high, 85 cycles low
    # // 1 bit = 0.8us high, 0.45us low -> 80 cycles high, 45 cycles low
    # // reset = 50us low

    await ClockCycles(dut.clk_in, 1)
    assert dut.color_valid.value == 1, "Color valid should be 1"

    for led_idx in range(NUM_LEDS):
        dut.next_led_request.value = (led_idx + 1) % NUM_LEDS
        await ClockCycles(dut.clk_in, 100)  # let's demo waiting for a bit


def is_runner():
    """LED Driver Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "pattern" / "pat_gradient.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "NUM_LEDS": NUM_LEDS,
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="pat_gradient",
        includes=[proj_path / "hdl"],
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="pat_gradient",
        test_module="test_pat_gradient",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
