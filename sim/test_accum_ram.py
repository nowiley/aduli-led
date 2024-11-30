import os
import sys
from pathlib import Path
import typing
from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

WIDTH = 10


async def setup(dut):
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 3)
    await FallingEdge(dut.clk_in)
    dut.rst_in.value = 0

    dut.request_valid_in.value = 0

    # assert dut.ready_out.value == 1, "Ready should be high after reset"
    await ClockCycles(dut.clk_in, 3)
    # assert dut.ready_out.value == 1, "Should still be ready after a few cycles"
    dut._log.info("Setup complete")


@cocotb.test()
async def test_a(dut):
    """Test for driving first pixel a correct color"""
    await setup(dut)
    dut._log.info("Checking summation")

    sum_total = 0
    addr = 1
    # summands = [0, 1, 0, 0, 1, 1, 0, 1]
    summand_str = 0b10110010
    summands = [int(bit) for bit in f"{summand_str:08b}"]

    for summand in summands:
        dut.addr_in.value = addr
        dut.summand_in.value = summand

        dut.request_valid_in.value = 1
        dut._log.info(f"Setting summand to {summand}")
        await ClockCycles(dut.clk_in, 1)

        dut.request_valid_in.value = 0
        await ClockCycles(dut.clk_in, 1)
        await FallingEdge(dut.clk_in)

        assert dut.result_valid_out.value == 1, "Result valid should be high"
        # await ClockCycles(
        #     dut.clk_in, 1
        # )  # wait some extra time because results should stay there
        assert (
            dut.summand_out.value == summand
        ), f"Summand should be {summand} but is {dut.summand_out.value}"
        assert (
            dut.addr_out.value == addr
        ), f"Address should be {addr} but is {dut.addr_out.value}"
        assert (
            dut.read_out.value == sum_total
        ), f"Read should be {sum_total} but is {dut.read_out.value}"
        sum_total <<= 1
        sum_total += summand & 1
        sum_total %= 2**WIDTH
        assert (
            dut.sum_out.value == sum_total
        ), f"Sum should be {sum_total} but is {dut.sum_out.value}"

        await ClockCycles(dut.clk_in, 3)

    assert sum_total == summand_str, f"Sum should be {summand_str} but is {sum_total}"

    await ClockCycles(dut.clk_in, 20)


def is_runner():
    """LED Driver Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "mem" / "accum_ram.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "WIDTH": WIDTH,
        "DEPTH": 32,
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="accum_ram",
        includes=[proj_path / "hdl"],
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="accum_ram",
        test_module="test_accum_ram",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
