# Memory Model
The vendor memory models are not distributed with this repository, because they require a login to download.

`test/cocotb/test_quad_octal_memory_controller_model.py` (`CHIP_TYPE = 1`) needs the Infineon Octal SPI model
(S70KL1283), unpacked into this folder; the test is skipped without it:

[Infineon Octal SPI Model](https://www.infineon.com/gated/infineon-verilog-model-for-octal-spi-interface-simulationmodels-en_d3e0fd9b-b4c1-4165-9fcc-9e936dba99d0)

The APMemory tests (`CHIP_TYPE = 2`) use the behavioral model in `test/sim_models/aps12808l_model.v` and need no
download.
