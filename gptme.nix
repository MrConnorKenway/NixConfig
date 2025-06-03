{
  lib,
  python3Packages,
  fetchPypi,
}:

python3Packages.buildPythonApplication rec {
  pname = "gptme";
  version = "0.27.0";
  pyproject = true;

  build-system = with python3Packages; [
    setuptools
    poetry-core
  ];

  propagatedBuildInputs = with python3Packages; [
    click
    python-dotenv
    rich
    tabulate
    pick
    tiktoken
    tomlkit
    typing-extensions
    platformdirs
    lxml
    json-repair
    openai
    anthropic
    ipython
    bashlex
    pillow
  ];

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-bS68ICddAopvAToF6bapPXvAL8Oey27DAD1XPAaQ8Rw=";
  };

  meta = with lib; {
    description = "Personal AI assistant in your terminal";
    homepage = "https://github.com/gptme/gptme";
    license = licenses.mit;
  };
}
