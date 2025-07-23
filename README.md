# 🌧️ Blockchain Rainfall Insurance for Farmers

A decentralized insurance platform that automatically pays out to farmers when rainfall drops below predefined thresholds. Built on Stacks blockchain using Clarity smart contracts.

## 🌾 Overview

This smart contract enables farmers to purchase rainfall insurance policies that automatically trigger payouts when local rainfall data indicates drought conditions. The system uses oracle-based rainfall data to ensure accurate and tamper-proof measurements.

## ✨ Features

- 📋 **Policy Creation**: Farmers can create customized insurance policies
- 🌧️ **Rainfall Monitoring**: Oracle-based rainfall data recording
- 💰 **Automatic Claims**: Claims processing when rainfall thresholds aren't met
- 🔒 **Secure Payouts**: Automated payouts via smart contract
- ❌ **Policy Cancellation**: Option to cancel policies with partial refunds

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/markyshow03/Blockchain-Rainfall-Insurance-for-Farmers.git
cd Blockchain-Rainfall-Insurance-for-Farmers
```

2. Install dependencies:
```bash
clarinet integrate
```

3. Run tests:
```bash
clarinet test
```

## 📝 Usage

### Creating a Policy

```clarity
(contract-call? .Blockchain-Rainfall-Insurance-for-Farmers create-policy
  u1000000 ;; premium in micro-STX
  u5000000 ;; coverage amount
  u100     ;; rainfall threshold (mm)
  u1000    ;; duration in blocks
  "Farm-Location-A")
```

### Recording Rainfall Data (Oracle Only)

```clarity
(contract-call? .Blockchain-Rainfall-Insurance-for-Farmers record-rainfall
  "Farm-Location-A"
  u202401  ;; period identifier
  u75)     ;; rainfall amount in mm
```

### Filing a Claim

```clarity
(contract-call? .Blockchain-Rainfall-Insurance-for-Farmers file-claim
  u1       ;; policy ID
  u202401) ;; period to check
```

### Processing Claims (Contract Owner Only)

```clarity
(contract-call? .Blockchain-Rainfall-Insurance-for-Farmers process-claim u1)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description | Access |
|----------|-------------|---------|
| `create-policy` | Create new insurance policy | Any user |
| `record-rainfall` | Record rainfall data | Oracle only |
| `file-claim` | Submit insurance claim | Policy holder |
| `process-claim` | Process approved claim | Contract owner |
| `cancel-policy` | Cancel active policy | Policy holder |
| `set-rainfall-oracle` | Update oracle address | Contract owner |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-policy` | Retrieve policy details |
| `get-rainfall-data` | Get rainfall measurements |
| `get-claim` | View claim information |
| `get-contract-balance` | Check contract balance |
| `get-next-policy-id` | Get next available policy ID |
| `get-rainfall-oracle` | Current oracle address |

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Farmers     │    │   Rainfall      │    │   Insurance     │
│                 │───▶│   Oracle        │───▶│   Contract      │
│   (Policy       │    │                 │    │                 │
│    Holders)     │    │  (Data Feed)    │    │  (Automation)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📊 Policy Workflow

1. 🌱 **Policy Creation**: Farmer creates policy with premium payment
2. 📡 **Data Collection**: Oracle records rainfall measurements
3. 📉 **Threshold Check**: System monitors if rainfall meets minimum requirements
4. 🚨 **Claim Filing**: Farmer files claim when conditions are met
5. ✅ **Automatic Payout**: Contract processes and pays valid claims

## 🛡️ Security Features

- Oracle-based data integrity
- Time-locked policy periods
- Multi-signature claim processing
- Automated threshold verification
- Secure fund management

## 🔗 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only access |
| u101 | Not found |
| u102 | Already exists |
| u103 | Insufficient payment |
| u104 | Policy expired |
| u105 | Claim already processed |
| u106 | Threshold not met |
| u107 | Invalid data |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For questions or support, please open an issue on GitHub or contact the development team.

---

*Built with 💙 for farmers worldwide* 🌍
