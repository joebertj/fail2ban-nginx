# fail2ban-nginx
Fail2ban Jail Configuration for nginx - Anti Abuse & DDoS Protection

A comprehensive fail2ban configuration for protecting nginx web servers against various attacks including WordPress exploits, DDoS attempts, and other malicious activities.

## Features

- **nginx-abuse-protect**: Detects WordPress attacks, double-slash exploits, directory index scans, .env file access attempts, and other abuse patterns
- **nginx-ddos-protect**: Catches ApacheBench attacks, rate limiting violations, and upstream connection errors
- **recidive-nginx**: Monitors for repeat offenders from the nginx-abuse-protect jail
- All filters use wildcard log path `/var/log/nginx/*.log` for comprehensive monitoring

## How to use?

1. Copy filter files from this repository to your server:
   ```shell
   sudo cp filter.d/*.conf /etc/fail2ban/filter.d/
   ```

2. Create or edit jail configuration file:
   ```shell
   sudo cp jail.local /etc/fail2ban/jail.d/nginx.conf
   # Or manually copy the contents to /etc/fail2ban/jail.local
   ```

3. Restart fail2ban service:
   ```shell
   sudo systemctl restart fail2ban
   ```

4. Verify jails are active:
   ```shell
   sudo fail2ban-client status
   ```

## Testing

### Automated Test Suite

Run the comprehensive test suite:
```shell
./test.sh
```

This will test all filters with sample log entries and verify jail configurations.

### Manual Testing

**Test regex patterns**
```shell
sudo fail2ban-regex /var/log/nginx/access.log /etc/fail2ban/filter.d/nginx-abuse-protect.conf
sudo fail2ban-regex /var/log/nginx/error.log /etc/fail2ban/filter.d/nginx-abuse-protect.conf
```

You will see a list of IPs detected as suspicious from your Nginx logs.

## Cheat sheet

### Check jail status
```shell
sudo fail2ban-client status nginx-abuse-protect
sudo fail2ban-client status nginx-ddos-protect
sudo fail2ban-client status recidive-nginx
```

### Ban/unban IPs
```shell
# Ban an IP
sudo fail2ban-client set nginx-abuse-protect banip 192.168.1.100

# Unban an IP
sudo fail2ban-client set nginx-abuse-protect unbanip 192.168.1.100

# Unban all IPs for a jail
sudo fail2ban-client set nginx-abuse-protect unban --all
```

### Export banned IPs
```shell
sudo fail2ban-client get nginx-abuse-protect banip --with-time > fail2ban-banip-$(date +'%Y-%m-%d').txt
```

### View jail statistics
```shell
sudo fail2ban-client status nginx-abuse-protect
```

## Configuration

### Bantimes
- `nginx-abuse-protect`: 600 seconds (10 minutes)
- `nginx-ddos-protect`: 300 seconds (5 minutes)
- `recidive-nginx`: 3600 seconds (1 hour)

### Log paths
All nginx filters monitor `/var/log/nginx/*.log` for comprehensive coverage of both access and error logs.

## Contributing

Please test changes in a safe environment before deploying to production.

## License

See LICENSE file for details.
