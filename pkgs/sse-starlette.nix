{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  # runtime
  starlette,
  uvicorn,
  fastapi,
  anyio,
  typing-extensions,
  # tests
  pytestCheckHook,
  pythonOlder,
}:
buildPythonPackage rec {
  pname = "sse-starlette";
  version = "1.8.0";
  format = "pyproject";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "sysid";
    repo = pname;
    rev = "refs/tags/v${version}";
    hash = "sha256-H7lqdJreSVIwL6wdQuc17pnsOfGUBWDylEcVWzCD6xw=";
  };

  postPatch = ''
    # remove coverage arguments to pytest
    sed -i '/--cov/d' setup.cfg
  '';

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs =
    [
      starlette
      uvicorn
      fastapi
      anyio
    ]
    ++ lib.optionals (pythonOlder "3.10") [
      typing-extensions
    ];

  nativeCheckInputs = [
    # TODO: need asgi_lifespan for test
    # pytestCheckHook
  ];

  pythonImportsCheck = [
    "sse_starlette"
  ];

  meta = with lib; {
    changelog = "https://github.com/sysid/sse-starlette/releases/tag/${version}";
    homepage = "https://github.com/sysid/sse-starlette";
    description = "Server Sent Events for Starlette and FastAPI";
    license = licenses.bsd3;
  };
}
