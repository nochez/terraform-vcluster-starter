#!/bin/bash
PORTS=(50023 50024 50025 50026)

for port in "${PORTS[@]}"; do
  if lsof -i:$port > /dev/null; then
    echo "Port $port is in use."
  else
    echo "Port $port is available."
  fi
done

