import os
import sys
import math
from pathlib import Path
import typing
from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

NUM_LEDS = 50


@cocotb.test()
async def test_a(dut):
    """Test for driving first pixel a correct color"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    await ClockCycles(dut.clk_in, 2)  # check the pre-reset behavior

    dut.start_in.value = 0
    dut.led_display_valid_in.value = 0
    dut.calibration_state_in.value = 0

    # Reset
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 1)
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0

    await ClockCycles(dut.clk_in, 2)

    dut.start_in.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.start_in.value = 0
    await FallingEdge(dut.clk_in)

    for sel_bit in range(math.ceil(math.log2(NUM_LEDS))):
        assert dut.led_addr_bit_sel_start_out.value == 1, "Selected bit should be valid"
        for i in range(10):
            assert dut.state.value == 1, "Should be in LED display calibration state"
            assert (
                dut.calibration_first_out.value == 1
            ) or sel_bit != 0, "First should be high on first cycle"
            assert (
                dut.led_addr_bit_sel_out.value == sel_bit
            ), "Should be selecting correct bit"

            await ClockCycles(dut.clk_in, 1)  # pretend we're doing something

        dut.led_display_valid_in.value = 1  # pretend we're done
        await ClockCycles(dut.clk_in, 1)
        dut.led_display_valid_in.value = 0  # pretend we're done
        await FallingEdge(dut.clk_in)
        assert dut.calibration_start_out.value == 1, "Should be starting calibration"

        await ClockCycles(dut.clk_in, 10)  # pretend it took forever to respond

        dut.calibration_state_in.value = 1  # anything but 0

        for i in range(10):
            assert dut.state.value == 2, "Should be in calib display state"
            await ClockCycles(dut.clk_in, 1)
            assert (
                dut.calibration_start_out.value == 0
            ), "Should be done starting calibration"
            assert dut.calibration_first_out.value == 0, "First should be low"

        dut.calibration_state_in.value = 0  # we're back at IDLE
        await ClockCycles(dut.clk_in, 1)
        await FallingEdge(dut.clk_in)

    assert dut.state.value == 0, "Should be back in IDLE state"


def is_runner():
    """Moving pixel tester"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "aduli_fsm.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "NUM_LEDS": NUM_LEDS,
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="aduli_fsm",
        includes=[proj_path / "hdl"],
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="aduli_fsm",
        test_module="test_aduli_fsm",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
