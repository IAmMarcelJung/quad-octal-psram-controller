# SPDX-License-Identifier: Apache-2.0
{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  setuptools-scm,
  cocotb,
}:

buildPythonPackage {
  pname = "cocotbext-spi";
  # untagged commit after v0.5.0 (cocotb 2.x support)
  version = "0.5.0.post0+g67857d0";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "schang412";
    repo = "cocotbext-spi";
    rev = "67857d0c7b9ea854467b57269becb9b221d9986e";
    hash = "sha256-jdTTTzrTKxq1H2WpaYra4ytrGnjVBzR/p6tqtp6ArAw=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];
  dependencies = [ cocotb ];

  pythonImportsCheck = [ "cocotbext.spi" ];

  meta = {
    description = "SPI modules for cocotb";
    homepage = "https://github.com/schang412/cocotbext-spi";
    license = lib.licenses.mit;
  };
}
