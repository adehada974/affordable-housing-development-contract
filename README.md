# Affordable Housing Development Contract

A comprehensive smart contract system built on the Stacks blockchain using Clarity, designed to facilitate transparent and efficient affordable housing development processes through community engagement and financing coordination.

## 🏠 Project Overview

This project consists of two interconnected smart contracts that address critical challenges in affordable housing development:

### 1. Community Engagement & Needs Assessment
- **Purpose**: Facilitates democratic community participation in housing development decisions
- **Features**: 
  - Resident survey management and data collection
  - Community proposal submission and voting mechanisms
  - Transparent progress tracking and milestone reporting
  - Stakeholder feedback integration

### 2. Development Financing & Subsidy Coordination
- **Purpose**: Manages financial aspects of housing development projects
- **Features**:
  - Subsidy pool management with multi-source funding
  - Low-interest loan coordination and disbursement
  - Investor whitelist and contribution tracking
  - Automated fund scheduling and audit trail

## 🏗️ Architecture

```
├── contracts/
│   ├── community-engagement.clar     # Community participation & voting
│   └── financing-coordination.clar   # Financial management & subsidies
├── tests/
│   ├── community-engagement_test.ts  # Contract tests
│   └── financing-coordination_test.ts
├── settings/
│   ├── Devnet.toml                  # Development network config
│   ├── Testnet.toml                 # Testnet configuration
│   └── Mainnet.toml                 # Mainnet configuration
└── Clarinet.toml                    # Project configuration
```

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) v16+ for testing
- [Git](https://git-scm.com/) for version control

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/adehada974/affordable-housing-development-contract.git
   cd affordable-housing-development-contract
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Verify contract syntax**
   ```bash
   clarinet check
   ```

4. **Run tests**
   ```bash
   npm test
   ```

## 🧪 Development

### Contract Development
- All smart contracts are located in the `contracts/` directory
- Use `.clar` file extensions for Clarity contracts
- Follow Clarity best practices for data types and function definitions

### Testing
- TypeScript tests are located in the `tests/` directory
- Run specific test suites: `npm run test -- community-engagement_test.ts`
- Generate coverage reports: `npm run test:coverage`

### Local Development
```bash
# Start local development environment
clarinet integrate

# Deploy to local devnet
clarinet deploy --devnet

# Check contract syntax
clarinet check

# Run console for interactive testing
clarinet console
```

## 📋 Contract Features

### Community Engagement Contract
- **Survey Management**: Create, manage, and collect community surveys
- **Proposal System**: Submit and vote on housing development proposals
- **Progress Tracking**: Monitor development milestones and community feedback
- **Event Logging**: Transparent record of all community interactions

### Financing Coordination Contract
- **Fund Management**: Handle multiple funding sources and subsidy pools
- **Loan Processing**: Manage low-interest loan applications and approvals
- **Investor Relations**: Whitelist management and contribution tracking
- **Audit Trail**: Complete financial transaction history

## 🔧 Configuration

### Network Settings
- **Devnet**: Local development and testing
- **Testnet**: Public testing environment
- **Mainnet**: Production deployment

### Environment Variables
```bash
# Set your preferred network
export CLARINET_NETWORK=devnet

# Configure deployment settings
export CONTRACT_DEPLOYER=your-address-here
```

## 📚 Documentation

### Smart Contract APIs
- Detailed function documentation available in contract files
- API reference: [docs/api-reference.md](docs/api-reference.md)
- Integration guides: [docs/integration.md](docs/integration.md)

### Example Usage
```javascript
// Example: Submit a community proposal
await contractCall({
  contractAddress: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
  contractName: 'community-engagement',
  functionName: 'submit-proposal',
  functionArgs: [
    stringCV('Housing Development Proposal'),
    stringCV('Detailed description of the proposal'),
    uintCV(100) // Required votes threshold
  ],
});
```

## 🤝 Contributing

We welcome contributions to improve the affordable housing development ecosystem:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines
- Follow Clarity coding standards
- Add comprehensive tests for new features
- Update documentation for any API changes
- Ensure all contracts pass `clarinet check`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🌟 Acknowledgments

- Built with [Clarinet](https://github.com/hirosystems/clarinet) by Hiro
- Powered by the [Stacks](https://www.stacks.co/) blockchain
- Inspired by the need for transparent, community-driven affordable housing solutions

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/adehada974/affordable-housing-development-contract/issues)
- **Discussions**: [GitHub Discussions](https://github.com/adehada974/affordable-housing-development-contract/discussions)
- **Documentation**: [Project Wiki](https://github.com/adehada974/affordable-housing-development-contract/wiki)

---

**Note**: This project is designed for educational and development purposes. Please conduct thorough testing and security audits before deploying to production environments.
