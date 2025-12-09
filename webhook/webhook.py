#!/usr/bin/env python3
"""
GLPI Webhook Service for Wazuh Integration
This script receives alerts from Wazuh and creates tickets in GLPI
"""

import os
import json
import time
import requests
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

# Configure logging
import logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('webhook.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration from environment variables
GLPI_URL = os.getenv('GLPI_URL', 'http://glpi:80')
GLPI_API_TOKEN = os.getenv('GLPI_API_TOKEN', '')
WAZUH_API_URL = os.getenv('WAZUH_API_URL', 'http://wazuh-server:55000')
WAZUH_API_USER = os.getenv('WAZUH_API_USER', '')
WAZUH_API_PASSWORD = os.getenv('WAZUH_API_PASSWORD', '')

def create_glpi_ticket(alert_data):
    """Create a ticket in GLPI using REST API"""
    try:
        logger.info(f"Creating GLPI ticket for alert: {alert_data.get('rule', {}).get('description', 'Unknown')}")
        # Prepare ticket data
        ticket_data = {
            "input": {
                "name": f"Security Alert: {alert_data.get('rule', {}).get('description', 'Unknown')}",
                "content": f"""
                **Wazuh Alert Details**

                **Agent:** {alert_data.get('agent', {}).get('name', 'N/A')}
                **Rule:** {alert_data.get('rule', {}).get('description', 'N/A')}
                **Level:** {alert_data.get('rule', {}).get('level', 'N/A')}
                **Location:** {alert_data.get('location', 'N/A')}

                **Full Alert Data:**
                ```json
                {json.dumps(alert_data, indent=2)}
                ```
                """,
                "status": 1,  # New status
                "urgency": 3,  # Medium urgency
                "impact": 3,   # Medium impact
                "priority": 3, # Medium priority
                "type": 1,     # Incident type
                "itilcategories_id": 1,  # Default category
                "requesttypes_id": 1     # Default request type
            }
        }

        # Send request to GLPI API
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'user_token {GLPI_API_TOKEN}',
            'App-Token': GLPI_API_TOKEN
        }

        # Add retry logic and timeout
        max_retries = 3
        retry_delay = 5
        timeout = 30

        for attempt in range(max_retries):
            try:
                response = requests.post(
                    f"{GLPI_URL}/apirest.php/Ticket",
                    headers=headers,
                    json=ticket_data,
                    timeout=timeout,
                    verify=True  # Changed from False to True for security
                )

                if response.status_code == 201:
                    return True, response.json().get('id')
                elif response.status_code == 401:
                    return False, "GLPI API Error: Unauthorized - Check API token"
                elif response.status_code >= 500 and attempt < max_retries - 1:
                    time.sleep(retry_delay)
                    continue
                else:
                    return False, f"GLPI API Error: {response.status_code} - {response.text}"

            except requests.exceptions.SSLError:
                # Fallback to verify=False only if SSL verification fails
                response = requests.post(
                    f"{GLPI_URL}/apirest.php/Ticket",
                    headers=headers,
                    json=ticket_data,
                    timeout=timeout,
                    verify=False
                )
                return True, response.json().get('id') if response.status_code == 201 else (False, f"SSL Error: {response.text}")

            except requests.exceptions.RequestException as e:
                if attempt < max_retries - 1:
                    time.sleep(retry_delay)
                    continue
                else:
                    return False, f"Request failed after {max_retries} attempts: {str(e)}"

        if response.status_code == 201:
            return True, response.json().get('id')
        else:
            return False, f"GLPI API Error: {response.status_code} - {response.text}"

    except Exception as e:
        logger.error(f"Exception creating ticket: {str(e)}", exc_info=True)
        return False, f"Exception creating ticket: {str(e)}"

@app.route('/webhook', methods=['POST'])
def webhook():
    """Webhook endpoint to receive Wazuh alerts"""
    try:
        logger.info("Received webhook request")
        data = request.json

        if not data:
            logger.warning("No JSON data received in webhook request")
            return jsonify({"error": "No JSON data received"}), 400

        # Create ticket in GLPI
        logger.info(f"Processing alert: {data.get('rule', {}).get('description', 'Unknown alert')}")
        success, result = create_glpi_ticket(data)

        if success:
            logger.info(f"Ticket created successfully: {result}")
            return jsonify({
                "status": "success",
                "message": "Ticket created successfully",
                "ticket_id": result
            }), 201
        else:
            logger.error(f"Failed to create ticket: {result}")
            return jsonify({
                "status": "error",
                "message": result
            }), 500

    except Exception as e:
        logger.error(f"Webhook error: {str(e)}", exc_info=True)
        return jsonify({
            "status": "error",
            "message": f"Webhook error: {str(e)}"
        }), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)