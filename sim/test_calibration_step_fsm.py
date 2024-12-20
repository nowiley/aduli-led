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
ACTIVE_H = 128
ACTIVE_V = 72
H_PORCH = 6
V_PORCH = 6
WAIT_CYCLES = 10
LED_ADDRESS_WIDTH = 4


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
        dut.start_calibration_step.value = 1
        await ClockCycles(dut.clk_pixel, WAIT_CYCLES + 1)
        dut.start_calibration_step.value = 0
        dut.new_frame_in.value = 1
        await ClockCycles(dut.clk_pixel, 1)
        for start_v, start_h in [(0, 0)]:
            for v in range(start_v, ACTIVE_V + V_PORCH):
                for h in range(start_h, ACTIVE_H + H_PORCH):
                    await FallingEdge(dut.clk_pixel)
                    # active draw
                    dut.detect_1.value = detect_1
                    dut.hcount_in.value = h
                    dut.vcount_in.value = v
                    dut.new_frame_in.value = 0

                    if v == ACTIVE_V and h == ACTIVE_H:
                        dut.new_frame_in.value = 1

    rec_frame_buf = []
    dut._log.info("GOING TO REAd")

    await ClockCycles(dut.clk_pixel, 3)
    for v in range(ACTIVE_V):
        for h in range(ACTIVE_H):
            if v % 4 == 0 and h % 4 == 0:
                dut.read_request.value = 1
                dut.hcount_in.value = h
                dut.vcount_in.value = v
                await ClockCycles(dut.clk_pixel, 3)
                await FallingEdge(dut.clk_pixel)
                assert (
                    dut.read_out.value == 0b1011
                ), f"Read out should be 0b1011, but got {dut.read_out.value}"


@cocotb.test()
async def test_b(dut):
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
        dut.start_calibration_step.value = 1
        await ClockCycles(dut.clk_pixel, 2)
        # dut.increment_id.value = 0
        await ClockCycles(dut.clk_pixel, 2)
        dut.new_frame_in.value = 1
        await ClockCycles(dut.clk_pixel, 1)
        for start_v, start_h in [(0, 0)]:
            for v in range(start_v, ACTIVE_V + V_PORCH):
                for h in range(start_h, ACTIVE_H + H_PORCH):
                    await FallingEdge(dut.clk_pixel)
                    # active draw
                    dut.detect_1.value = detect_1
                    dut.hcount_in.value = h
                    dut.vcount_in.value = v
                    dut.new_frame_in.value = 0
            dut.new_frame_in.value = 1
            await ClockCycles(dut.clk_pixel, 1)
            dut.new_frame_in.value = 0
            await ClockCycles(dut.clk_pixel, 1)

@cocotb.test()
async def test_c(dut):
    """Test for overwriting"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_pixel, 10, units="ns").start())

    await ClockCycles(dut.clk_pixel, 2)  # check the pre-reset behavior

    # Reset
    dut.rst.value = 1
    await ClockCycles(dut.clk_pixel, 3)
    await FallingEdge(dut.clk_pixel)
    dut.rst.value = 0
    dut.read_request.value = 0
    dut.should_overwrite_latch.value = 0

    for i, detect_1 in enumerate([1, 1, 1, 1]):
        dut.start_calibration_step.value = 1
        if i == 2:
            dut.should_overwrite_latch.value = 1
        await ClockCycles(dut.clk_pixel, WAIT_CYCLES + 1)
        dut.start_calibration_step.value = 0
        dut.new_frame_in.value = 1
        dut.should_overwrite_latch.value = 0
        await ClockCycles(dut.clk_pixel, 1)
        for start_v, start_h in [(0, 0)]:
            for v in range(start_v, ACTIVE_V + V_PORCH):
                for h in range(start_h, ACTIVE_H + H_PORCH):
                    await FallingEdge(dut.clk_pixel)
                    # active draw
                    dut.detect_1.value = detect_1
                    dut.hcount_in.value = h
                    dut.vcount_in.value = v
                    dut.new_frame_in.value = 0

                    if v == ACTIVE_V and h == ACTIVE_H:
                        dut.new_frame_in.value = 1

    rec_frame_buf = []
    dut._log.info("GOING TO REAd")

    await ClockCycles(dut.clk_pixel, 3)
    for v in range(ACTIVE_V):
        for h in range(ACTIVE_H):
            if v % 4 == 0 and h % 4 == 0:
                dut.read_request.value = 1
                dut.hcount_in.value = h
                dut.vcount_in.value = v
                await ClockCycles(dut.clk_pixel, 3)
                await FallingEdge(dut.clk_pixel)
                assert (
                    dut.read_out.value == 0b0011
                ), f"Read out should be 0b0011, but got {dut.read_out.value}"
            
@cocotb.test()
async def test_d(dut):
    """Test for overlapping detect1 detect 2"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_pixel, 10, units="ns").start())

    await ClockCycles(dut.clk_pixel, 2)  # check the pre-reset behavior

    # Reset
    dut.rst.value = 1
    await ClockCycles(dut.clk_pixel, 3)
    await FallingEdge(dut.clk_pixel)
    dut.rst.value = 0
    dut.read_request.value = 0
    dut.detect_0.value = 0
    dut.should_overwrite_latch.value = 0

    for i, detect_1 in enumerate([0, 0, 1, 0]):
        dut.start_calibration_step.value = 1
        if i == 2:
            dut.detect_0.value = 1
        else:
            dut.detect_0.value = 0
        await ClockCycles(dut.clk_pixel, WAIT_CYCLES + 1)
        dut.start_calibration_step.value = 0
        dut.new_frame_in.value = 1
        dut.should_overwrite_latch.value = 0
        await ClockCycles(dut.clk_pixel, 1)
        for start_v, start_h in [(0, 0)]:
            for v in range(start_v, ACTIVE_V + V_PORCH):
                for h in range(start_h, ACTIVE_H + H_PORCH):
                    await FallingEdge(dut.clk_pixel)
                    # active draw
                    dut.detect_1.value = detect_1
                    dut.hcount_in.value = h
                    dut.vcount_in.value = v
                    dut.new_frame_in.value = 0

                    if v == ACTIVE_V and h == ACTIVE_H:
                        dut.new_frame_in.value = 1

    rec_frame_buf = []
    dut._log.info("GOING TO REAd")

    await ClockCycles(dut.clk_pixel, 3)
    for v in range(ACTIVE_V):
        for h in range(ACTIVE_H):
            if v % 4 == 0 and h % 4 == 0:
                dut.read_request.value = 1
                dut.hcount_in.value = h
                dut.vcount_in.value = v
                await ClockCycles(dut.clk_pixel, 3)
                await FallingEdge(dut.clk_pixel)
                assert (
                    dut.read_out.value == 0b1111
                ), f"Read out should be 0b1111, but got {dut.read_out.value}"


def is_runner():
    """Moving pixel tester"""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "calibration" / "calibration_step_fsm.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "NUM_LEDS": NUM_LEDS,
        "ACTIVE_H_PIXELS": ACTIVE_H,
        "ACTIVE_LINES": ACTIVE_V,
        "WAIT_CYCLES": WAIT_CYCLES,
        "LED_ADDRESS_WIDTH": LED_ADDRESS_WIDTH
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="calibration_step_fsm",
        includes=[proj_path / "hdl"],
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="calibration_step_fsm",
        test_module="test_calibration_step_fsm",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
