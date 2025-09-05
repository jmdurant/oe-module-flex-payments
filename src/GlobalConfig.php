<?php

/**
 * Bootstrap custom module skeleton.  This file is an example custom module that can be used
 * to create modules that can be utilized inside the OpenEMR system.  It is NOT intended for
 * production and is intended to serve as the barebone requirements you need to get started
 * writing modules that can be installed and used in OpenEMR.
 *
 * @package   OpenEMR
 * @link      http://www.open-emr.org
 *
 * @author    Stephen Nielson <stephen@nielson.org>
 * @copyright Copyright (c) 2021 Stephen Nielson <stephen@nielson.org>
 * @license   https://github.com/openemr/openemr/blob/master/LICENSE GNU General Public License 3
 */

namespace OpenEMR\Modules\FlexPayments;

use OpenEMR\Common\Crypto\CryptoGen;
use OpenEMR\Services\Globals\GlobalSetting;

class GlobalConfig
{
    const CONFIG_OPTION_TEXT = 'oe_skeleton_config_option_text';
    const CONFIG_OPTION_ENCRYPTED = 'oe_skeleton_config_option_encrypted';
    const CONFIG_OVERRIDE_TEMPLATES = "oe_skeleton_override_twig_templates";
    const CONFIG_ENABLE_MENU = "oe_skeleton_add_menu_button";
    const CONFIG_ENABLE_BODY_FOOTER = "oe_skeleton_add_body_footer";
    const CONFIG_ENABLE_FHIR_API = "oe_skeleton_enable_fhir_api";

    // Flex gateway configuration (encrypted + toggles)
    const FLEX_ENABLE = 'oe_skeleton_flex_enable';
    const FLEX_API_BASE_URL = 'oe_skeleton_flex_api_base_url';
    const FLEX_API_KEY_ENCRYPTED = 'oe_skeleton_flex_api_key_encrypted';
    const FLEX_TEST_MODE = 'oe_skeleton_flex_test_mode';
    const FLEX_WEBHOOK_SECRET_ENCRYPTED = 'oe_skeleton_flex_webhook_secret_encrypted';
    const FLEX_WEBHOOK_SIGNATURE_HEADER = 'oe_skeleton_flex_webhook_signature_header';
    const FLEX_WEBHOOK_TOLERANCE_SECONDS = 'oe_skeleton_flex_webhook_tolerance_seconds';
    const FLEX_AUTO_POST_REFUNDS = 'oe_skeleton_flex_auto_post_refunds';
    // Mobile app integration
    const FLEX_MOBILE_HMAC_SECRET_ENCRYPTED = 'oe_skeleton_flex_mobile_hmac_secret_encrypted';
    const FLEX_ALLOW_MOBILE_CORS = 'oe_skeleton_flex_allow_mobile_cors';

    private $globalsArray;

    /**
     * @var CryptoGen
     */
    private $cryptoGen;

    public function __construct(array $globalsArray)
    {
        $this->globalsArray = $globalsArray;
        $this->cryptoGen = new CryptoGen();
    }

    /**
     * Returns true if all of the settings have been configured.  Otherwise it returns false.
     * @return bool
     */
    public function isConfigured()
    {
        $keys = [self::CONFIG_OPTION_TEXT, self::CONFIG_OPTION_ENCRYPTED];
        foreach ($keys as $key) {
            $value = $this->getGlobalSetting($key);
            if (empty($value)) {
                return false;
            }
        }
        return true;
    }

    public function getTextOption()
    {
        return $this->getGlobalSetting(self::CONFIG_OPTION_TEXT);
    }

    /**
     * Returns our decrypted value if we have one, or false if the value could not be decrypted or is empty.
     * @return bool|string
     */
    public function getEncryptedOption()
    {
        $encryptedValue = $this->getGlobalSetting(self::CONFIG_OPTION_ENCRYPTED);
        return $this->cryptoGen->decryptStandard($encryptedValue);
    }

    public function getGlobalSetting($settingKey)
    {
        return $this->globalsArray[$settingKey] ?? null;
    }

    public function getGlobalSettingSectionConfiguration()
    {
        $settings = [
            self::CONFIG_OPTION_TEXT => [
                'title' => 'Flex HSA/FSA Payments Text Option'
                ,'description' => 'Example global config option with text'
                ,'type' => GlobalSetting::DATA_TYPE_TEXT
                ,'default' => ''
            ]
            ,self::CONFIG_OPTION_ENCRYPTED => [
                'title' => 'Flex HSA/FSA Payments Encrypted Option (Encrypted)'
                ,'description' => 'Example of adding an encrypted global configuration value for your module.  Used for sensitive data'
                ,'type' => GlobalSetting::DATA_TYPE_ENCRYPTED
                ,'default' => ''
            ]
            ,self::CONFIG_OVERRIDE_TEMPLATES => [
                'title' => 'Flex HSA/FSA Payments enable overriding twig files'
                ,'description' => 'Enable module Twig overrides (e.g., portal Flex button)'
                ,'type' => GlobalSetting::DATA_TYPE_BOOL
                ,'default' => '1'  // Default enabled for portal integration
            ]
            ,self::CONFIG_ENABLE_MENU => [
                'title' => 'Flex HSA/FSA Payments add module menu item'
                ,'description' => 'Adds module menu items (requires log out/in)'
                ,'type' => GlobalSetting::DATA_TYPE_BOOL
                ,'default' => '1'  // Default enabled for admin access
            ]
            ,self::CONFIG_ENABLE_BODY_FOOTER => [
                'title' => 'Flex HSA/FSA Payments enable body footer injection'
                ,'description' => 'Injects Flex JS to place buttons across pages'
                ,'type' => GlobalSetting::DATA_TYPE_BOOL
                ,'default' => '1'  // Default enabled for UI integration
            ]
            ,self::CONFIG_ENABLE_FHIR_API => [
                'title' => 'Flex HSA/FSA Payments: Enable example FHIR API'
                ,'description' => 'Example of extending the FHIR API (sample only)'
                ,'type' => GlobalSetting::DATA_TYPE_BOOL
                ,'default' => ''
            ]
            // Flex settings
            ,self::FLEX_ENABLE => [
                'title' => 'Enable Flex Gateway (HSA/FSA)'
                ,'description' => 'Turns on Flex gateway UI and endpoints in this module.'
                ,'type' => GlobalSetting::DATA_TYPE_BOOL
                ,'default' => '1'  // Default enabled - requires API key to function
            ]
            ,self::FLEX_API_BASE_URL => [
                'title' => 'Flex API Base URL'
                ,'description' => 'Base URL for Flex API (e.g., https://api.withflex.com)'
                ,'type' => GlobalSetting::DATA_TYPE_TEXT
                ,'default' => 'https://api.withflex.com'
            ]
            ,self::FLEX_API_KEY_ENCRYPTED => [
                'title' => 'Flex API Key (Encrypted)'
                ,'description' => 'Your Flex API secret key stored encrypted.'
                ,'type' => GlobalSetting::DATA_TYPE_ENCRYPTED
                ,'default' => ''
            ]
            ,self::FLEX_TEST_MODE => [
                'title' => 'Flex Test Mode'
                ,'description' => 'If enabled, marks requests as test mode when supported.'
                ,'type' => GlobalSetting::DATA_TYPE_BOOL
                ,'default' => '1'  // Default to test mode for safety
            ]
            ,self::FLEX_WEBHOOK_SECRET_ENCRYPTED => [
                'title' => 'Flex Webhook Secret (Encrypted)'
                ,'description' => 'Used to verify incoming Flex webhooks.'
                ,'type' => GlobalSetting::DATA_TYPE_ENCRYPTED
                ,'default' => ''
            ]
            ,self::FLEX_WEBHOOK_SIGNATURE_HEADER => [
                'title' => 'Flex Webhook Signature Header'
                ,'description' => 'Header name containing the webhook signature (e.g., Flex-Signature)'
                ,'type' => GlobalSetting::DATA_TYPE_TEXT
                ,'default' => 'Flex-Signature'
            ]
            ,self::FLEX_WEBHOOK_TOLERANCE_SECONDS => [
                'title' => 'Flex Webhook Tolerance Seconds'
                ,'description' => 'Max clock skew in seconds when timestamped signatures are used.'
                ,'type' => GlobalSetting::DATA_TYPE_TEXT
                ,'default' => '300'
            ]
            ,self::FLEX_AUTO_POST_REFUNDS => [
                'title' => 'Auto-post Flex refunds to AR'
                ,'description' => 'When enabled, successful Flex refunds create AR reversal entries automatically (including partial refunds).'
                ,'type' => GlobalSetting::DATA_TYPE_BOOL
                ,'default' => '1'  // Default enabled for automatic reconciliation
            ]
            ,self::FLEX_MOBILE_HMAC_SECRET_ENCRYPTED => [
                'title' => 'Mobile HMAC Secret (Encrypted)'
                ,'description' => 'Shared secret for mobile apps to sign create-checkout requests. Leave blank to disable HMAC.'
                ,'type' => GlobalSetting::DATA_TYPE_ENCRYPTED
                ,'default' => ''
            ]
            ,self::FLEX_ALLOW_MOBILE_CORS => [
                'title' => 'Allow Mobile CORS for create_checkout'
                ,'description' => 'Allows cross-origin POST/OPTIONS for create_checkout endpoint (use with Mobile HMAC).'
                ,'type' => GlobalSetting::DATA_TYPE_BOOL
                ,'default' => ''
            ]
        ];
        return $settings;
    }
}
