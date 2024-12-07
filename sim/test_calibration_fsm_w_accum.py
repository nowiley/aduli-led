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
ACTIVE_H = 12
ACTIVE_V = 8
H_PORCH = 2
V_PORCH = 2
WAIT_CYCLES = 1


@cocotb.test()
async def test_a(dut):
    """Test for driving first pixel a correct color"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_pixel, 10, units="ns").start())

    await ClockCycles(dut.clk_pixel, 2)  # check the pre-reset behavior

    # Reset
    dut.rst.value = 1
    await ClockCycles(dut.clk_pixel, 3)
    await FallingEdge(dut.clk_pixel)
    dut.rst.value = 0
    dut.read_request.value = 0
    
    for detect_1 in [1, 0, 1, 1]:
        dut.increment_id.value = 1
        dut.displayed_frame_valid.value = 0
        await ClockCycles(dut.clk_pixel, 2)
        dut.displayed_frame_valid.value = 1
        dut.increment_id.value = 0
        await ClockCycles(dut.clk_pixel, 2)
        dut.new_frame_in.value = 1
        await ClockCycles(dut.clk_pixel, 1)
        for (start_v, start_h) in [ (0, 0)]:
            for v in range(start_v, ACTIVE_V + V_PORCH):
                for h in range(start_h, ACTIVE_H + H_PORCH):
                    await FallingEdge(dut.clk_pixel)
                    #active draw
                    dut.detect_1.value = detect_1
                    dut.hcount_in.value = h
                    dut.vcount_in.value = v
                    dut.new_frame_in.value = 0 
            dut.new_frame_in.value = 1
            await ClockCycles(dut.clk_pixel, 1)
            dut.new_frame_in.value = 0
            await ClockCycles(dut.clk_pixel, 1)

                    
                    

    rec_frame_buf = []
    dut._log.info("GOING TO REAd")

    await ClockCycles(dut.clk_pixel, 3)
    for v in range(ACTIVE_V):
        for h in range(ACTIVE_H):
            if v % 4 == 0 and h % 4 == 0:
                dut.read_request.value = 1
                dut.hcount_in.value = h
                dut.vcount_in.value = v
                await FallingEdge(dut.clk_pixel)
                await ClockCycles(dut.clk_pixel,10)
                assert dut.read_out.value == 0b1011, f"Read out should be 0b1011, but got {dut.read_out.value}"  



                


def is_runner():
    """Moving pixel tester"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "calibration" / "calibration_fsm_w_accum.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "NUM_LEDS": NUM_LEDS,
        "ACTIVE_H_PIXELS": ACTIVE_H,
        "ACTIVE_LINES": ACTIVE_V,
        "WAIT_CYCLES": WAIT_CYCLES
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="calibration_fsm_w_accum",
        includes=[proj_path / "hdl"],
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="calibration_fsm_w_accum",
        test_module="test_calibration_fsm_w_accum",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()