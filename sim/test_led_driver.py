import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge


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
    # assert dut.ready_out.value == 1, "Ready should be high after reset"
    await ClockCycles(dut.clk_in, 3)
    # assert dut.ready_out.value == 1, "Should still be ready after a few cycles"
    assert dut.strand_out.value == 0, "Strand should be low if not sending data"
    dut.color_valid.value = 1  # start sending data
    await ClockCycles(dut.clk_in, 1)
    dut.color_valid.value = 0
    dut._log.info("Checking correct protocol")
    bitstring = (
        (int(dut.green_in.value) & 0xFF) << 16
        | (int(dut.red_in.value) & 0xFF) << 8
        | (int(dut.blue_in.value) & 0xFF)
    )
    # // Assuming 100MHz clock, 10ns period ->
    # // 0 bit = 0.4us high, 0.85us low -> 40 cycles high, 85 cycles low
    # // 1 bit = 0.8us high, 0.45us low -> 80 cycles high, 45 cycles low
    # // reset = 50us low
    await ClockCycles(dut.clk_in, 1)
    assert (
        dut.strand_out.value == 1
    ), "Strand should be high immediately after valid data in"

    for re_writes in range(3):
        for led_idx in range(3):
            for i in range(24):
                if i == 12:
                    dut.color_valid.value = 1
                elif i == 13:
                    dut.color_valid.value = 0
                cur_bit = (bitstring >> (24 - 1 - i)) & 0x01
                dut._log.info(f"Checking bit {i} = {cur_bit}")
                assert dut.strand_out.value == 1, "Strand should be high at the start"
                if cur_bit == 0:
                    dut._log.info("Checking T0H 40 cycles high")
                    for j in range(40):
                        assert (
                            dut.strand_out.value == 1
                        ), "Data should be high in T0H period"
                        await ClockCycles(dut.clk_in, 1)
                    dut._log.info("Checking T0L 85 cycles low")
                    for j in range(85):
                        assert (
                            dut.strand_out.value == 0
                        ), "Data should be low in T0L period"
                        await ClockCycles(dut.clk_in, 1)
                else:
                    dut._log.info("Checking T1H 80 cycles high")
                    for j in range(80):
                        assert (
                            dut.strand_out.value == 1
                        ), "Data should be high in T1H period"
                        await ClockCycles(dut.clk_in, 1)
                    dut._log.info("Checking T1L 45 cycles low")
                    for j in range(45):
                        assert (
                            dut.strand_out.value == 0
                        ), "Data should be low in T1L period"
                        await ClockCycles(dut.clk_in, 1)
        dut._log.info("Checking reset")
        for j in range(5000):
            assert dut.strand_out.value == 0, "Data should be low in reset period"
            await ClockCycles(dut.clk_in, 1)
        # need to wait one more as it switches through IDLE
        await ClockCycles(dut.clk_in, 1)
        assert dut.strand_out.value == 1, "Strand should be high after reset"


def is_runner():
    """LED Driver Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "led_driver.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "NUM_LEDS": 3,
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="led_driver",
        includes=[proj_path / "hdl"],
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
