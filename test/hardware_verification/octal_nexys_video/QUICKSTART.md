# Quickstart: quad APMemory controller (sim + Nexys Video)

Details: [README_apmemory.md](README_apmemory.md)

## Simulation

Needs Icarus Verilog, cocotb 2.0, cocotbext-axi and pytest, or `nix develop` in the repository root.

```sh
cd test/cocotb
pytest -v test_quad_octal_apmemory_model.py
```

## Board (Nexys Video + FMC PSRAM board, SW0 off)

```sh
cd test/hardware_verification/octal_nexys_video
VIVADO=vivado   # Vivado 2025.1

$VIVADO -mode batch -source build_quad.tcl                         # bitstream in build/
# edge aligned (posedge) bus clock variant: BUS_CLOCK_NEGEDGE=0 $VIVADO ... (output in build_posedge/)

python3 hw_scenario.py tcl > build/hw_scenario.tcl
$VIVADO -mode batch -source run_hw_scenario.tcl -tclargs program   # board -> build/hw_result.txt
(cd ../../cocotb && HW_SCENARIO=/tmp/sim.txt \
    pytest test_quad_octal_apmemory_model.py::test_quad_octal_apmemory_model_hw_scenario)
python3 hw_scenario.py compare build/hw_result.txt /tmp/sim.txt   # expect "0 mismatching words"

$VIVADO -mode batch -source stress_test.tcl -tclargs - 10 build/stress.txt   # expect 0 errors
```

The Digilent adapter can show up as two JTAG targets; the scripts try every target, so a
"No devices detected" error for one of them is expected.
