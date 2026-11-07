const String defaultApplePay = '''{
  "provider": "apple_pay",
  "data": {
    "merchantIdentifier": "800321394293557994",
    "displayName": "Vitals Payments",
    "merchantCapabilities": ["3DS", "debit", "credit"],
    "supportedNetworks": ["amex", "visa", "discover", "masterCard"],
    "countryCode": "US",
    "currencyCode": "USD",
    "requiredBillingContactFields": ["emailAddress", "name", "phoneNumber", "postalAddress"],
    "requiredShippingContactFields": [],
    "shippingMethods": [
      {
        "amount": "0.00",
        "detail": "Available within an hour",
        "identifier": "in_store_pickup",
        "label": "In-Store Pickup"
      },
      {
        "amount": "4.99",
        "detail": "5-8 Business Days",
        "identifier": "flat_rate_shipping_id_2",
        "label": "UPS Ground"
      },
      {
        "amount": "29.99",
        "detail": "1-3 Business Days",
        "identifier": "flat_rate_shipping_id_1",
        "label": "FedEx Priority Mail"
      }
    ]
  }
}''';

/// Sample configuration for Google Pay. Contains the same content as the file
/// under `assets/default_payment_profile_google_pay.json`.
const String defaultGooglePay = '''{
  "provider": "google_pay",
  "data": {
    "environment": "TEST",
    "apiVersion": 2,
    "apiVersionMinor": 0,
    "allowedPaymentMethods": [
      {
        "type": "CARD",
        "tokenizationSpecification": {
          "type": "PAYMENT_GATEWAY",
          "parameters": {
            "gateway": "stripe",
            "stripe:version": "2020-08-27",
            "stripe:publishableKey": "pk_test_51SQQDt2EyoPbYQj1WAQnGc1HiRX7tY1Qcl4JEJPZPJInKlZkr9b591kyaIZIm7diWo7DZAh2gr1HmvYgfOIIIwzW00hgLyf7Dk"
          }
        },
        "parameters": {
          "allowedCardNetworks": ["VISA", "MASTERCARD"],
          "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
          "billingAddressRequired": true,
          "billingAddressParameters": {
            "format": "FULL",
            "phoneNumberRequired": true
          }
        }
      }
    ],
    "merchantInfo": {
      "merchantId": "800321394293557994",
      "merchantName": "Vitals Payments"
    },
    "transactionInfo": {
      "countryCode": "US",
      "currencyCode": "USD"
    }
  }
}''';

const String basicGooglePayIsReadyToPay = '''{
  "apiVersion": 2,
  "apiVersionMinor": 0,
  "allowedPaymentMethods": [
    {
      "type": "CARD",
      "parameters": {
        "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
        "allowedCardNetworks": ["AMEX", "DISCOVER", "INTERAC", "JCB", "MASTERCARD", "VISA"]
      }
    }
  ]
}''';

const String basicGooglePayLoadPaymentData = '''{
  "apiVersion": 2,
  "apiVersionMinor": 0,
  "merchantInfo": {
    "merchantName": "Vitals Marchent"
  },
  "allowedPaymentMethods": [
    {
      "type": "CARD",
      "parameters": {
        "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
        "allowedCardNetworks": ["MASTERCARD", "VISA"]
        // "allowedCardNetworks": ["AMEX", "DISCOVER", "INTERAC", "JCB", "MASTERCARD", "VISA"]
      },
      "tokenizationSpecification": {
        "type": "PAYMENT_GATEWAY",
        "parameters": {
          "gateway": "example",
          "gatewayMerchantId": "800321394293557994"
        }
      }
    }
  ],
  "transactionInfo": {
    "totalPriceStatus": "FINAL",
    "totalPrice": "12.34",
    "currencyCode": "USD"
  }
}''';

const String invalidGooglePayIsReadyToPay = '''{
  "apiVersion": 2,
  "apiVersionMinor": 0,
  "allowedPaymentMethods": [
    {
      "type": "CARD",
      "parameters": {}
    }
  ]
}''';

const String invalidGooglePayLoadPaymentData = '''{
  "apiVersion": 2,
  "apiVersionMinor": 0,
  "merchantInfo": {
    "merchantName": "Vitals Marchent"
  },
  "allowedPaymentMethods": [
    {
      "type": "CARD",
      "parameters": {
        "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
        "allowedCardNetworks": ["AMEX", "DISCOVER", "INTERAC", "JCB", "MASTERCARD", "VISA"]
      },
      "tokenizationSpecification": {
        "type": "PAYMENT_GATEWAY",
        "parameters": {
          "gateway": "example",
          "gatewayMerchantId": "800321394293557994"
        }
      }
    }
  ],
  "transactionInfo": {
    "totalPriceStatus": "FINAL",
    "totalPrice": "12.34",
    "currencyCode": "USD"
  }
}''';