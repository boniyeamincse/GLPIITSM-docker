# GLPI ITSM Architecture Documentation

This document provides a comprehensive overview of the GLPI Docker architecture with Wazuh integration.

## Table of Contents

1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow](#data-flow)
4. [Network Architecture](#network-architecture)
5. [Security Architecture](#security-architecture)
6. [Scalability Considerations](#scalability-considerations)
7. [Integration Points](#integration-points)
8. [Deployment Architecture](#deployment-architecture)

## System Overview

The GLPI ITSM system is a containerized solution that provides IT Service Management capabilities with security alert integration from Wazuh. The system is designed for easy deployment, scalability, and maintainability.

### High-Level Architecture

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────────┐   │
│   │             │    │             │    │                                 │   │
│   │  Wazuh      │    │  Users      │    │  External Systems              │   │
│   │  Server     │    │  (Browser)  │    │  (Email, LDAP, etc.)           │   │
│   │             │    │             │    │                                 │   │
│   └──────┬──────┘    └──────┬──────┘    └─────────────┬─────────────────┘   │
│          │                  │                         │                   │
│          │                  │                         │                   │
│   ┌──────▼──────┐    ┌──────▼──────┐    ┌─────────────▼─────────────────┐   │
│   │             │    │             │    │                                 │   │
│   │  Webhook    │    │  GLPI       │    │  Postfix                      │   │
│   │  Service    │    │  Web        │    │  Email Relay                  │   │
│   │  (Port 5000)│    │  Interface  │    │  (Port 25)                    │   │
│   │             │    │  (Port 8080)│    │                                 │   │
│   └──────┬──────┘    └──────┬──────┘    └─────────────┬─────────────────┘   │
│          │                  │                         │                   │
│          │                  │                         │                   │
│          └────────┬─────────┘                         │                   │
│                   │                                  │                   │
│                   ▼                                  │                   │
│            ┌─────────────┐                          │                   │
│            │             │                          │                   │
│            │  MariaDB    │                          │                   │
│            │  Database   │                          │                   │
│            │             │                          │                   │
│            └─────────────┘                          │                   │
│                                                      │                   │
└──────────────────────────────────────────────────────┘───────────────────┘
```

## Component Architecture

### 1. GLPI Web Interface

**Container:** `glpi`
**Image:** `glpi/glpi:latest`
**Port:** 8080
**Technology:** PHP, Apache/Nginx

**Responsibilities:**
- User authentication and authorization
- Ticket management interface
- Asset inventory management
- Reporting and dashboards
- REST API endpoint

**Key Features:**
- Multi-entity support
- Role-based access control
- Customizable workflows
- Plugin architecture
- Internationalization support

### 2. MariaDB Database

**Container:** `mariadb`
**Image:** `mariadb:10.6`
**Port:** 3306 (internal only)
**Technology:** MariaDB 10.6

**Responsibilities:**
- Data persistence for GLPI
- Transaction management
- Data integrity and constraints
- Backup and recovery

**Database Schema:**
- `glpi_db` - Main database
- Tables: users, tickets, assets, configurations, logs, etc.
- Optimized indexes for performance

### 3. Webhook Service

**Container:** `glpi-webhook`
**Image:** Custom Python image
**Port:** 5000
**Technology:** Python 3.9, Flask

**Responsibilities:**
- Receive Wazuh security alerts
- Transform alerts to GLPI ticket format
- Create tickets via GLPI REST API
- Provide health monitoring endpoint

**Key Features:**
- JSON payload processing
- Error handling and retries
- Logging and monitoring
- Configurable alert mapping

### 4. Postfix Email Relay

**Container:** `postfix`
**Image:** `catatnight/postfix`
**Port:** 25
**Technology:** Postfix MTA

**Responsibilities:**
- Email notification delivery
- SMTP relay service
- Queue management
- Email routing

**Configuration:**
- Basic email relay
- Configurable domain and credentials
- Queue management

## Data Flow

### Wazuh Alert Processing Flow

```
┌─────────────┐       ┌─────────────────┐       ┌─────────────┐       ┌─────────────┐
│             │       │                 │       │             │       │             │
│  Wazuh      │──────▶│  Webhook        │──────▶│  GLPI       │──────▶│  MariaDB    │
│  Server     │  HTTP │  Service        │  REST │  Application│  SQL  │  Database   │
│             │  POST │                 │  API  │             │       │             │
└─────────────┘       └─────────────────┘       └─────────────┘       └─────────────┘
     │                         │                     │                     │
     │                         │                     │                     │
     ▼                         ▼                     ▼                     ▼
┌─────────────┐       ┌─────────────────┐       ┌─────────────┐       ┌─────────────┐
│             │       │                 │       │             │       │             │
│  Security   │       │  Processing     │       │  Ticket     │       │  Data       │
│  Events     │       │  & Validation   │       │  Creation   │       │  Storage    │
│             │       │                 │       │             │       │             │
└─────────────┘       └─────────────────┘       └─────────────┘       └─────────────┘
```

### User Interaction Flow

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│             │       │             │       │             │       │             │
│  User       │──────▶│  GLPI       │──────▶│  MariaDB    │       │  Postfix    │
│  Browser    │  HTTP │  Web        │  SQL  │  Database   │       │  Email      │
│             │  GET/ │  Interface  │       │             │       │  Relay      │
└─────────────┘       └─────────────┘       └─────────────┘       └─────────────┘
     │                         │                     │                     │
     │                         │                     │                     │
     ▼                         ▼                     ▼                     ▼
┌─────────────┐       ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│             │       │             │       │             │       │             │
│  Web        │       │  Data       │       │  Data       │       │  Email      │
│  Interface  │       │  Processing │       │  Storage    │       │  Delivery   │
│             │       │             │       │             │       │             │
└─────────────┘       └─────────────┘       └─────────────┘       └─────────────┘
```

## Network Architecture

### Container Network

**Network Name:** `glpi_network`
**Type:** Bridge network
**Subnet:** Auto-assigned by Docker

**Network Topology:**

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│   │             │    │             │    │             │    │             │   │
│   │  GLPI       │    │  MariaDB    │    │  Webhook    │    │  Postfix    │   │
│   │  Container  │    │  Container  │    │  Container  │    │  Container  │   │
│   │             │    │             │    │             │    │             │   │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘   │
│          │                  │                  │                  │          │
│          │                  │                  │                  │          │
│   ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐   │
│   │             │    │             │    │             │    │             │   │
│   │  Port 8080  │    │  Port 3306   │    │  Port 5000  │    │  Port 25    │   │
│   │  (HTTP)     │    │  (MySQL)     │    │  (HTTP)     │    │  (SMTP)     │   │
│   │             │    │             │    │             │    │             │   │
│   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

### Port Mapping

| Service | Container Port | Host Port | Protocol | Access |
|---------|----------------|-----------|----------|--------|
| GLPI    | 80             | 8080      | HTTP     | Public |
| Webhook | 5000           | 5000      | HTTP     | Public |
| Postfix | 25             | 25        | SMTP     | Public |
| MariaDB | 3306           | -         | MySQL    | Internal |

### Security Considerations

1. **Internal Communication:** All containers communicate via internal Docker network
2. **External Access:** Only necessary ports are exposed to host
3. **Database Security:** MariaDB is not exposed externally
4. **API Security:** GLPI REST API requires authentication tokens

## Security Architecture

### Authentication and Authorization

**GLPI Authentication:**
- Local user database
- LDAP/Active Directory integration (optional)
- Multi-factor authentication (plugin available)
- Session management with timeout

**API Authentication:**
- User tokens for REST API access
- App tokens for application authentication
- Token expiration and rotation

**Webhook Security:**
- Environment-based API token storage
- HTTPS support (when configured)
- Input validation and sanitization
- Rate limiting (can be added)

### Data Protection

**Encryption:**
- SSL/TLS for external communications (recommended)
- Database encryption at rest (optional)
- Secure password storage (hashed)

**Access Control:**
- Role-based access control (RBAC)
- Entity-based data segregation
- Fine-grained permissions
- Audit logging

### Network Security

**Firewall Rules:**
- Restrict access to management ports
- IP whitelisting for sensitive endpoints
- Rate limiting for API endpoints

**Container Security:**
- Regular image updates
- Minimal base images
- Non-root container execution
- Read-only filesystems where possible

## Scalability Considerations

### Vertical Scaling

**Current Limits:**
- Single container instances
- Shared resources
- Single database instance

**Scaling Options:**
1. **Resource Allocation:**
   ```yaml
   # Example resource limits in docker-compose.yml
   deploy:
     resources:
       limits:
         cpus: '2.0'
         memory: 4G
   ```

2. **Database Optimization:**
   - Query caching
   - Index optimization
   - Connection pooling

### Horizontal Scaling

**Multi-Container Architecture:**

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────────┐   │
│   │             │    │             │    │                                 │   │
│   │  GLPI       │    │  GLPI       │    │  Load Balancer                │   │
│   │  Instance 1 │    │  Instance 2 │    │  (Nginx/HAProxy)              │   │
│   │             │    │             │    │                                 │   │
│   └──────┬──────┘    └──────┬──────┘    └─────────────┬─────────────────┘   │
│          │                  │                         │                   │
│          │                  │                         │                   │
│          └────────┬─────────┘                         │                   │
│                   │                                  │                   │
│                   ▼                                  │                   │
│            ┌─────────────┐                          │                   │
│            │             │                          │                   │
│            │  MariaDB    │                          │                   │
│            │  (Replica   │                          │                   │
│            │   Set)      │                          │                   │
│            │             │                          │                   │
│            └─────────────┘                          │                   │
│                                                      │                   │
└──────────────────────────────────────────────────────┘───────────────────┘
```

**Scaling Components:**

1. **GLPI Web Interface:**
   - Multiple instances behind load balancer
   - Shared session storage (Redis)
   - Shared file storage (NFS, S3)

2. **Database:**
   - Master-slave replication
   - Read replicas for reporting
   - Regular backups

3. **Webhook Service:**
   - Multiple instances
   - Load balanced endpoints
   - Shared logging

### Performance Optimization

**Caching Strategies:**
- OPcache for PHP performance
- Query caching in MariaDB
- Object caching with Redis
- Browser caching for static assets

**Database Optimization:**
- Regular index optimization
- Query analysis and tuning
- Partitioning large tables
- Connection pooling

## Integration Points

### Wazuh Integration

**Integration Method:** REST Webhook
**Protocol:** HTTP/HTTPS
**Data Format:** JSON
**Authentication:** None (internal network)

**Data Flow:**
1. Wazuh detects security event
2. Wazuh sends JSON payload to webhook endpoint
3. Webhook validates and transforms data
4. Webhook creates GLPI ticket via REST API
5. GLPI stores ticket in database
6. GLPI triggers notifications (email, etc.)

**Example Wazuh Alert:**
```json
{
  "agent": {
    "id": "001",
    "name": "web-server-01"
  },
  "rule": {
    "level": 12,
    "description": "Multiple authentication failures"
  },
  "location": "/var/log/auth.log",
  "data": {
    "src_ip": "192.168.1.100",
    "attempts": 5
  }
}
```

### Email Integration

**Integration Method:** SMTP Relay
**Protocol:** SMTP
**Port:** 25
**Authentication:** Configurable

**Data Flow:**
1. GLPI generates email notification
2. GLPI sends email to Postfix container
3. Postfix relays email to configured SMTP server
4. Email delivered to recipient

**Configuration Options:**
- Direct SMTP delivery
- Smart host relay
- Authentication methods
- TLS encryption

### REST API Integration

**API Endpoints:**
- `/apirest.php/Ticket` - Ticket management
- `/apirest.php/User` - User management
- `/apirest.php/Asset` - Asset management
- `/apirest.php/Entity` - Entity management

**Authentication:**
- User tokens
- App tokens
- Session-based (for web interface)

**Usage Examples:**
```bash
# Create ticket
curl -X POST -H "Authorization: user_token TOKEN" \
     -H "App-Token: TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"input": {"name": "Test", "content": "Test content"}}' \
     http://glpi:80/apirest.php/Ticket

# Get tickets
curl -X GET -H "Authorization: user_token TOKEN" \
     -H "App-Token: TOKEN" \
     http://glpi:80/apirest.php/Ticket
```

## Deployment Architecture

### Single Server Deployment

**Recommended for:** Small to medium installations
**Server Requirements:**
- CPU: 4+ cores
- RAM: 8+ GB
- Disk: 100+ GB (SSD recommended)
- OS: Linux (Ubuntu/CentOS) or Windows with Docker

**Deployment Steps:**
1. Install Docker and Docker Compose
2. Clone repository
3. Configure `.env` file
4. Run `docker-compose up -d`
5. Complete GLPI web setup

### Multi-Server Deployment

**Recommended for:** Large installations, high availability
**Server Requirements:**

**Web Servers (2+):**
- CPU: 4 cores each
- RAM: 8 GB each
- Disk: 50 GB each

**Database Server:**
- CPU: 8+ cores
- RAM: 16+ GB
- Disk: 200+ GB (SSD, RAID recommended)

**Load Balancer:**
- CPU: 4 cores
- RAM: 4 GB
- Disk: 20 GB

**Deployment Architecture:**

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────────────────────────┐   │
│   │             │    │             │    │                                 │   │
│   │  User       │    │  User       │    │  Load Balancer                │   │
│   │  Browser    │    │  Browser    │    │  (HAProxy/Nginx)             │   │
│   │             │    │             │    │                                 │   │
│   └──────┬──────┘    └──────┬──────┘    └─────────────┬─────────────────┘   │
│          │                  │                         │                   │
│          │                  │                         │                   │
│          └────────┬─────────┘                         │                   │
│                   │                                  │                   │
│                   ▼                                  │                   │
│            ┌─────────────┐                          │                   │
│            │             │                          │                   │
│            │  Web        │                          │                   │
│            │  Server 1   │                          │                   │
│            │             │                          │                   │
│            └──────┬──────┘                          │                   │
│                   │                                  │                   │
│            ┌──────▼──────┐                          │                   │
│            │             │                          │                   │
│            │  Web        │                          │                   │
│            │  Server 2   │                          │                   │
│            │             │                          │                   │
│            └──────┬──────┘                          │                   │
│                   │                                  │                   │
│                   ▼                                  │                   │
│            ┌─────────────┐                          │                   │
│            │             │                          │                   │
│            │  Database   │                          │                   │
│            │  Cluster    │                          │                   │
│            │             │                          │                   │
│            └─────────────┘                          │                   │
│                                                      │                   │
└──────────────────────────────────────────────────────┘───────────────────┘
```

### Cloud Deployment

**Cloud Provider Options:**
- AWS (ECS, RDS)
- Azure (Container Instances, Database)
- Google Cloud (GKE, Cloud SQL)
- DigitalOcean (Droplets, Managed Databases)

**Cloud-Specific Considerations:**
- Managed database services
- Auto-scaling groups
- Load balancers
- Managed Kubernetes (for large deployments)
- Cloud storage for backups

## Architecture Decision Records

### 1. Containerization Decision

**Decision:** Use Docker containers for all components
**Rationale:**
- Consistent deployment across environments
- Easy dependency management
- Isolation between components
- Simplified updates and rollbacks
- Portability across platforms

### 2. Database Choice

**Decision:** MariaDB 10.6
**Rationale:**
- Official GLPI recommendation
- MySQL compatibility
- Performance improvements
- Active community support
- Long-term support version

### 3. Webhook Implementation

**Decision:** Custom Python webhook service
**Rationale:**
- Flexibility in alert processing
- Easy integration with Wazuh
- Customizable ticket creation logic
- Better error handling
- Future extensibility

### 4. Network Architecture

**Decision:** Internal Docker network with selected port exposure
**Rationale:**
- Security through isolation
- Controlled external access
- Simplified container communication
- Standardized networking

## Future Architecture Evolution

### 1. Microservices Migration

**Potential Changes:**
- Separate GLPI modules into microservices
- API gateway for unified access
- Service mesh for inter-service communication
- Independent scaling of components

### 2. Kubernetes Deployment

**Benefits:**
- Auto-scaling capabilities
- Self-healing containers
- Rolling updates
- Advanced networking
- Resource optimization

### 3. Enhanced Security

**Future Improvements:**
- Mutual TLS for service communication
- Service mesh with Istio
- Advanced rate limiting
- Comprehensive audit logging
- Automated security scanning

### 4. Multi-Region Deployment

**Considerations:**
- Database replication strategies
- Data synchronization
- Latency optimization
- Disaster recovery planning
- Global load balancing

This architecture documentation provides a comprehensive overview of the GLPI ITSM system design, deployment options, and future evolution paths. The modular container-based approach ensures flexibility, scalability, and maintainability for enterprise IT service management needs.