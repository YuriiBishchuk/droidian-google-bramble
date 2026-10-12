#!/usr/bin/env bash
# ssh_pmos.sh - Instant SSH shortcut into postmarketOS on Pixel 4a (5G)
exec ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@127.0.0.1 "$@"
