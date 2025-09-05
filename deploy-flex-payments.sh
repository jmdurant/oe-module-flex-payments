#!/bin/bash

# Flex Payments Module Deployment Script for OpenEMR (Docker) - Linux Version
#
# Deploys the Flex HSA/FSA payment integration module
#
# Usage:
#   ./deploy-flex-payments.sh                                    # Default deployment
#   ./deploy-flex-payments.sh -f                                # Clean install with defaults
#   ./deploy-flex-payments.sh -p "myproject" -e "prod"         # Custom project/environment
#   ./deploy-flex-payments.sh -r                                # Force container restart
#
# Parameters:
#   -f  : Perform clean uninstall before deployment AND skip all prompts
#   -p  : Project name for container naming (default: "official")
#   -e  : Environment name for container naming (default: "production")
#   -r  : Force container restart

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

# Parse command line arguments
while getopts "fp:e:r" opt; do
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
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Define paths - dynamically determine base directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONTAINER_NAME="${PROJECT}-${ENVIRONMENT}-openemr-1"
SOURCE_DIR="${SCRIPT_DIR}"
MODULE_NAME="oe-module-flex-payments"
# Determine the actual user's home directory (handle sudo)
if [[ -n "$SUDO_USER" ]]; then
    ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    ACTUAL_HOME="$HOME"
fi
# Use the mounted OpenEMR directory
BASE_TARGET_DIR="${ACTUAL_HOME}/openemr/interface/modules/custom_modules"
TARGET_DIR="${BASE_TARGET_DIR}/${MODULE_NAME}"
CONTAINER_MODULES_DIR="/var/www/localhost/htdocs/openemr/interface/modules/custom_modules"
CONTAINER_MODULE_DIR="${CONTAINER_MODULES_DIR}/${MODULE_NAME}"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to perform a clean uninstall
uninstall_flex_payments_module() {
    print_color "$YELLOW" "Performing clean uninstall of Flex Payments Module..."
    
    # Remove module from container
    docker exec -it "$CONTAINER_NAME" rm -rf "$CONTAINER_MODULE_DIR" 2>/dev/null || true
    
    # Remove module from database
    docker exec -it "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e "DELETE FROM modules WHERE mod_directory = '$MODULE_NAME';" 2>/dev/null || true
    
    # Remove Flex refunds table if it exists (optional - commented out to preserve data)
    print_color "$YELLOW" "Preserving Flex refunds data (uncomment in script to remove)..."
    # docker exec -it "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e "DROP TABLE IF EXISTS module_flex_refunds;" 2>/dev/null || true
    
    # Remove custom skeleton table if exists
    # docker exec -it "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e "DROP TABLE IF EXISTS mod_custom_skeleton_records;" 2>/dev/null || true
    
    # Remove global settings
    print_color "$YELLOW" "Removing Flex global settings..."
    docker exec -it "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e "DELETE FROM globals WHERE gl_name LIKE 'oe_flex_%';" 2>/dev/null || true
    docker exec -it "$CONTAINER_NAME" mariadb -uopenemr -popenemr openemr -e "DELETE FROM globals WHERE gl_name LIKE 'my_module_%';" 2>/dev/null || true
    
    print_color "$GREEN" "Clean uninstall completed."
}

# Display configuration
echo ""
print_color "$CYAN" "===================================================="
print_color "$CYAN" "Flex HSA/FSA Payments Module Deployment Script (Docker)"
print_color "$CYAN" "===================================================="
print_color "$YELLOW" "Configuration:"
print_color "$GRAY" "  Project: $PROJECT"
print_color "$GRAY" "  Environment: $ENVIRONMENT"
print_color "$GRAY" "  Container: $CONTAINER_NAME"
print_color "$GRAY" "  Source: $SOURCE_DIR"
print_color "$GRAY" "  Target: $TARGET_DIR"
echo ""

print_color "$YELLOW" "Payment Features:"
print_color "$GREEN" "  ✓ HSA/FSA card payment processing"
print_color "$GREEN" "  ✓ PCI-compliant hosted checkout (no card data stored)"
print_color "$GREEN" "  ✓ Automatic payment posting to accounts receivable"
print_color "$GREEN" "  ✓ Refund processing with AR reconciliation"
print_color "$GREEN" "  ✓ Receipt generation and delivery"
print_color "$GREEN" "  ✓ Webhook signature verification (HMAC SHA-256)"
print_color "$GREEN" "  ✓ Flutter mobile app integration"
print_color "$GREEN" "  ✓ Patient portal integration"
echo ""

# Check if source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    print_color "$RED" "Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

# Update from git repository
GIT_REPO_DIR="$SCRIPT_DIR"
if [[ -d "$GIT_REPO_DIR/.git" ]]; then
    print_color "$CYAN" "Updating Flex Payments module from git repository..."
    CURRENT_DIR=$(pwd)
    cd "$GIT_REPO_DIR"
    git pull origin main 2>&1 | sed 's/^/  /'
    print_color "$GREEN" "✓ Git pull completed"
    cd "$CURRENT_DIR"
else
    print_color "$YELLOW" "Warning: Git repository not found at $GIT_REPO_DIR"
fi

# Ask user if they want to perform a clean uninstall
if [[ "$FORCE" == "true" ]]; then
    uninstall_flex_payments_module
else
    read -p "Do you want to perform a clean uninstall before deploying? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        uninstall_flex_payments_module
        read -p "Module uninstalled. Do you want to continue with deployment? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_color "$YELLOW" "Deployment canceled by user."
            exit 0
        fi
    fi
fi

# Create base target directory if it doesn't exist
sudo mkdir -p "$BASE_TARGET_DIR"

# Remove existing installation if it exists
if [[ -d "$TARGET_DIR" ]]; then
    print_color "$YELLOW" "Removing existing installation..."
    sudo rm -rf "$TARGET_DIR"
fi

# Create target directory
print_color "$GREEN" "Creating target directory..."
sudo mkdir -p "$TARGET_DIR"

# Copy files, excluding git files and vendor directory
print_color "$GREEN" "Copying files to target directory..."
print_color "$YELLOW" "  ⚠️  Excluding: .git, vendor, node_modules, flutter_stripe-main, oe-module-payroll, openemr"

# Need sudo to copy to the protected directory
sudo rsync -av --exclude='.git' --exclude='.gitignore' --exclude='vendor' \
      --exclude='node_modules' --exclude='composer.lock' \
      --exclude='flutter_stripe-main' --exclude='oe-module-payroll' \
      --exclude='openemr' --exclude='.claude' --exclude='deploy-*.sh' \
      "$SOURCE_DIR/" "$TARGET_DIR/"

# Match ownership with other modules
if [[ -d "$BASE_TARGET_DIR/oe-module-telehealth" ]]; then
    OWNER_GROUP=$(stat -c "%U:%G" "$BASE_TARGET_DIR/oe-module-telehealth")
    print_color "$GREEN" "Setting ownership to match other modules: $OWNER_GROUP"
    sudo chown -R "$OWNER_GROUP" "$TARGET_DIR"
elif [[ -d "$BASE_TARGET_DIR" ]]; then
    OWNER_GROUP=$(stat -c "%U:%G" "$BASE_TARGET_DIR")
    print_color "$GREEN" "Setting ownership to match base directory: $OWNER_GROUP"
    sudo chown -R "$OWNER_GROUP" "$TARGET_DIR"
fi

# Fix permissions
print_color "$GREEN" "Fixing OpenEMR permissions for module installation..."
docker exec "$CONTAINER_NAME" chown -R apache:apache /var/www/localhost/htdocs/openemr/
docker exec "$CONTAINER_NAME" chmod 755 /var/www/localhost/htdocs/openemr/interface/forms/

# Since we're using a mounted volume, the files are already in the container
print_color "$GREEN" "Module files deployed to mounted volume"

# Run composer install (if composer.json exists)
if [[ -f "$TARGET_DIR/composer.json" ]]; then
    print_color "$GREEN" "Running composer install..."
    
    # Configure Composer plugins
    docker exec "$CONTAINER_NAME" sh -c "cd $CONTAINER_MODULE_DIR && composer config --no-plugins allow-plugins.openemr/oe-module-installer-plugin true" 2>/dev/null || true
    
    # Install dependencies
    COMPOSER_CMD="cd $CONTAINER_MODULE_DIR && composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist --no-progress"
    print_color "$GRAY" "  Command: $COMPOSER_CMD"
    
    if docker exec "$CONTAINER_NAME" sh -c "$COMPOSER_CMD"; then
        print_color "$GREEN" "Composer install completed successfully"
    else
        print_color "$YELLOW" "Warning: Composer install failed or not needed"
        print_color "$YELLOW" "  Module may not require external dependencies"
    fi
else
    print_color "$CYAN" "No composer.json found - skipping composer install"
fi

# Apply Twig template overrides for patient portal
print_color "$GREEN" "Deploying patient portal integration..."
LOCAL_PORTAL_TEMPLATES="${TARGET_DIR}/templates/portal"
if [[ -d "$LOCAL_PORTAL_TEMPLATES" ]]; then
    print_color "$CYAN" "  Portal Twig templates deployed with module"
    print_color "$GRAY" "  Templates will override default portal navigation"
    print_color "$GREEN" "  ✓ 'Pay with Flex' button will appear in patient portal Payments tile"
else
    print_color "$YELLOW" "  No portal template overrides found"
fi

# Container restart handling
if [[ "$RESTART" == "true" ]]; then
    print_color "$YELLOW" "Restarting OpenEMR container..."
    docker restart "$CONTAINER_NAME"
    sleep 5
elif [[ "$FORCE" != "true" ]]; then
    read -p "Do you want to restart the OpenEMR container? (y/n) [default: n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_color "$YELLOW" "Restarting OpenEMR container..."
        docker restart "$CONTAINER_NAME"
        sleep 5
    fi
fi

# Display success message
echo ""
print_color "$GREEN" "===================================================="
print_color "$GREEN" "✅ Flex Payments Module Deployed Successfully!"
print_color "$GREEN" "===================================================="
echo ""
print_color "$YELLOW" "Next steps:"
print_color "$YELLOW" "1. Log in to OpenEMR as administrator"
print_color "$YELLOW" "2. Go to Modules > Manage Modules"
print_color "$YELLOW" "3. Find 'Flex Payments' and click 'Register'"
print_color "$YELLOW" "4. Click 'Install' then 'Enable'"
print_color "$YELLOW" "5. Configure Flex settings:"
print_color "$GRAY" "   • Navigate to: Administration → Globals → Portal → Flex HSA/FSA Payments"
print_color "$GRAY" "   • Enter your Flex API credentials"
print_color "$GRAY" "   • Configure webhook secret for security"
print_color "$GRAY" "   • Enable auto-post refunds to AR (recommended)"
echo ""
print_color "$CYAN" "Required Configuration:"
print_color "$GRAY" "  • Flex API Base URL: https://api.withflex.com (or your test URL)"
print_color "$GRAY" "  • Flex API Key: [Your encrypted API key]"
print_color "$GRAY" "  • Test Mode: YES for testing, NO for production"
print_color "$GRAY" "  • Enable Body Footer Injection: YES (for UI integration)"
print_color "$GRAY" "  • Enable Flex Gateway: YES"
echo ""
print_color "$CYAN" "Optional Security Settings:"
print_color "$GRAY" "  • Webhook Secret: [Your HMAC secret for signature verification]"
print_color "$GRAY" "  • Webhook Signature Header: Flex-Signature (default)"
print_color "$GRAY" "  • Webhook Tolerance: 300 seconds (default)"
print_color "$GRAY" "  • Mobile HMAC Secret: [For Flutter app integration]"
echo ""
print_color "$CYAN" "Integration Points:"
print_color "$GRAY" "  • Staff: Record Payment → 'Pay with Flex' button"
print_color "$GRAY" "  • Portal: Payments tile → 'Pay with Flex' button"
print_color "$GRAY" "  • Terminal: Stripe Terminal window → 'Pay with Flex' option"
print_color "$GRAY" "  • Admin: Modules → Flex Payments → Settings/Session Info"
echo ""
print_color "$CYAN" "Webhook Configuration:"
print_color "$GRAY" "  Configure this URL in your Flex dashboard:"
print_color "$GRAY" "  https://your-domain.com/interface/modules/custom_modules/$MODULE_NAME/public/flex_webhook.php"
echo ""
print_color "$CYAN" "Mobile App Integration:"
print_color "$GRAY" "  • Flutter plugin: flutter_flex/"
print_color "$GRAY" "  • Example app: flutter_flex/example/"
print_color "$GRAY" "  • Create checkout endpoint: /public/flex_controller.php?mode=create_checkout"
print_color "$GRAY" "  • Enable CORS if needed: 'Allow Mobile CORS' in settings"
echo ""
print_color "$CYAN" "Testing Payments:"
print_color "$GRAY" "  1. Enable Test Mode in settings"
print_color "$GRAY" "  2. Use Flex test card numbers"
print_color "$GRAY" "  3. Process a test payment from staff or portal"
print_color "$GRAY" "  4. Verify payment posts to patient account"
print_color "$GRAY" "  5. Test refund processing"
echo ""
print_color "$GREEN" "💳 HSA/FSA payments are now available for your patients!"
print_color "$GREEN" "Deployment completed!"