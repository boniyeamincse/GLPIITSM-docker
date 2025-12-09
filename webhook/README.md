
# GLPI Webhook Service Documentation

This document provides comprehensive documentation for the Python webhook service that integrates Wazuh security alerts with GLPI ticketing system.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [API Endpoints](#api-endpoints)
6. [Alert Processing](#alert-processing)
7. [Error Handling](#error-handling)
8. [Security](#security)
9. [Performance](#performance)
10. [Troubleshooting](#troubleshooting)
11. [Customization](#customization)
12. [Examples](#examples)

## 🏗️ Overview

The GLPI Webhook Service is a Python-based microservice that:

- Receives security alerts from Wazuh in JSON format
- Transforms alerts into GLPI ticket format
- Creates tickets in GLPI via REST API
- Provides health monitoring endpoint
- Handles errors and retries automatically

## 🔧 Architecture

### Component Diagram

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                                                                               │
│   ┌─────────────┐    ┌─────────────────┐    ┌─────────────────────────────┐   │
│   │             │    │                 │    │                             │   │
│   │  Wazuh      │    │  Webhook        │    │  GLPI                       │   │
│   │  Server     │────▶│  Service        │────▶│  REST API                  │   │
│   │             │    │                 │    │                             │   │
│   └─────────────┘    └─────────────────┘    └─────────────────────────────┘   │
│          │                  │                         │                   │
│          │                  │                         │                   │
│   ┌──────▼──────┐    ┌──────▼──────┐    ┌─────────────▼─────────────────┐   │
│   │             │    │             │    │                             │   │
│   │  Security   │    │  Processing │    │  Ticket                   │   │
│   │  Events     │    │  & Validation│    │  Creation                │   │
│   │             │    │             │    │                             │   │
│   └─────────────┘    └─────────────┘    └─────────────────────────────┘   │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

- **Language:** Python 3.9+
- **Framework:** Flask (micro web framework)
- **HTTP Client:** Requests library
- **Logging:** Python logging module
- **Container:** Docker with custom image

## 🛠️ Installation

### Prerequisites

- Python 3.9+
- Docker (for containerized deployment)
- GLPI instance with REST API enabled
- Wazuh server configured to send alerts

### Local Installation

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the service
python webhook.py
```

### Docker Installation

The service is automatically built and deployed via the main `docker-compose.yml` file.

## ⚙️ Configuration

### Environment Variables

The webhook service uses the following environment variables:

```env
# GLPI Connection
GLPI_URL=http://glpi:80
GLPI_API_TOKEN=your_glpi_api_token

# Wazuh Connection (for future direct integration)
WAZUH_API_URL=http://wazuh-server:55000
WAZUH_API_USER=wazuh_user
WAZUH_API_PASSWORD=wazuh_password
```

### Configuration File

The service can also be configured via a `.env` file in the webhook directory.

## 🌐 API Endpoints

### POST /webhook

**Description:** Receive Wazuh alerts and create GLPI tickets

**Request:**
- Method: POST
- Content-Type: application/json
- Body: Wazuh alert JSON payload

**Example Request:**
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

**Response:**
- Success (201): Ticket created successfully
- Error (400): Invalid request data
- Error (500): Internal server error

**Example Success Response:**
```json
{
  "status": "success",
  "message": "Ticket created successfully",
  "ticket_id": 12345
}
```

### GET /health

**Description:** Health check endpoint

**Request:**
- Method: GET

**Response:**
```json
{
  "status": "healthy"
}
```

## 📊 Alert Processing

### Alert Transformation

The webhook service transforms Wazuh alerts into GLPI ticket format:

1. **Extract key information:**
   - Agent name and ID
   - Rule description and level
   - Alert location
   - Full alert data

2. **Map to GLPI ticket fields:**
   - **Name:** "Security Alert: [Rule Description]"
   - **Content:** Formatted alert details with Markdown
   - **Status:** New (1)
   - **Urgency:** Based on alert level (1-5 scale)
   - **Impact:** Based on alert level (1-5 scale)
   - **Priority:** Calculated from urgency and impact
   - **Type:** Incident (1)
   - **Category:** Default ITIL category

### Priority Mapping

| Wazuh Level | GLPI Urgency | GLPI Impact | GLPI Priority |
|-------------|--------------|-------------|---------------|
| 1-3         | 1 (Very Low) | 1 (Very Low)| 1 (Very Low)  |
| 4-6         | 2 (Low)      | 2 (Low)     | 2 (Low)       |
| 7-9         | 3 (Medium)   | 3 (Medium)  | 3 (Medium)    |
| 10-12       | 4 (High)     | 4 (High)    | 4 (High)      |
| 13-15       | 5 (Very High)| 5 (Very High)| 5 (Very High) |

## ❌ Error Handling

### Retry Logic

The service implements automatic retry for failed API calls:

- **Max Retries:** 3 attempts
- **Retry Delay:** 5 seconds between attempts
- **Timeout:** 30 seconds per request

### Error Types

1. **Validation Errors (400):**
   - Invalid JSON payload
   - Missing required fields
   - Malformed data

2. **Authentication Errors (401):**
   - Invalid GLPI API token
   - Expired token
   - Permission issues

3. **API Errors (500):**
   - GLPI API unavailable
   - Database connection issues
   - Internal server errors

4. **Network Errors:**
   - Connection timeouts
   - DNS resolution failures
   - SSL certificate issues

### Error Logging

All errors are logged with detailed information:
- Timestamp
- Error type
- Request details
- Stack trace (for debugging)

## 🔒 Security

### Authentication

- **GLPI API:** Uses user token and app token authentication
- **Environment Variables:** Sensitive data stored in environment variables
- **No Hardcoded Credentials:** All credentials loaded from environment

### Data Protection

- **HTTPS Support:** SSL verification enabled by default
- **Input Validation:** All incoming data validated
- **Error Handling:** Sensitive information not exposed in error messages

### Best Practices

1. **Use HTTPS:** Configure reverse proxy with SSL
2. **Restrict Access:** Limit access to webhook endpoint
3. **Rotate Tokens:** Regularly update API tokens
4. **Monitor Logs:** Review webhook logs for suspicious activity
5. **Rate Limiting:** Consider adding rate limiting for production

## ⚡ Performance

### Optimization Techniques

1. **Connection Pooling:** Reuse HTTP connections
2. **Asynchronous Processing:** Non-blocking I/O operations
3. **Caching:** Cache GLPI API responses where appropriate
4. **Batching:** Process multiple alerts in batches (future enhancement)

### Performance Metrics

- **Response Time:** < 500ms for typical alerts
- **Throughput:** 10-20 alerts/second (depending on GLPI performance)
- **Memory Usage:** ~100MB (containerized)

## 🚨 Troubleshooting

### Common Issues

**1. Webhook not receiving alerts:**
- Check Wazuh configuration
- Verify network connectivity
- Test with curl command

**2. Tickets not created in GLPI:**
- Verify GLPI API token
- Check GLPI API availability
- Review webhook logs

**3. Authentication failures:**
- Regenerate API tokens
- Check token permissions
- Verify token format

### Debugging Commands

```bash
# Test webhook endpoint
curl -X POST -H "Content-Type: application/json" \
     -d '{"test":"data"}' http://localhost:5000/webhook

# View webhook logs
docker-compose logs -f webhook

# Check service health
curl http://localhost:5000/health

# Test GLPI API directly
curl -X GET -H "Authorization: user_token YOUR_TOKEN" \
     -H "App-Token: YOUR_TOKEN" http://localhost:8080/apirest.php/Ticket
```

## 🛠️ Customization

### Modifying Ticket Creation

Edit `webhook.py` to customize ticket creation:

```python
def create_glpi_ticket(alert_data):
    """Customize ticket creation logic here"""
    ticket_data = {
        "input": {
            "name": f"Custom: {alert_data.get('rule', {}).get('description', 'Unknown')}",
            "content": "Custom ticket content",
            # Customize other fields as needed
        }
    }
    # Add custom processing logic
    return create_ticket_in_glpi(ticket_data)
```

### Adding Alert Processing Rules

```python
def process_alert(alert_data):
    """Add custom alert processing rules"""
