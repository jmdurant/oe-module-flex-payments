#!/bin/bash

# Flex Payments Module - Credential Setup Helper
#
# This script helps you obtain and configure Flex payment credentials
#
# Usage:
#   ./setup-flex-credentials.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to generate a secure random secret
generate_secret() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 32
    elif command -v uuidgen >/dev/null 2>&1; then
        echo "$(uuidgen)$(uuidgen)" | tr -d '-' | base64
    else
        echo "CHANGE_ME_$(date +%s)_$(head -c 32 /dev/urandom | base64 | tr -d '/+=\n')"
    fi
}

# Clear screen for better presentation
clear

print_color "$CYAN" "============================================================"
print_color "$CYAN" "      Flex Payments Module - Credential Setup Helper"
print_color "$CYAN" "============================================================"
echo ""

print_color "$YELLOW" "This helper will guide you through obtaining and configuring"
print_color "$YELLOW" "the necessary credentials for Flex HSA/FSA payment processing."
echo ""

# Step 1: Flex Account
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "$BOLD$CYAN" "STEP 1: Create a Flex Account"
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_color "$GREEN" "1. Visit: ${BOLD}https://withflex.com${NC}"
print_color "$GREEN" "2. Click 'Sign Up' or 'Get Started'"
print_color "$GREEN" "3. Complete the merchant application"
print_color "$GREEN" "4. Wait for account approval (usually 1-2 business days)"
echo ""
print_color "$GRAY" "Note: You'll need your business EIN/Tax ID and bank details"
echo ""
read -p "Press Enter when you have your Flex account ready..."
echo ""

# Step 2: API Key
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "$BOLD$CYAN" "STEP 2: Get Your API Key"
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_color "$GREEN" "1. Log in to your Flex Dashboard"
print_color "$GREEN" "2. Navigate to: ${BOLD}Settings → API Keys${NC}"
print_color "$GREEN" "3. Click '${BOLD}Create API Key${NC}'"
print_color "$GREEN" "4. Choose environment:"
print_color "$YELLOW" "   • Test Mode: Key starts with ${BOLD}sk_test_${NC}"
print_color "$YELLOW" "   • Live Mode: Key starts with ${BOLD}sk_live_${NC}"
print_color "$GREEN" "5. Copy the entire API key"
echo ""
print_color "$RED" "⚠️  IMPORTANT: Save this key securely - it won't be shown again!"
echo ""

read -p "Enter your Flex API Key: " FLEX_API_KEY
if [[ -z "$FLEX_API_KEY" ]]; then
    print_color "$RED" "No API key entered. You'll need to add it manually later."
else
    if [[ "$FLEX_API_KEY" == sk_test_* ]]; then
        print_color "$GREEN" "✓ Test mode API key detected"
        FLEX_TEST_MODE="1"
    elif [[ "$FLEX_API_KEY" == sk_live_* ]]; then
        print_color "$YELLOW" "✓ LIVE mode API key detected - real payments will be processed!"
        FLEX_TEST_MODE="0"
    else
        print_color "$YELLOW" "⚠️  Unusual key format - please verify it's correct"
        FLEX_TEST_MODE="1"
    fi
fi
echo ""

# Step 3: Webhook Configuration
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "$BOLD$CYAN" "STEP 3: Configure Webhooks (Optional but Recommended)"
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_color "$GREEN" "1. In Flex Dashboard, go to: ${BOLD}Settings → Webhooks${NC}"
print_color "$GREEN" "2. Click '${BOLD}Add Endpoint${NC}'"
print_color "$GREEN" "3. Enter your webhook URL:"
echo ""
print_color "$CYAN" "   ${BOLD}https://your-domain.com/interface/modules/custom_modules/oe-module-flex-payments/public/flex_webhook.php${NC}"
echo ""
print_color "$GRAY" "   Replace 'your-domain.com' with your actual OpenEMR domain"
echo ""
print_color "$GREEN" "4. Select events to listen for:"
print_color "$YELLOW" "   • payment.succeeded"
print_color "$YELLOW" "   • payment.failed"  
print_color "$YELLOW" "   • refund.succeeded"
print_color "$YELLOW" "   • refund.failed"
print_color "$GREEN" "5. After saving, copy the '${BOLD}Signing Secret${NC}'"
print_color "$GRAY" "   (It starts with ${BOLD}whsec_${NC})"
echo ""

read -p "Enter your Webhook Signing Secret (or press Enter to skip): " FLEX_WEBHOOK_SECRET
if [[ -z "$FLEX_WEBHOOK_SECRET" ]]; then
    print_color "$YELLOW" "⚠️  No webhook secret entered. Webhooks won't be verified."
else
    if [[ "$FLEX_WEBHOOK_SECRET" == whsec_* ]]; then
        print_color "$GREEN" "✓ Valid webhook secret format"
    else
        print_color "$YELLOW" "⚠️  Unusual secret format - please verify it's correct"
    fi
fi
echo ""

# Step 4: Mobile Integration
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "$BOLD$CYAN" "STEP 4: Mobile App Integration (Optional)"
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_color "$GREEN" "For Flutter/mobile app integration, you need an HMAC secret."
print_color "$GREEN" "This protects the mobile API endpoint from unauthorized use."
echo ""

read -p "Generate a mobile HMAC secret? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    FLEX_MOBILE_SECRET=$(generate_secret)
    print_color "$GREEN" "✓ Generated mobile HMAC secret:"
    print_color "$CYAN" "  $FLEX_MOBILE_SECRET"
    echo ""
    print_color "$YELLOW" "⚠️  Save this secret - you'll need it in your mobile app!"
else
    FLEX_MOBILE_SECRET=""
    print_color "$GRAY" "Skipping mobile secret generation"
fi
echo ""

# Step 5: API Base URL
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "$BOLD$CYAN" "STEP 5: API Endpoint Configuration"
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_color "$GREEN" "Default Flex API URL: ${BOLD}https://api.withflex.com${NC}"
echo ""
read -p "Use default API URL? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    FLEX_API_BASE_URL="https://api.withflex.com"
    print_color "$GREEN" "✓ Using default API URL"
else
    read -p "Enter custom API URL: " FLEX_API_BASE_URL
    if [[ -z "$FLEX_API_BASE_URL" ]]; then
        FLEX_API_BASE_URL="https://api.withflex.com"
        print_color "$YELLOW" "Using default: $FLEX_API_BASE_URL"
    fi
fi
echo ""

# Summary and Save
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "$BOLD$CYAN" "Configuration Summary"
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -n "$FLEX_API_KEY" ]]; then
    print_color "$GREEN" "✓ API Key: ${GRAY}***${FLEX_API_KEY: -8}${NC}"
else
    print_color "$RED" "✗ API Key: Not configured"
fi

if [[ -n "$FLEX_WEBHOOK_SECRET" ]]; then
    print_color "$GREEN" "✓ Webhook Secret: ${GRAY}***${FLEX_WEBHOOK_SECRET: -8}${NC}"
else
    print_color "$YELLOW" "○ Webhook Secret: Not configured (optional)"
fi

if [[ -n "$FLEX_MOBILE_SECRET" ]]; then
    print_color "$GREEN" "✓ Mobile HMAC: ${GRAY}***${FLEX_MOBILE_SECRET: -8}${NC}"
else
    print_color "$GRAY" "○ Mobile HMAC: Not configured (optional)"
fi

print_color "$GREEN" "✓ Test Mode: $([ "$FLEX_TEST_MODE" = "1" ] && echo "YES" || echo "NO")"
print_color "$GREEN" "✓ API URL: $FLEX_API_BASE_URL"
echo ""

# Save configuration
CONFIG_FILE="flex.conf"
print_color "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Save configuration to $CONFIG_FILE? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cat > "$CONFIG_FILE" << EOF
# Flex Payment Module Configuration
# Generated: $(date)
# 
# WARNING: This file contains sensitive credentials!
# Do not commit to version control or share publicly.

# API Credentials
FLEX_API_KEY="$FLEX_API_KEY"
FLEX_WEBHOOK_SECRET="$FLEX_WEBHOOK_SECRET"
FLEX_MOBILE_SECRET="$FLEX_MOBILE_SECRET"

# Configuration
FLEX_TEST_MODE="$FLEX_TEST_MODE"
FLEX_API_BASE_URL="$FLEX_API_BASE_URL"
EOF
    
    chmod 600 "$CONFIG_FILE"
    print_color "$GREEN" "✓ Configuration saved to $CONFIG_FILE"
    print_color "$YELLOW" "  File permissions set to 600 (owner read/write only)"
    echo ""
    
    # Offer to deploy immediately
    if [[ -f "./deploy-flex-payments-with-config.sh" ]]; then
        print_color "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        read -p "Deploy Flex Payments module now with these settings? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_color "$GREEN" "Starting deployment..."
            echo ""
            ./deploy-flex-payments-with-config.sh -c "$CONFIG_FILE"
        else
            print_color "$CYAN" "To deploy later, run:"
            print_color "$YELLOW" "  ./deploy-flex-payments-with-config.sh -c $CONFIG_FILE"
        fi
    else
        print_color "$CYAN" "To deploy with these settings, run:"
        print_color "$YELLOW" "  ./deploy-flex-payments-with-config.sh -c $CONFIG_FILE"
    fi
else
    print_color "$YELLOW" "Configuration not saved."
    echo ""
    print_color "$CYAN" "To use these settings, export as environment variables:"
    echo ""
    [[ -n "$FLEX_API_KEY" ]] && print_color "$GRAY" "export FLEX_API_KEY=\"$FLEX_API_KEY\""
    [[ -n "$FLEX_WEBHOOK_SECRET" ]] && print_color "$GRAY" "export FLEX_WEBHOOK_SECRET=\"$FLEX_WEBHOOK_SECRET\""
    [[ -n "$FLEX_MOBILE_SECRET" ]] && print_color "$GRAY" "export FLEX_MOBILE_SECRET=\"$FLEX_MOBILE_SECRET\""
    print_color "$GRAY" "export FLEX_TEST_MODE=\"$FLEX_TEST_MODE\""
    print_color "$GRAY" "export FLEX_API_BASE_URL=\"$FLEX_API_BASE_URL\""
    echo ""
    print_color "$CYAN" "Then run:"
    print_color "$YELLOW" "  ./deploy-flex-payments-with-config.sh"
fi

echo ""
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "$GREEN" "✅ Setup Complete!"
print_color "$MAGENTA" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Additional resources
print_color "$CYAN" "📚 Additional Resources:"
print_color "$GRAY" "  • Flex Documentation: https://docs.withflex.com"
print_color "$GRAY" "  • API Reference: https://docs.withflex.com/api"
print_color "$GRAY" "  • Support: support@withflex.com"
echo ""
print_color "$CYAN" "🔒 Security Reminders:"
print_color "$YELLOW" "  • Never commit flex.conf to version control"
print_color "$YELLOW" "  • Rotate API keys regularly"
print_color "$YELLOW" "  • Use test mode for development"
print_color "$YELLOW" "  • Monitor webhook logs for suspicious activity"
echo ""

exit 0