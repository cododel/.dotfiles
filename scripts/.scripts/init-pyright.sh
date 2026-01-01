#!/bin/bash

python3 -m venv .venv
poetry env use .venv/bin/python
echo '{
  "venvPath": ".",
  "venv": ".venv"
}' > pyrightconfig.json

echo "Successfully initialized Pyright"

