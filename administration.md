# GLPI ITSM Administration Guide

This guide provides comprehensive administration instructions for the GLPI Docker setup with Wazuh integration.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [User Management](#user-management)
3. [Backup and Recovery](#backup-and-recovery)
4. [Monitoring and Maintenance](#monitoring-and-maintenance)
5. [Troubleshooting](#troubleshooting)
6. [Security Management](#security-management)
7. [Performance Optimization](#performance-optimization)
8. [Integration Management](#integration-management)

## Daily Operations

### Starting and Stopping Services

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart specific service
docker-compose restart glpi
docker-compose restart webhook
docker-compose restart mariadb
docker-compose restart postfix
```

### Checking Service Status

```bash
# View running containers
docker-compose ps

# Check service logs
docker-compose logs -f
docker-compose logs -f glpi
docker-compose logs -f webhook

# Check resource usage
docker stats
```

### Accessing Services

- **GLPI Web Interface:** `http://your-server:8080`
- **Webhook Endpoint:** `http://your-server:5000/webhook`
- **SMTP Server:** `your-server:25`
- **Database:** `mariadb` container (internal only)

## User Management

### GLPI User Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| Super Admin | Full system access | All permissions |
| Admin | System administration | Configuration, user management |
| Technician | Ticket management | View, create, update tickets |
| Observer | Read-only access | View tickets and reports |
| Self-service | Basic user | Create and view own tickets |

### Creating Users

1. Login to GLPI as Super Admin
2. Navigate to **Setup > Users**
3. Click **Add** button
4. Fill in user details:
   - Username, Email, Name
   - Password (or let user set on first login)
   - Profile (select appropriate role)
   - Entity (if using multi-entity setup)

### Bulk User Import

```bash
# Use GLPI CLI for bulk operations
docker exec -it glpi php bin/console glpi:user:import --help
```

## Backup and Recovery

### Backup Procedures

#### Database Backup

```bash
# Manual backup
docker exec mariadb mysqldump -u root -p glpi_db > glpi_db_backup_$(date +%Y%m%d).sql

# Automated backup script
#!/bin/bash
BACKUP_DIR="/backups/glpi"
mkdir -p $BACKUP_DIR
docker exec mariadb mysqldump -u root -p${MYSQL_ROOT_PASSWORD} glpi_db > ${BACKUP_DIR}/glpi_db_$(date +%Y%m%d_%H%M%S).sql
find $BACKUP_DIR -type f -mtime +30 -delete
```

#### File System Backup

```bash
# Backup GLPI files and configurations
docker exec glpi tar czvf /backup/glpi_files_$(date +%Y%m%d).tar.gz /var/www/html/glpi
docker cp glpi:/backup/glpi_files_$(date +%Y%m%d).tar.gz ./backups/
```

### Restore Procedures

```bash
# Restore database
cat glpi_db_backup.sql | docker exec -i mariadb mysql -u root -p glpi_db

# Restore files
docker cp ./backups/glpi_files.tar.gz glpi:/backup/
docker exec glpi tar xzvf /backup/glpi_files.tar.gz -C /
docker exec glpi chown -R www-data:www-data /var/www/html/glpi
```

### Disaster Recovery Plan

1. **Daily:** Automated database backups
2. **Weekly:** Full system backup (database + files)
3. **Monthly:** Test restore procedure
4. **Quarterly:** Review backup strategy and retention policy

## Monitoring and Maintenance

### System Monitoring

```bash
# Check disk space
docker system df

# Clean up unused containers and images
docker system prune -a

# Monitor container resource usage
docker stats --no-stream
```

### Log Management

```bash
# View GLPI logs
docker-compose logs -f glpi

# View webhook logs
docker-compose logs -f webhook
tail -f webhook/webhook.log

# Rotate logs (add to cron)
logrotate -f /etc/logrotate.conf
```

### Maintenance Tasks

| Task | Frequency | Command |
|------|-----------|---------|
| Database optimization | Weekly | `docker exec mariadb mysqloptimize -u root -p --all-databases` |
| Clean old sessions | Daily | `docker exec glpi php bin/console glpi:session:clean` |
| Update statistics | Daily | `docker exec glpi php bin/console glpi:stats:update` |
| Check for updates | Weekly | `docker-compose pull` |

## Troubleshooting

### Common Issues and Solutions

#### GLPI Not Accessible

1. **Check container status:** `docker-compose ps`
2. **Check logs:** `docker-compose logs glpi`
3. **Verify port binding:** `netstat -tuln | grep 8080`
4. **Check database connection:** `docker exec glpi php bin/console glpi:database:check`

#### Webhook Not Working

1. **Test webhook endpoint:**
   ```bash
   curl -X POST -H "Content-Type: application/json" \
   -d '{"test":"data"}' http://localhost:5000/webhook
   ```
2. **Check webhook logs:** `tail -f webhook/webhook.log`
3. **Verify GLPI API token:** Check `.env` file and GLPI API settings
4. **Test GLPI API directly:**
   ```bash
   curl -X GET -H "Authorization: user_token YOUR_TOKEN" \
   -H "App-Token: YOUR_TOKEN" http://localhost:8080/apirest.php/Ticket
   ```

#### Email Not Sending

1. **Check Postfix logs:** `docker-compose logs postfix`
2. **Test SMTP connection:**
   ```bash
   telnet localhost 25
   EHLO test
   QUIT
   ```
3. **Verify SMTP credentials:** Check `.env` file
4. **Check spam folder:** Test emails may be filtered

### Performance Issues

1. **Check resource usage:** `docker stats`
2. **Optimize database:**
   ```bash
   docker exec mariadb mysqloptimize -u root -p --all-databases
   ```
3. **Increase PHP memory:** Edit `config/php.ini`
4. **Enable caching:** Configure OPcache in `config/php.ini`

## Security Management

### Security Best Practices

1. **Regular Updates:**
   ```bash
   docker-compose pull
   docker-compose up -d --build
   ```

2. **Password Rotation:**
   - Rotate database passwords monthly
   - Rotate API tokens quarterly
   - Use strong, randomly generated passwords

3. **Access Control:**
   - Restrict GLPI admin access
   - Use firewall rules to limit access to ports
   - Implement IP whitelisting if possible

4. **SSL Configuration:**
   - Use reverse proxy with SSL (Nginx, Apache)
   - Configure Let's Encrypt certificates
   - Enforce HTTPS for all access

### Security Monitoring

1. **Check for vulnerabilities:**
   ```bash
   docker scan glpi
   docker scan mariadb
   ```

2. **Monitor failed login attempts:**
   ```bash
   docker exec mariadb mysql -u root -p -e "SELECT * FROM glpi.logs WHERE itemtype='User' AND action='failed_login'"
   ```

3. **Audit user activities:**
   ```bash
   docker exec mariadb mysql -u root -p -e "SELECT * FROM glpi.logs ORDER BY date DESC LIMIT 100"
   ```

## Performance Optimization

### Database Optimization

```bash
# Optimize tables
docker exec mariadb mysqloptimize -u root -p --all-databases

# Analyze tables
docker exec mariadb mysqlanalyze -u root -p --all-databases

# Configure MySQL performance
# Add to custom MySQL config:
[mysqld]
innodb_buffer_pool_size = 1G
query_cache_size = 64M
query_cache_type = 1
```

### PHP Configuration

```ini
# config/php.ini optimizations
memory_limit = 512M
max_execution_time = 300
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
```

### GLPI Configuration

1. **Enable caching:** `Setup > General > Performance`
2. **Configure cron jobs:**
   ```bash
   # Add to crontab
   * * * * * docker exec glpi php bin/console glpi:cron
   ```
3. **Optimize asset inventory:** Regular cleanup of old assets

## Integration Management

### Wazuh Integration

1. **Configure Wazuh manager:**
   ```xml
   <integration>
     <name>glpi-webhook</name>
     <hook_url>http://glpi-server:5000/webhook</hook_url>
     <level>7</level>
     <alert_format>json</alert_format>
   </integration>
   ```

2. **Test integration:**
   ```bash
   curl -X POST -H "Content-Type: application/json" \
   -d '@test_alert.json' http://localhost:5000/webhook
   ```

3. **Monitor integration:**
   ```bash
   # Check webhook success rate
   grep "Ticket created successfully" webhook/webhook.log | wc -l

   # Check failed attempts
   grep "Failed to create ticket" webhook/webhook.log | wc -l
   ```

### Email Integration

1. **Configure Postfix:**
   ```bash
   # Edit Postfix configuration
   docker exec -it postfix bash
   # Configure relay host if needed
   ```

2. **Test email sending:**
   ```bash
   echo "Test email" | mail -s "GLPI Test" user@example.com
   ```

3. **Configure GLPI email notifications:**
   - Navigate to `Setup > Notifications`
   - Configure email templates and triggers

## Maintenance Checklist

### Daily
- [ ] Check service status
- [ ] Review logs for errors
- [ ] Monitor resource usage
- [ ] Verify backup completion

### Weekly
- [ ] Database optimization
- [ ] Clean old sessions
- [ ] Update statistics
- [ ] Check for security updates

### Monthly
- [ ] Test backup restore
- [ ] Review user accounts
- [ ] Rotate passwords
- [ ] Performance review

### Quarterly
- [ ] Major version updates
- [ ] Security audit
- [ ] Capacity planning
- [ ] Documentation review

## Advanced Administration

### Customizing GLPI

1. **Create custom fields:**
   - Navigate to `Setup > Entities > [Entity] > Custom fields`
   - Add fields for specific business requirements

2. **Create custom reports:**
   - Use GLPI's report builder
   - Export data for external analysis

3. **Automate workflows:**
   - Configure business rules
   - Set up automatic ticket assignment

### Scaling the System

1. **Vertical scaling:**
   - Increase container resources
   - Upgrade server hardware

2. **Horizontal scaling:**
   - Separate database server
   - Load balancing for web interface
   - Multiple webhook instances

3. **Database optimization:**
   - Query optimization
   - Index management
   - Partitioning large tables

### Monitoring and Alerting

1. **Set up monitoring:**
   ```bash
   # Use Prometheus + Grafana
   # Or integrate with existing monitoring systems
   ```

2. **Configure alerts:**
   - Disk space alerts
   - Service availability alerts
   - Performance threshold alerts

3. **Log aggregation:**
   - Centralize logs with ELK stack
   - Set up log rotation and retention policies

This administration guide provides comprehensive instructions for managing your GLPI ITSM system. Regular maintenance and monitoring will ensure optimal performance and reliability.