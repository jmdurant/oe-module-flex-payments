#!/bin/bash

# Flex Payments Module Deployment Script with Configuration
# 
# Usage with environment variables:
#   export FLEX_API_KEY="your-api-key"
#   export FLEX_WEBHOOK_SECRET="your-webhook-secret"
#   export FLEX_TEST_MODE="1"  # or "0" for production
#   ./deploy-flex-payments-with-config.sh
#
# Or inline:
#   FLEX_API_KEY="key" FLEX_WEBHOOK_SECRET="secret" ./deploy-flex-payments-with-config.sh
#
# Or with config file:
#   ./deploy-flex-payments-with-config.sh -c /path/to/flex.conf

# Set strict error handling
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Default parameters
FORCE=false
PROJECT="official"
ENVIRONMENT="production"
RESTART=false
CONFIG_FILE=""

# Parse command line arguments
while getopts "fp:e:rc:" opt; do
  case $opt in
    f)
      FORCE=true
      ;;
    p)
      PROJECT="$OPTARG"
      ;;
    e)
      ENVIRONMENT="$OPTARG"
      ;;
    r)
      RESTART=true
      ;;
    c)
      CONFIG_FILE="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Load config file if specified
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    print_color "$CYAN" "Loading configuration from: $CONFIG_FILE"
    source "$CONFIG_FILE"
fi

# Define paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONTAINER_NAME="${PROJECT}-${ENVIRONMENT}-openemr-1"

# First run the standard deployment
print_color "$CYAN" "Running standard deployment..."
"${SCRIPT_DIR}/deploy-flex-payments.sh" ${FORCE:+-f} -p "$PROJECT" -e "$ENVIRONMENT" ${RESTART:+-r}

# Now configure the module settings if credentials are provided
if [[ -n "${FLEX_API_KEY:-}" ]] || [[ -n "${FLEX_WEBHOOK_SECRET:-}" ]]; then
    print_color "$CYAN" "===================================================="
    print_color "$CYAN" "Configuring Flex Payment Settings"
    print_color "$CYAN" "===================================================="
    
    # Function to encrypt a value using OpenEMR's encryption
    encrypt_value() {
        local value="$1"
        local encrypted=$(docker exec "$CONTAINER_NAME" php -r "
            require_once '/var/www/localhost/htdocs/openemr/vendor/autoload.php';
            require_once '/var/www/localhost/htdocs/openemr/src/Common/Crypto/CryptoGen.php';
            \$crypto = new \OpenEMR\Common\Crypto\CryptoGen();
            echo \$crypto->encryptStandard('$value');
        " 2>/dev/null)
        echo "$encrypted"
    }
    
    # Configure API Key
    if [[ -n "${FLEX_API_KEY:-}" ]]; then
        print_color "$GREEN" "Setting Flex API Key..."
        ENCRYPTED_KEY=$(encrypt_value "$FLEX_API_KEY")
        docker exec "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e \
            "INSERT INTO globals (gl_name, gl_value) VALUES ('oe_skeleton_flex_api_key_encrypted', '$ENCRYPTED_KEY') 
             ON DUPLICATE KEY UPDATE gl_value = '$ENCRYPTED_KEY';" 2>/dev/null || true
        print_color "$GREEN" "  ✓ API Key configured"
    fi
    
    # Configure Webhook Secret
    if [[ -n "${FLEX_WEBHOOK_SECRET:-}" ]]; then
        print_color "$GREEN" "Setting Flex Webhook Secret..."
        ENCRYPTED_SECRET=$(encrypt_value "$FLEX_WEBHOOK_SECRET")
        docker exec "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e \
            "INSERT INTO globals (gl_name, gl_value) VALUES ('oe_skeleton_flex_webhook_secret_encrypted', '$ENCRYPTED_SECRET') 
             ON DUPLICATE KEY UPDATE gl_value = '$ENCRYPTED_SECRET';" 2>/dev/null || true
        print_color "$GREEN" "  ✓ Webhook Secret configured"
    fi
    
    # Configure Mobile HMAC Secret
    if [[ -n "${FLEX_MOBILE_SECRET:-}" ]]; then
        print_color "$GREEN" "Setting Mobile HMAC Secret..."
        ENCRYPTED_MOBILE=$(encrypt_value "$FLEX_MOBILE_SECRET")
        docker exec "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e \
            "INSERT INTO globals (gl_name, gl_value) VALUES ('oe_skeleton_flex_mobile_hmac_secret_encrypted', '$ENCRYPTED_MOBILE') 
             ON DUPLICATE KEY UPDATE gl_value = '$ENCRYPTED_MOBILE';" 2>/dev/null || true
        print_color "$GREEN" "  ✓ Mobile HMAC Secret configured"
    fi
    
    # Configure Test Mode
    if [[ -n "${FLEX_TEST_MODE:-}" ]]; then
        print_color "$GREEN" "Setting Test Mode to: ${FLEX_TEST_MODE}"
        docker exec "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e \
            "INSERT INTO globals (gl_name, gl_value) VALUES ('oe_skeleton_flex_test_mode', '$FLEX_TEST_MODE') 
             ON DUPLICATE KEY UPDATE gl_value = '$FLEX_TEST_MODE';" 2>/dev/null || true
        print_color "$GREEN" "  ✓ Test Mode configured"
    fi
    
    # Configure API Base URL
    if [[ -n "${FLEX_API_BASE_URL:-}" ]]; then
        print_color "$GREEN" "Setting API Base URL: ${FLEX_API_BASE_URL}"
        docker exec "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e \
            "INSERT INTO globals (gl_name, gl_value) VALUES ('oe_skeleton_flex_api_base_url', '$FLEX_API_BASE_URL') 
             ON DUPLICATE KEY UPDATE gl_value = '$FLEX_API_BASE_URL';" 2>/dev/null || true
        print_color "$GREEN" "  ✓ API Base URL configured"
    fi
    
    print_color "$GREEN" "===================================================="
    print_color "$GREEN" "✅ Flex Payment Settings Configured!"
    print_color "$GREEN" "===================================================="
    echo ""
    print_color "$CYAN" "Configured Settings:"
    [[ -n "${FLEX_API_KEY:-}" ]] && print_color "$GRAY" "  • API Key: ***${FLEX_API_KEY: -4}"
    [[ -n "${FLEX_WEBHOOK_SECRET:-}" ]] && print_color "$GRAY" "  • Webhook Secret: ***${FLEX_WEBHOOK_SECRET: -4}"
    [[ -n "${FLEX_MOBILE_SECRET:-}" ]] && print_color "$GRAY" "  • Mobile HMAC: ***${FLEX_MOBILE_SECRET: -4}"
    [[ -n "${FLEX_TEST_MODE:-}" ]] && print_color "$GRAY" "  • Test Mode: $([ "$FLEX_TEST_MODE" = "1" ] && echo "YES" || echo "NO")"
    [[ -n "${FLEX_API_BASE_URL:-}" ]] && print_color "$GRAY" "  • API URL: $FLEX_API_BASE_URL"
    echo ""
else
    print_color "$YELLOW" "No Flex credentials provided. Configure them manually in:"
    print_color "$GRAY" "  Administration → Globals → Portal → Flex HSA/FSA Payments"
    echo ""
    print_color "$CYAN" "To auto-configure, set environment variables:"
    print_color "$GRAY" "  export FLEX_API_KEY='your-api-key'"
    print_color "$GRAY" "  export FLEX_WEBHOOK_SECRET='your-webhook-secret'"
    print_color "$GRAY" "  export FLEX_TEST_MODE='1'  # or '0' for production"
    print_color "$GRAY" "  ./deploy-flex-payments-with-config.sh"
    echo ""
    print_color "$CYAN" "Or use a config file:"
    print_color "$GRAY" "  ./deploy-flex-payments-with-config.sh -c flex.conf"
fi

print_color "$GREEN" "Deployment with configuration completed!"