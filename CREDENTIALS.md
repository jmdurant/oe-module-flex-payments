# Flex Payments - Credential Setup Guide

## Quick Start

Run the interactive setup helper:
```bash
./setup-flex-credentials.sh
```

This will guide you through obtaining and configuring all necessary credentials.

## Manual Setup

### 1. Obtain Flex Account & API Key

1. **Sign up at [withflex.com](https://withflex.com)**
   - You'll need your business EIN/Tax ID
   - Bank account details for settlements
   - Wait for account approval (1-2 business days)

2. **Get your API Key**
   - Log into Flex Dashboard
   - Go to Settings → API Keys
   - Create new key (test or live mode)
   - Copy the key (starts with `sk_test_` or `sk_live_`)

### 2. Configure Webhooks (Optional but Recommended)

1. **In Flex Dashboard → Settings → Webhooks**
2. **Add endpoint URL:**
   ```
   https://YOUR-DOMAIN.com/interface/modules/custom_modules/oe-module-flex-payments/public/flex_webhook.php
   ```
3. **Select events:**
   - `payment.succeeded`
   - `payment.failed`
   - `refund.succeeded`
   - `refund.failed`
4. **Copy the signing secret** (starts with `whsec_`)

### 3. Generate Mobile HMAC Secret (If Using Mobile App)

```bash
# Generate a secure random secret
openssl rand -base64 32
```

Save this secret - you'll need it in your Flutter app configuration.

## Credential Storage Options

### Option A: Configuration File (Recommended)
```bash
# Copy template
cp flex.conf.example flex.conf

# Edit with your credentials
nano flex.conf

# Deploy with config
./deploy-flex-payments-with-config.sh -c flex.conf
```

### Option B: Environment Variables
```bash
export FLEX_API_KEY="sk_test_your_key"
export FLEX_WEBHOOK_SECRET="whsec_your_secret"
export FLEX_MOBILE_SECRET="your_mobile_secret"
export FLEX_TEST_MODE="1"  # 1 for test, 0 for live

./deploy-flex-payments-with-config.sh
```

### Option C: Manual Entry in OpenEMR
1. Deploy module: `./deploy-flex-payments.sh`
2. Log into OpenEMR as admin
3. Go to: Administration → Globals → Portal → Flex HSA/FSA Payments
4. Enter credentials manually

## Security Best Practices

### ⚠️ NEVER Commit Credentials
- `flex.conf` is in `.gitignore`
- Don't commit any file with real keys
- Use environment variables in CI/CD

### 🔐 Credential Security
1. **API Keys**: Treat like passwords
2. **Test vs Live**: Always start with test keys
3. **Rotation**: Rotate keys periodically
4. **Access**: Limit who has access to production keys

### 🔍 Verify Your Setup
After configuration, test with a small payment:
1. Enable test mode
2. Use Flex test card numbers
3. Process a $1.00 test payment
4. Verify in both OpenEMR and Flex Dashboard

## Troubleshooting

### API Key Not Working
- Verify key starts with `sk_test_` or `sk_live_`
- Check if key matches the mode (test/live)
- Ensure key hasn't been revoked

### Webhooks Not Received
- Verify endpoint URL is publicly accessible
- Check webhook secret matches
- Review Flex Dashboard webhook logs
- Ensure OpenEMR module is enabled

### Mobile App Can't Connect
- Verify mobile HMAC secret matches
- Check CORS is enabled in settings
- Ensure endpoint is accessible from mobile

## Support

- **Flex Support**: support@withflex.com
- **Flex Docs**: https://docs.withflex.com
- **Module Issues**: Create issue on GitHub
- **OpenEMR Forums**: https://community.open-emr.org

## Testing Credentials

For initial testing, you can use Flex's test mode:
- API Key: `sk_test_...` (from your dashboard)
- Test cards: See [Flex Testing Guide](https://docs.withflex.com/testing)

## Environment-Specific URLs

| Environment | API Base URL |
|------------|--------------|
| Production | `https://api.withflex.com` |
| Sandbox/Test | Contact Flex for test environment URL |

---

**Remember**: Always start with test credentials and verify everything works before switching to live mode!