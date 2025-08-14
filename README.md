# LNURL POS

A Flutter-based Point-of-Sale application for accepting Lightning Network payments via LNURL-pay.

Download the latest Android app release from GitHub:

https://github.com/joschisan/lnurl-pos/releases/tag/latest

## Features

- **LNURL-pay Support**: Scan LNURL codes to generate payment requests
- **Real-time Payment Verification**: Monitor payment status with LUD-21 verify endpoint
- **Simple POS Interface**: Clean, intuitive interface for merchants
- **Lightning Network**: Accept Bitcoin payments instantly over Lightning
- **QR Code Scanning**: Easy invoice generation by scanning merchant LNURL codes
- **Payment Status Tracking**: Real-time updates when payments are received

## Usage

1. Scan or paste an LNURL-pay code from a Lightning service
2. Enter the payment amount in satoshis
3. Display the generated invoice QR code to customers
4. Monitor payment status in real-time

Built with Flutter and Rust for cross-platform compatibility.