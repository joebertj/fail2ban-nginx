#!/bin/bash
# fail2ban-nginx Test Suite
# Tests all nginx filters and jail configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Functions
print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_failure() {
    echo -e "${RED}✗ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check prerequisites
print_header "Checking Prerequisites"
if ! check_command fail2ban-client; then
    print_failure "fail2ban-client not found. Please install fail2ban first."
    exit 1
fi
print_success "fail2ban-client found"

if ! check_command fail2ban-regex; then
    print_failure "fail2ban-regex not found. Please install fail2ban first."
    exit 1
fi
print_success "fail2ban-regex found"

# Create temporary test directory and log files
print_header "Setting Up Test Environment"
TEST_DIR="/tmp/fail2ban-nginx-test"
sudo mkdir -p "$TEST_DIR/nginx"
sudo touch "$TEST_DIR/nginx/access.log"
sudo touch "$TEST_DIR/nginx/error.log"
sudo chmod 644 "$TEST_DIR/nginx"/*.log
print_success "Test directory created at $TEST_DIR"

# Deploy filters to fail2ban
print_header "Deploying Filters"
if sudo cp filter.d/*.conf /etc/fail2ban/filter.d/ 2>/dev/null; then
    print_success "Filters copied to /etc/fail2ban/filter.d/"
else
    print_failure "Failed to copy filters"
    exit 1
fi

# Create test jail configuration
print_header "Creating Test Jail Configuration"
cat > /tmp/test-jails-$$.conf << 'EOF'
#
# HTTP servers
#

[nginx-abuse-protect]
enabled   = true
port      = http,https
logpath   = /tmp/fail2ban-nginx-test/nginx/*.log
banaction = iptables-multiport
maxretry  = 1
findtime  = 3600
bantime   = 600

[recidive-nginx]
enabled   = true
logpath   = /tmp/fail2ban-nginx-test/fail2ban.log
banaction = iptables-multiport
maxretry  = 2
findtime  = 86400
bantime   = 3600

[nginx-ddos-protect]
enabled   = true
port      = http,https
logpath   = /tmp/fail2ban-nginx-test/nginx/*.log
banaction = iptables-multiport
maxretry  = 1
findtime  = 3600
bantime   = 300
EOF

sudo cp /tmp/test-jails-$$.conf "$TEST_DIR/test-jails.conf"
rm /tmp/test-jails-$$.conf

sudo touch "$TEST_DIR/fail2ban.log"
sudo chmod 644 "$TEST_DIR/fail2ban.log"

if sudo cp "$TEST_DIR/test-jails.conf" /etc/fail2ban/jail.d/test-nginx.conf 2>/dev/null; then
    print_success "Test jail configuration created"
else
    print_failure "Failed to create test jail configuration"
    exit 1
fi

# Create test log lines
print_header "Creating Test Log Lines"

# Access log tests
sudo tee "$TEST_DIR/nginx/access.log" > /dev/null << 'EOF'
192.168.1.100 - - [03/Nov/2025:13:40:00 +0000] "GET /test.php HTTP/1.1" 200 1234 "-" "Mozilla/5.0"
192.168.1.101 - - [03/Nov/2025:13:40:01 +0000] "GET //a1b2c3d4?cb=e5f6&sid=789&ts=123456&v=1 HTTP/1.1" 200 5678 "-" "ApacheBench/2.3"
192.168.1.102 - - [03/Nov/2025:13:40:02 +0000] "GET /wp-admin.php HTTP/1.1" 403 0 "-" "badbot"
192.168.1.103 - - [03/Nov/2025:13:40:03 +0000] "GET /.env HTTP/1.1" 403 0 "-" "scanner"
EOF

# Error log tests
sudo tee "$TEST_DIR/nginx/error.log" > /dev/null << 'EOF'
2025/11/03 13:40:00 [error] 123#456: *789 directory index of "/var/www/" is forbidden, client: 192.168.1.200, server: example.com, request: "GET / HTTP/1.1", host: "example.com"
2025/11/03 13:40:01 [alert] 123#456: *1 1024 worker_connections are not enough while connecting to upstream, client: 192.168.1.201,
2025/11/03 13:40:02 [error] 123#456: *2 connect() to unix:/var/run/php-fpm.sock failed (111: Connection refused) while connecting to upstream, client: 192.168.1.202, server: example.com
2025/11/03 13:40:03 [error] 123#456: *3 upstream prematurely closed connection while reading response header from upstream, client: 192.168.1.203, server: example.com
EOF

print_success "Test log lines created"

# Test filter regexes
print_header "Testing Filter Regexes"

# Test nginx-abuse-protect with access.log
echo "Testing nginx-abuse-protect (access.log)..."
if sudo fail2ban-regex "$TEST_DIR/nginx/access.log" /etc/fail2ban/filter.d/nginx-abuse-protect.conf 2>&1 | grep -q "Failregex: [1-9]"; then
    print_success "nginx-abuse-protect (access.log) - Patterns detected"
else
    print_failure "nginx-abuse-protect (access.log) - No patterns detected"
fi

# Test nginx-abuse-protect with error.log
echo "Testing nginx-abuse-protect (error.log)..."
if sudo fail2ban-regex "$TEST_DIR/nginx/error.log" /etc/fail2ban/filter.d/nginx-abuse-protect.conf 2>&1 | grep -q "Failregex: [1-9]"; then
    print_success "nginx-abuse-protect (error.log) - Patterns detected"
else
    print_failure "nginx-abuse-protect (error.log) - No patterns detected"
fi

# Test nginx-ddos-protect with access.log
echo "Testing nginx-ddos-protect (access.log)..."
if sudo fail2ban-regex "$TEST_DIR/nginx/access.log" /etc/fail2ban/filter.d/nginx-ddos-protect.conf 2>&1 | grep -q "Failregex: [1-9]"; then
    print_success "nginx-ddos-protect (access.log) - Patterns detected"
else
    print_failure "nginx-ddos-protect (access.log) - No patterns detected"
fi

# Test nginx-ddos-protect with error.log
echo "Testing nginx-ddos-protect (error.log)..."
if sudo fail2ban-regex "$TEST_DIR/nginx/error.log" /etc/fail2ban/filter.d/nginx-ddos-protect.conf 2>&1 | grep -q "Failregex: [1-9]"; then
    print_success "nginx-ddos-protect (error.log) - Patterns detected"
else
    print_failure "nginx-ddos-protect (error.log) - No patterns detected"
fi

# Test fail2ban service with test jails
print_header "Testing fail2ban Service"

# Restart fail2ban to load test configuration
if sudo systemctl restart fail2ban 2>/dev/null; then
    sleep 2
    print_success "fail2ban service restarted"
else
    print_failure "Failed to restart fail2ban service"
    exit 1
fi

# Check if jails are active
echo "Checking jail status..."
if sudo fail2ban-client status 2>/dev/null | grep -q "nginx-abuse-protect"; then
    print_success "nginx-abuse-protect jail is active"
else
    print_failure "nginx-abuse-protect jail is not active"
fi

if sudo fail2ban-client status 2>/dev/null | grep -q "nginx-ddos-protect"; then
    print_success "nginx-ddos-protect jail is active"
else
    print_failure "nginx-ddos-protect jail is not active"
fi

if sudo fail2ban-client status 2>/dev/null | grep -q "recidive-nginx"; then
    print_success "recidive-nginx jail is active"
else
    print_failure "recidive-nginx jail is not active"
fi

# Test configuration values
print_header "Verifying Configuration Values"

# Check nginx-abuse-protect bantime
BT=$(sudo fail2ban-client get nginx-abuse-protect bantime 2>/dev/null || echo "0")
if [ "$BT" = "600" ]; then
    print_success "nginx-abuse-protect bantime is 600"
else
    print_failure "nginx-abuse-protect bantime is $BT (expected 600)"
fi

# Check nginx-ddos-protect bantime
BT=$(sudo fail2ban-client get nginx-ddos-protect bantime 2>/dev/null || echo "0")
if [ "$BT" = "300" ]; then
    print_success "nginx-ddos-protect bantime is 300"
else
    print_failure "nginx-ddos-protect bantime is $BT (expected 300)"
fi

# Cleanup
print_header "Cleaning Up"

# Remove test configuration
sudo rm -f /etc/fail2ban/jail.d/test-nginx.conf
print_success "Test jail configuration removed"

# Remove test directory
sudo rm -rf "$TEST_DIR"
print_success "Test directory removed"

# Restart fail2ban to return to normal state
if sudo systemctl restart fail2ban 2>/dev/null; then
    print_success "fail2ban service restarted (normal state)"
else
    print_failure "Failed to restart fail2ban service"
fi

# Print summary
print_header "Test Summary"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed${NC}"
    exit 1
fi

