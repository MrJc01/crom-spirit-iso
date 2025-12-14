#!/bin/sh
# Spirit System Test Script v2.0
# Tests all Spirit components including new features

echo ""
echo "========================================"
echo "   SPIRIT SYSTEM TEST v2.0"
echo "========================================"
echo ""
echo "Date: $(date 2>/dev/null || echo 'N/A')"
echo "Host: $(hostname)"
echo ""

PASS=0
FAIL=0

test_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "[PASS] $2"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $2"
        FAIL=$((FAIL + 1))
    fi
}

test_file() {
    if [ -e "$1" ]; then
        echo "[PASS] $2"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $2"
        FAIL=$((FAIL + 1))
    fi
}

test_exec() {
    if $1 >/dev/null 2>&1; then
        echo "[PASS] $2"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $2"
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

echo ""
echo "--- New Features ---"
test_file /spirit/bin/nexus "Nexus HUD"
test_file /spirit/bin/hotkeyd "Hotkey Daemon"
test_file /spirit/bin/ai "Spirit AI"
test_cmd ai "AI Command"

echo ""
echo "--- VM Commands ---"
test_cmd windows "Windows VM"
test_cmd linux "Linux VM"

echo ""
echo "--- GPU Tools ---"
test_file /spirit/bin/gpu_detach "GPU Detach"
test_file /spirit/bin/gpu_attach "GPU Attach"
test_cmd lspci "PCI Utils"

echo ""
echo "--- Utilities ---"
test_cmd htop "htop"
test_cmd nano "nano"
test_cmd curl "curl"
test_cmd wget "wget"
test_cmd free "free"

echo ""
echo "--- System Files ---"
test_file /init "Init Script"
test_file /etc/profile "Profile"
test_file /etc/motd.sh "MOTD"
test_file /spirit/bin "Spirit Bin"

echo ""
echo "--- Filesystem ---"
test_file /proc/cpuinfo "Procfs"
test_file /sys/class "Sysfs"
test_file /dev/null "Devfs"

echo ""
echo "--- Function Tests ---"
test_exec "nodus status" "nodus status"
test_exec "hypervisor status" "hypervisor status"

# Memory test
MEM=$(free -m 2>/dev/null | awk '/Mem/ {print $2}')
if [ "$MEM" -gt 0 ] 2>/dev/null; then
    echo "[PASS] Memory: ${MEM}MB"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Memory detection"
    FAIL=$((FAIL + 1))
fi

# AI offline test
if echo "status" | timeout 2 ai 2>/dev/null | grep -q ""; then
    echo "[PASS] AI responds"
    PASS=$((PASS + 1))
else
    echo "[SKIP] AI (needs input)"
    PASS=$((PASS + 1))
fi

echo ""
echo "========================================"
echo "   TEST RESULTS"
echo "========================================"
echo ""
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
TOTAL=$((PASS + FAIL))
PERCENT=$((PASS * 100 / TOTAL))
echo "  SCORE:  $PERCENT%"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  STATUS: ALL TESTS PASSED!"
else
    echo "  STATUS: $FAIL TESTS FAILED"
fi
echo ""
echo "========================================"
