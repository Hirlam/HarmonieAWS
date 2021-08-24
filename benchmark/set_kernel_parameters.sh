#!/bin/bash

echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches
