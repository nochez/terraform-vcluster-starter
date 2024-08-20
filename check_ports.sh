#!/bin/bash
PORTS=(50023 50024 50025 50026)
WAIT_TIME=5  # Wait between checks (seconds)
TIMEOUT=300  # Time before giving up (seconds)

check_ports() {
  for port in "${PORTS[@]}"; do
    if lsof -i:$port > /dev/null; then
      echo "Port $port is in use."
      return 1  # Port not free, return failure
    else
      echo "Port $port is available."
    fi
  done
  return 0  # If all ports are available, return success
}

wait_for_ports() {
  local elapsed=0
  while ! check_ports; do
    if [ $elapsed -ge $TIMEOUT ]; then
      echo "Timeout reached! Ports are still in use :("
      return 1
    fi
    echo "Waiting for ports..."
    sleep $WAIT_TIME
    elapsed=$((elapsed + WAIT_TIME))
  done
  echo "All ports are available¨!"
  return 0
}

wait_for_ports

