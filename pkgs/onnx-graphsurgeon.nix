{ lib
, fetchFromGitHub
, python
, buildPythonPackage
, onnx
, numpy
}:

buildPythonPackage {
  pname = "onnx-graphsurgeon";
  version = "0.3.25";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "TensorRT";
    rev = "8.5.2";
    hash = "sha256-IvfMj1/m8NXEOHQdGTFMCy4ra1DuxFCEIDWvwymh7PU=";
    sparseCheckout = [
      "tools/onnx-graphsurgeon"
    ];
  };

  preBuild = "cd tools/onnx-graphsurgeon";

  propagatedBuildInputs = [
    onnx
    numpy
  ];

  meta = with lib; {
    description = "Python bindings for TensorRT, a high-performance deep learning interface";
    homepage = "https://github.com/nvidia/tensorrt/tools/onnx-graphsurgeon";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
  };
}
