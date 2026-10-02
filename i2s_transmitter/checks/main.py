import sys
import check50
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

import helpers

CHECKS_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.environ.get("PWD", os.getcwd())

# Konfiguration
MODULE_NAME = "i2s_transmitter"

DESIGN_FILE = f"{MODULE_NAME}.vhd"
TESTBENCH_FILE = f"{MODULE_NAME}_tb.vhd"
TESTBENCH_NAME = f"{MODULE_NAME}_tb"
VCD_FILE = f"{MODULE_NAME}.vcd"

@check50.check()
def exists():
    f"""{DESIGN_FILE} exists"""
    check50.exists(DESIGN_FILE)

@check50.check(exists)
def testbench_exists():
    f"""{TESTBENCH_FILE} exists"""
    tb_path = os.path.join(CHECKS_DIR, TESTBENCH_FILE)
    check50.exists(tb_path)

@check50.check(testbench_exists)
def ghdl_installed():
    """GHDL is installed"""
    try:
        helpers.ensure_ghdl()
        helpers.ensure_vaporview()
    except Exception as e:
        raise check50.Failure(str(e))

@check50.check(ghdl_installed)
def testbench_runs():
    f"""{DESIGN_FILE} compiles without errors and simulation testbench passes logic tests"""
    try:
        tb_path = os.path.join(CHECKS_DIR, TESTBENCH_FILE)
        vcd_path = os.path.join(ROOT_DIR, VCD_FILE)
        
        helpers.compile_vhdl(DESIGN_FILE)
        helpers.compile_vhdl(tb_path)
        
        output = helpers.run_testbench(TESTBENCH_NAME, DESIGN_FILE, tb_path, vcd_path)
        
        if 'assertion error' in output.lower():
            raise check50.Failure("Simulation failed with assertion errors")
        
        helpers.log_vcd_created(vcd_path)
    except check50.Failure:
        raise
    except Exception as e:
        raise check50.Failure(str(e))
