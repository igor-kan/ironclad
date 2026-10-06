#!/usr/bin/env bash
# ==============================================================================
# Hardware Virtualization & KVM Pre-Flight Verifier
# ==============================================================================
set -euo pipefail

echo "========================================================================"
echo "  Ironclad Agent Sandbox: Hardware Virtualization Pre-Flight Check"
echo "========================================================================"

# 1. Check for /dev/kvm existence
if [ -e /dev/kvm ]; then
    echo "  [OK] /dev/kvm device node exists."
else
    echo "  [FAIL] /dev/kvm does not exist! Ensure KVM kernel module is loaded."
    exit 1
fi

# 2. Check read/write access to /dev/kvm
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "  [OK] /dev/kvm is accessible with read/write permissions."
else
    echo "  [WARN] User $(whoami) lacks RW access to /dev/kvm. Add user to 'kvm' group."
fi

# 3. CPU Virtualization Flag Check
if grep -E -q '(vmx|svm)' /proc/cpuinfo; then
    CPU_TYPE=$(grep -m1 -E '(vmx|svm)' /proc/cpuinfo | grep -o -E '(vmx|svm)')
    if [ "$CPU_TYPE" == "vmx" ]; then
        echo "  [OK] Intel VT-x hardware virtualization detected (vmx flag)."
    else
        echo "  [OK] AMD-V hardware virtualization detected (svm flag)."
    fi
else
    echo "  [FAIL] No hardware virtualization extensions detected in /proc/cpuinfo."
    exit 1
fi

echo "========================================================================"
echo "  Pre-flight verification passed! Host is capable of running MicroVMs."
echo "========================================================================"
