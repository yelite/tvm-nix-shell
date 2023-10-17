{
  lib,
  async-timeout,
  buildPythonPackage,
  fetchFromGitHub,
  flask,
  httpcore,
  httpx,
  hypercorn,
  pytest-asyncio,
  pytest-cov,
  pytestCheckHook,
  python-socks,
  pythonOlder,
  setuptools,
  setuptools-scm,
  starlette,
  sse-starlette,
  tiny-proxy,
  trio,
  trustme,
  yarl,
}:
buildPythonPackage rec {
  pname = "httpx-sse";
  version = "0.3.1";
  format = "pyproject";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "florimondmanca";
    repo = pname;
    rev = "refs/tags/${version}";
    hash = "sha256-Ej5qiOTG+LWtuR21dPPE5HQWiACqG0ZF3p+/0kfIapU=";
  };

  postPatch = ''
    # remove coverage arguments to pytest
    sed -i '/--cov/d' setup.cfg
  '';

  nativeBuildInputs = [
    setuptools
    setuptools-scm
  ];

  propagatedBuildInputs = [
    httpx
  ];

  # __darwinAllowLocalNetworking = true;

  nativeCheckInputs = [
    pytest-cov
    pytest-asyncio
    pytestCheckHook
    starlette
    sse-starlette
  ];

  pythonImportsCheck = [
    "httpx_sse"
  ];

  disabledTests = [
  ];

  meta = with lib; {
    description = "Consume Server-Sent Event (SSE) messages with HTTPX";
    homepage = "https://github.com/florimondmanca/httpx-sse";
    changelog = "https://github.com/florimondmanca/httpx-sse/releases/tag/v${version}";
    license = licenses.mit;
  };
}
