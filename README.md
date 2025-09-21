# Community Kitchen Collective - Kitchen Scheduling Platform

A decentralized smart contract platform for managing shared commercial kitchen spaces using Stacks blockchain technology. This platform enables community-based kitchen sharing, booking management, and payment processing for food entrepreneurs, small businesses, and community organizations.

## Project Overview

The Community Kitchen Collective addresses the challenge of accessing affordable commercial kitchen space for food entrepreneurs and small businesses. By leveraging blockchain technology, the platform provides:

- **Decentralized Kitchen Management**: Community-owned and operated kitchen spaces
- **Transparent Booking System**: Fair and transparent scheduling with conflict resolution
- **Automated Payment Processing**: Secure payments using STX tokens
- **Access Control**: Digital access codes for secure kitchen entry
- **Community Governance**: Democratic decision-making for kitchen rules and policies

## Features

### ✅ Core Functionality (Implemented)

- **User Registration & Management**
  - Support for individual, business, and community memberships
  - User profiles with contact information and business details
  - Food handler certification tracking
  - Compliance scoring system

- **Kitchen Space Management**
  - Multiple kitchen space registration
  - Equipment inventory tracking
  - Capacity management
  - Maintenance mode controls

- **Booking System**
  - Time slot reservation with conflict detection
  - Flexible booking duration (up to 12 hours)
  - Purpose and special requirements tracking
  - Cancellation window management (24 hours default)

- **Payment Processing Framework**
  - STX-based payment system
  - Outstanding balance tracking
  - Refund processing capabilities
  - Payment record management

- **Access Control**
  - Unique access code generation
  - Check-in/check-out functionality
  - Session time tracking
  - Usage statistics

- **Query & Analytics**
  - User information retrieval
  - Kitchen space details
  - Booking history and status
  - Utilization statistics
  - Payment records

### 🔄 Future Enhancements

- **Advanced Payment Integration**
  - Complete STX payment processing
  - Multi-token support
  - Membership subscription models
  - Revenue sharing mechanisms

- **Governance Features**
  - Community voting on kitchen rules
  - Democratic space management
  - Dispute resolution system

- **Advanced Scheduling**
  - Recurring bookings
  - Priority booking for members
  - Waitlist management
  - Calendar integration

- **Integration & APIs**
  - Web application interface
  - Mobile app support
  - IoT device integration
  - Third-party calendar sync

## Technical Architecture

### Smart Contract Structure

```
kitchen-scheduling.clar
├── Constants & Error Codes
├── Data Variables (IDs, rates, limits)
├── Data Maps
│   ├── kitchen-users (user management)
│   ├── kitchen-spaces (facility management)
│   ├── bookings (reservation system)
│   ├── kitchen-availability (scheduling)
│   └── payment-records (financial tracking)
├── Public Functions
│   ├── register-kitchen-user
│   ├── register-kitchen-space
│   ├── book-kitchen-slot
│   ├── process-booking-payment
│   ├── check-in-to-kitchen
│   ├── check-out-from-kitchen
│   └── cancel-booking
├── Private Helper Functions
└── Read-only Functions
```

### Data Models

**User Model:**
- Principal address mapping
- Personal/business information
- Membership type and status
- Certification and compliance tracking
- Usage statistics and balances

**Kitchen Space Model:**
- Facility details and capacity
- Equipment inventory
- Operational status and maintenance
- Usage statistics

**Booking Model:**
- Time slot reservations
- User and kitchen associations
- Payment and access information
- Session tracking

**Payment Model:**
- Transaction records
- Refund processing
- Balance management

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v18 or later)
- [Clarinet](https://docs.hiro.so/stacks/clarinet) CLI tool
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd community-kitchen-collective
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Verify setup:**
   ```bash
   clarinet check
   ```

### Development Workflow

1. **Run contract validation:**
   ```bash
   clarinet check
   ```

2. **Execute tests:**
   ```bash
   npm test
   ```

3. **Start development console:**
   ```bash
   clarinet console
   ```

4. **Deploy to testnet:**
   ```bash
   clarinet deploy --testnet
   ```

## Usage Examples

### Register as a Kitchen User

```clarity
(contract-call? .kitchen-scheduling register-kitchen-user
  "Alice's Bakery"
  (some "Alice's Artisan Breads")
  "alice@artisanbreads.com"
  "business")
```

### Register a Kitchen Space (Owner Only)

```clarity
(contract-call? .kitchen-scheduling register-kitchen-space
  "Commercial Baking Kitchen"
  "Fully equipped for baking operations with ovens, mixers, and prep space"
  u6
  (list "Gas Range" "Convection Oven" "Stand Mixer" "Prep Tables"))
```

### Book a Kitchen Time Slot

```clarity
(contract-call? .kitchen-scheduling book-kitchen-slot
  u1                              ;; kitchen-id
  u1640995200                     ;; start-time (Unix timestamp)
  u1640998800                     ;; end-time (Unix timestamp)
  "Morning bread production"
  (some "Need access to freezer space"))
```

### Query User Information

```clarity
(contract-call? .kitchen-scheduling get-user-info tx-sender)
```

## Testing

The project includes comprehensive test coverage with 19 test cases covering:

- User registration and validation
- Kitchen space management
- Booking system functionality
- Access control and permissions
- Data integrity and edge cases
- Error handling and validation

**Run the test suite:**
```bash
npm test
```

**Test Categories:**
- ✅ User registration and management (6 tests)
- ✅ Kitchen space operations (4 tests)
- ✅ Data queries and validation (5 tests)
- ✅ Access control and permissions (2 tests)
- ✅ Edge cases and error handling (2 tests)

## Configuration

### Contract Parameters

- **Hourly Rate:** 0.05 STX (50,000,000 μSTX)
- **Maximum Booking Duration:** 12 hours
- **Cancellation Window:** 24 hours (86,400 seconds)
- **Default Kitchen Capacity:** 4 users

### Supported Membership Types

- `"individual"` - Individual users and entrepreneurs
- `"business"` - Registered businesses and companies
- `"community"` - Community organizations and non-profits

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `err-owner-only` | Function requires contract owner privileges |
| 101 | `err-not-found` | Requested resource does not exist |
| 102 | `err-already-exists` | Resource already exists (e.g., duplicate registration) |
| 103 | `err-invalid-time` | Invalid time parameters or validation failure |
| 104 | `err-time-conflict` | Booking time conflicts with existing reservations |
| 105 | `err-unauthorized` | User lacks required permissions or certification |
| 106 | `err-booking-expired` | Booking time window has expired |
| 107 | `err-insufficient-payment` | Payment amount is insufficient |
| 108 | `err-cancellation-too-late` | Cancellation requested outside allowed window |

## Contributing

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/amazing-feature`
3. **Make your changes and add tests**
4. **Ensure all tests pass:** `npm test && clarinet check`
5. **Commit your changes:** `git commit -m 'Add amazing feature'`
6. **Push to the branch:** `git push origin feature/amazing-feature`
7. **Open a Pull Request**

### Development Guidelines

- Write comprehensive tests for new functionality
- Follow Clarity best practices and conventions
- Update documentation for API changes
- Ensure backward compatibility when possible
- Use descriptive commit messages

## Security Considerations

- **Input Validation:** All user inputs are validated for type and constraints
- **Access Control:** Function-level permissions enforce business rules
- **Data Integrity:** Consistent state management across operations
- **Time Safety:** Timestamp validation prevents past bookings
- **Payment Security:** Proper balance tracking and payment validation

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Roadmap

### Phase 1: Core Platform (Current)
- ✅ Basic user and kitchen management
- ✅ Booking system with conflict detection
- ✅ Payment framework
- ✅ Access control system

### Phase 2: Enhanced Features
- 🔄 Complete payment integration
- 🔄 Advanced scheduling features
- 🔄 Community governance tools
- 🔄 Mobile app interface

### Phase 3: Platform Growth
- 🔄 Multi-kitchen network support
- 🔄 Integration partnerships
- 🔄 Advanced analytics and reporting
- 🔄 Franchise and licensing model

## Contact & Support

For questions, support, or contributions:

- **Documentation:** [Project Wiki](#)
- **Issues:** [GitHub Issues](#)
- **Community:** [Discord Server](#)
- **Email:** [support@kitchencollective.com](#)

---

**Built with ❤️ for the food entrepreneur community using Stacks blockchain technology.**