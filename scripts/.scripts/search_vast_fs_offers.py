#!/usr/bin/env python3
"""
Search Vast.ai offers with grouped, high-quality filters for single high-end GPU machines.

Filters grouped inline by category for easy reading/editing:

- Reliability: High uptime and verified hosts.
- GPU: 1 GPU, modern CUDA/compute_cap, >=20GB VRAM.
- System: Strong CPU/RAM/disk.
- Price: Cheap hourly rate.
- Network: Fast/cheap internet + static IP.
- Availability: Rentable, long duration.

Run: python search_vast_fs_offers.py
"""

import os
import subprocess
import sys

VASTAI_BIN = os.getenv("VASTAI_BIN", "/Users/cododel/.local/bin/vastai")


# All filters in single list, grouped by category comments
filters = [
    # Reliability & Availability
    ["reliability", ">", "0.98"],
    ["verified", "=", "true"],
    ["rentable", "=", "true"],
    # GPU Specs
    ["num_gpus", "=", "1"],
    ["cuda_max_good", ">=", "12.7"],
    ["compute_cap", ">=", "890"],
    ["gpu_ram", ">", "20"],
    # System Resources
    ["cpu_cores_effective", ">", "32"],
    ["cpu_ram", ">", "40"],
    ["disk_space", ">", "700"],
    # Price (total $/hr for machine)
    ["dph", "<", "2"],
    # Network
    ["inet_down", ">", "300"],
    ["inet_down_cost", "<", "20"],
    ["inet_up", ">", "300"],
    ["inet_up_cost", "<", "20"],
    ["static_ip", "=", "true"],
    # Duration
    ["duration", ">", "90"],  # Max rental >90 days
]


def search_vast_fs_offers():
    """Run Vast.ai search with all grouped filters."""
    # Build filter string: field op value (e.g. 'reliability>0.98 num_gpus=1')
    filter_str = " ".join([f"{f[0]}{f[1]}{f[2]}" for f in filters])

    cmd = [VASTAI_BIN, "search", "offers", filter_str]

    print(f"Running: {' '.join(cmd)}")
    print("-" * 80)

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode == 0:
        print(result.stdout)
    else:
        print("Error occurred:", file=sys.stderr)
        print(result.stderr, file=sys.stderr)

    return result.returncode


if __name__ == "__main__":
    sys.exit(search_vast_fs_offers())
