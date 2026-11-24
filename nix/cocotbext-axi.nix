{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  cocotb,
  cocotb-bus,
}:

buildPythonPackage rec {
  pname = "cocotbext-axi";
  version = "0.1.28";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "alexforencich";
    repo = "cocotbext-axi";
    tag = "v${version}";
    hash = "sha256-z8csYidDWTvNIYQgM/bPi4VsQwOSc9gnqGQEXMH/jU8=";
  };

  build-system = [ setuptools ];
  dependencies = [
    cocotb
    cocotb-bus
  ];

  pythonImportsCheck = [ "cocotbext.axi" ];

  meta = {
    description = "AXI, AXI lite, and AXI stream modules for cocotb";
    homepage = "https://github.com/alexforencich/cocotbext-axi";
    license = lib.licenses.mit;
  };
}
