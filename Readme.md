# Flex HSA/FSA Payments Module for OpenEMR

This OpenEMR module integrates Flex (HSA/FSA) payment processing for healthcare providers, allowing patients to pay using their HSA/FSA cards through a secure hosted checkout experience.

## Features

- **Hosted Checkout Integration**: PCI-compliant payment processing through Flex's hosted checkout
- **HSA/FSA Card Support**: Specialized payment flow for healthcare spending accounts
- **Multi-interface Support**: Works in staff payment modals and patient portal
- **Automatic Refund Reconciliation**: Posts refunds directly to accounts receivable
- **Webhook Support**: Real-time payment status updates with HMAC signature verification
- **Mobile App Integration**: Flutter plugin for native iOS/Android apps
- **Test Mode**: Safe testing environment before going live

## Quick Links

- **OpenEMR Module Documentation**: `docs/Flex-OpenEMR-Module.md`
- **Flutter Plugin Documentation**: `docs/Flutter-Flex-Plugin.md`

## Installation

### Via Composer (Recommended)

```bash
composer require openemr/oe-module-flex-payments
```

### Manual Installation

1. Clone this repository into your OpenEMR custom modules directory:
   ```bash
   cd <openemr_installation>/interface/modules/custom_modules/
   git clone https://github.com/your-org/oe-module-flex-payments
   ```

2. Run composer autoload update:
   ```bash
   composer dump-autoload
   ```

### Activation

1. Login to OpenEMR as an administrator
2. Navigate to **Modules → Manage Modules**
3. Click the **Unregistered** tab
4. Find "Flex Payments" and click **Register**
5. Click **Install**, then **Enable**

## Configuration

Navigate to **Administration → Globals → Portal → "Flex HSA/FSA Payments"**

### Required Settings

- **Enable Flex Gateway**: Toggle to activate the module
- **Flex API Base URL**: Your Flex API endpoint (e.g., `https://api.withflex.com`)
- **Flex API Key**: Your encrypted API key from Flex

### Optional Settings

- **Test Mode**: Enable for testing without processing real payments
- **Webhook Secret**: For verifying webhook signatures
- **Auto-post Refunds**: Automatically create AR entries for refunds
- **Mobile HMAC Secret**: For securing mobile app requests

## Usage

### Staff Payment Processing

1. Navigate to patient account
2. Click **Record Payment**
3. Select **Pay with Flex** button
4. Complete payment in hosted checkout
5. Payment automatically posts to patient account

### Patient Portal

Patients see a **Pay with Flex** button on their payment tile, providing direct access to HSA/FSA payment options.

### Mobile App Integration

The included Flutter plugin enables native mobile payment flows. See `docs/Flutter-Flex-Plugin.md` for implementation details.

## Security Features

- All API credentials are encrypted at rest
- HMAC SHA-256 signature verification for webhooks
- No card data touches your servers (PCI-compliant hosted checkout)
- Timestamp validation and nonce support for mobile requests

## Module Structure

```
oe-module-flex-payments/
├── src/                    # PHP source files
│   ├── Bootstrap.php       # Module initialization
│   ├── FlexGatewayService.php # Flex API wrapper
│   ├── GlobalConfig.php    # Configuration management
│   └── RefundReconciler.php # AR posting logic
├── public/                 # Web endpoints
│   ├── flex_controller.php # Main API controller
│   ├── flex_webhook.php   # Webhook handler
│   └── assets/js/         # JavaScript assets
├── flutter_flex/          # Flutter mobile plugin
├── templates/             # Twig templates
└── docs/                  # Documentation
```

## Support

For issues or questions:
- Check the documentation in `/docs`
- Submit issues on GitHub
- Contact your Flex integration specialist

## Contributing

Contributions are welcome! Please submit pull requests with:
- Clear commit messages
- Updated documentation
- Test coverage where applicable

## License

GPL-3.0 License - See LICENSE file for details

## Credits

Originally based on the OpenEMR Custom Module Skeleton by Stephen Nielson.
Extended with Flex payment integration for healthcare providers.