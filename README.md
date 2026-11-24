# Quad Octal PSRAM Controller
An AXI4 memory controller for four Octal SPI (xSPI) DDR PSRAMs in parallel, as used on the
[DI-OWAS chip](https://github.com/DI-OWAS/chip-di-owas).

This fork only keeps the quad Octal SPI controller. The other controllers (SPI, Quad SPI, Hyperbus, single
Octal SPI) are in the upstream repository: https://github.com/timo-braungardt/QSPI_Memory_Controller
("upstream issue #N" in the code refers to its issues).

## OWAS Files
For the OWAS chip we want 4 Octal SPI controller in parallel.
For that implementation use these files:
```
./src/OctalMemoryController_quad.v",
./src/AXI4Subordinate.v",
./src/OSPIController_quad.v",
./src/OctalSPI_quad.v",
```
With `OctalMemoryController_quad` as the top of the module.

Leave the parameters in their default:
```
ADDR_WIDTH = 32,
DATA_WIDTH = 32,
STRB_WIDTH = (DATA_WIDTH / 8),
ID_WIDTH = 8,
```
Set the CHIP_TYPE parameter to 1 for simulation or **2 for the hardware verification and tapeout**.
```
CHIP_TYPE = -1    // 1 for simulation with Infineon model, 2 for hardware with APMemory
```
For the simulation a memory model from Infineon is used, for the hardware verification and tapeout we work with APMemory.  
The default parameter `-1` crashes a check in the synthesis to force the user to set a valid type.

### Code Formatting
For Verilog the [Verible formatter](https://open-vsx.org/extension/bmpenuelas/systemverilog-formatter-vscode) was used with the settings:
```
"systemverilogFormatter.veribleBuild": "none",
"systemverilogFormatter.commandLineArguments": "--indentation_spaces 4"
```

For python the [Black formatter](https://marketplace.visualstudio.com/items?itemName=ms-python.black-formatter) was used with the settings:
```
"black-formatter.args": ["--line-length", "100"]
```

## License
This project is licensed under the [Apache License 2.0](LICENSE).
Some files are derived from third-party work under the MIT License; they keep their original notices and are listed in [NOTICE](NOTICE).
Each source file carries an `SPDX-License-Identifier` header.
