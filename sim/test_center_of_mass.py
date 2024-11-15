import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

@cocotb.test()
async def test_a(dut):
    """cocotb test for com square"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,3)
    dut.rst_in.value = 0
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,5)
    for y in range(50):
        for x in range(70):
            dut._log.info(f"y = {y}, x = {x}")
            await FallingEdge(dut.clk_in)
            dut.x_in.value = x
            dut.y_in.value = y
            if (x in range(25, 40)) and (y in range(25, 40)):
                dut.valid_in.value = 1
            else:
                dut.valid_in.value = 0
            await RisingEdge(dut.clk_in)
    dut.tabulate_in.value = 1
    await RisingEdge(dut.valid_out)
    calc_x = dut.x_out.value
    calc_y = dut.y_out.value
    calc_valid = dut.valid_out.value
    dut._log.info(f"calc_x = {int(calc_x)}, calc_y = {int(calc_y)}, calc_valid = {int(calc_valid)}")
    assert calc_x == (25+40)//2 and calc_y == (25+40)//2 and calc_valid == 1
    await ClockCycles(dut.clk_in,4)

@cocotb.test()
async def test_b(dut):
    '''Test for single line down the screen'''
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,3)
    dut.rst_in.value = 0
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,5)
    for y in range(15):
        for x in range(32):
            dut._log.info(f"y = {y}, x = {x}")
            await FallingEdge(dut.clk_in)
            dut.x_in.value = x
            dut.y_in.value = y
            if (x == 26) and (y in range(0, 15)):
                dut.valid_in.value = 1
            else:
                dut.valid_in.value = 0
            await RisingEdge(dut.clk_in)
    dut.tabulate_in.value = 1
    await RisingEdge(dut.valid_out)
    calc_x = dut.x_out.value
    calc_y = dut.y_out.value
    calc_valid = dut.valid_out.value
    dut._log.info(f"calc_x = {int(calc_x)}, calc_y = {int(calc_y)}, calc_valid = {int(calc_valid)}")
    assert calc_x == 26 and calc_y == 14//2 and calc_valid == 1
    await ClockCycles(dut.clk_in,1)

@cocotb.test()
async def test_c(dut):
    ''' test consecutive frames'''
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,3)
    dut.rst_in.value = 0
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,5)
    for y in range(72):
        for x in range(128):
            await FallingEdge(dut.clk_in)
            dut.x_in.value = x
            dut.y_in.value = y
            if (x in range(25, 52)) and (y in range(25, 52)):
                dut.valid_in.value = 1
            else:
                dut.valid_in.value = 0
            await RisingEdge(dut.clk_in)
    dut.tabulate_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.tabulate_in.value = 0
    await RisingEdge(dut.valid_out)
    calc_x = dut.x_out.value
    calc_y = dut.y_out.value
    calc_valid = dut.valid_out.value
    dut._log.info(f"calc_x = {int(calc_x)}, calc_y = {int(calc_y)}, calc_valid = {int(calc_valid)}")
    assert calc_x == (25+51)//2 and calc_y == (25+51)//2 and calc_valid == 1
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,1)
    for y in range(72):
        for x in range(128):
            await FallingEdge(dut.clk_in)
            dut._log.info(f"y = {y}, x = {x}")
            dut.x_in.value = x
            dut.y_in.value = y
            if (x in range(51, 71)) and (y in range(51, 71)):
                dut.valid_in.value = 1
            else:
                dut.valid_in.value = 0
            await RisingEdge(dut.clk_in)
    dut.tabulate_in.value = 1
    await RisingEdge(dut.valid_out)
    calc_x = dut.x_out.value
    calc_y = dut.y_out.value
    calc_valid = dut.valid_out.value
    dut._log.info(f"calc_x = {int(calc_x)}, calc_y = {int(calc_y)}, calc_valid = {int(calc_valid)}")
    assert calc_x == (51+70)//2 and calc_y == (51+70)//2 and calc_valid == 1
    await ClockCycles(dut.clk_in,1)

@cocotb.test()
async def test_d(dut):
    """test for single pixel"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,3)
    dut.rst_in.value = 0
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,5)
    for y in range(2):
        for x in range(4):
            await FallingEdge(dut.clk_in)
            dut.x_in.value = x
            dut.y_in.value = y
            if (x == 2) and (y == 1):
                dut.valid_in.value = 1
            else:
                dut.valid_in.value = 0
            await RisingEdge(dut.clk_in)
    dut.tabulate_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.tabulate_in.value = 0
    await RisingEdge(dut.valid_out)
    calc_x = dut.x_out.value
    calc_y = dut.y_out.value
    calc_valid = dut.valid_out.value
    dut._log.info(f"calc_x = {calc_x}, calc_y = {calc_y}, calc_valid = {calc_valid}")
    assert calc_x == 2 and calc_y == 1 and calc_valid == 1
    await ClockCycles(dut.clk_in,1)

@cocotb.test()
async def test_e(dut):
    """test for entire screen"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,3)
    dut.rst_in.value = 0
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,5)
    for y in range(48):
        for x in range(23):
            await FallingEdge(dut.clk_in)
            dut.x_in.value = x
            dut.y_in.value = y
            dut.valid_in.value = 1
            await RisingEdge(dut.clk_in)
    dut.tabulate_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.tabulate_in.value = 0
    await RisingEdge(dut.valid_out)
    calc_x = dut.x_out.value
    calc_y = dut.y_out.value
    calc_valid = dut.valid_out.value
    dut._log.info(f"calc_x = {int(calc_x)}, calc_y = {int(calc_y)}, calc_valid = {int(calc_valid)}")
    assert calc_x == 23//2 and calc_y == 47//2 and calc_valid == 1
    await ClockCycles(dut.clk_in,1)

@cocotb.test()
async def test_f(dut):
    """test for top left of screen not entire screen given box unfilled"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,3)
    dut.rst_in.value = 0
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,5)
    for y in range(65):
        for x in range(72):
            await FallingEdge(dut.clk_in)
            dut.x_in.value = x
            dut.y_in.value = y
            if (x in (0, 12)) and (y in (0, 35)):
                dut.valid_in.value = 1
            else:
                dut.valid_in.value = 0
            await RisingEdge(dut.clk_in)
    dut.tabulate_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.tabulate_in.value = 0
    await RisingEdge(dut.valid_out)
    calc_x = dut.x_out.value
    calc_y = dut.y_out.value
    calc_valid = dut.valid_out.value
    dut._log.info(f"calc_x = {int(calc_x)}, calc_y = {int(calc_y)}, calc_valid = {calc_valid}")
    assert calc_x == 12//2 and calc_y == 35//2 and calc_valid == 1
    await ClockCycles(dut.clk_in,1)

@cocotb.test()
async def test_g(dut):
    """Test if no valid pixels are present"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,3)
    dut.rst_in.value = 0
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,5)
    for y in range(42):
        for x in range(11):
            await FallingEdge(dut.clk_in)
            dut.x_in.value = x
            dut.y_in.value = y
            dut.valid_in.value = 0
            await RisingEdge(dut.clk_in)
    dut.tabulate_in.value = 1
    await ClockCycles(dut.clk_in,1)
    dut.tabulate_in.value = 0
    await ClockCycles(dut.clk_in,500)
    calc_x = dut.x_out.value
    calc_y = dut.y_out.value
    calc_valid = dut.valid_out.value
    dut._log.info(f"calc_x = {int(calc_x)}, calc_y = {int(calc_y)}, calc_valid = {calc_valid}")
    assert  calc_valid == 0
    await ClockCycles(dut.clk_in,1)

def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "center_of_mass.sv"]
    sources += [proj_path / "hdl" / "divider.sv"]
    sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="center_of_mass",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="center_of_mass",
        test_module="test_center_of_mass",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()
