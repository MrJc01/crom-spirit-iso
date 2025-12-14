#!/bin/sh
# Spirit System Test Script
# Run inside the Spirit ISO to verify all commands work
# Copy output and share to verify functionality

echo ""
echo "========================================"
echo "   SPIRIT SYSTEM TEST v1.0"
echo "========================================"
echo ""
echo "Date: $(date 2>/dev/null || echo 'N/A')"
echo "Hostname: $(hostname)"
echo ""

PASS=0
FAIL=0

test_cmd() {
    CMD=$1
    DESC=$2
    if command -v "$CMD" >/dev/null 2>&1; then
        echo "[PASS] $DESC ($CMD)"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $DESC ($CMD)"
        FAIL=$((FAIL + 1))
    fi
}

test_file() {
    FILE=$1
    DESC=$2
    if [ -e "$FILE" ]; then
        echo "[PASS] $DESC ($FILE)"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $DESC ($FILE)"
        FAIL=$((FAIL + 1))
    fi
}

echo "--- Core Commands ---"
test_cmd sh "Shell"
test_cmd poweroff "Poweroff"
test_cmd reboot "Reboot"

echo ""
echo "--- Spirit Tools ---"
test_cmd spirit "Spirit Menu"
test_cmd shelp "Help Command"
test_cmd nodus "Nodus Storage"
test_cmd hypervisor "Hypervisor"
test_cmd windows "Windows VM"
test_cmd linux "Linux VM"
test_cmd ai "AI Assistant"

echo ""
echo "--- GPU Tools ---"
test_file /spirit/bin/gpu_detach "GPU Detach"
test_file /spirit/bin/gpu_attach "GPU Attach"
test_cmd lspci "PCI Utils"

echo ""
echo "--- Utilities ---"
test_cmd htop "Process Monitor"
test_cmd nano "Text Editor"
test_cmd curl "HTTP Client"
test_cmd wget "Download Tool"
test_cmd ls "List Files"
test_cmd mount "Mount"
test_cmd free "Memory Info"

echo ""
echo "--- System Files ---"
test_file /init "Init Script"
test_file /etc/profile "Profile"
test_file /etc/motd.sh "MOTD Script"
test_file /spirit/bin "Spirit Bin Dir"

echo ""
echo "--- Filesystem ---"
test_file /proc/cpuinfo "Procfs"
test_file /sys/class "Sysfs"
test_file /dev/null "Devfs"

echo ""
echo "--- Quick Function Tests ---"

# Test nodus runs
if nodus status >/dev/null 2>&1; then
    echo "[PASS] nodus status works"
    PASS=$((PASS + 1))
else
    echo "[FAIL] nodus status"
    FAIL=$((FAIL + 1))
fi

# Test hypervisor runs
if hypervisor status >/dev/null 2>&1; then
    echo "[PASS] hypervisor status works"
    PASS=$((PASS + 1))
else
    echo "[FAIL] hypervisor status"
    FAIL=$((FAIL + 1))
fi

# Test memory info
MEM=$(free -m | awk '/Mem/ {print $2}')
if [ "$MEM" -gt 0 ] 2>/dev/null; then
    echo "[PASS] Memory detected: ${MEM}MB"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Memory detection"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "========================================"
echo "   TEST RESULTS"
echo "========================================"
echo ""
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    echo ""
    echo "  STATUS: ALL TESTS PASSED!"
else
    echo ""
    echo "  STATUS: $FAIL TESTS FAILED"
fi
echo ""
echo "========================================"
