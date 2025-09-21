
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const user1 = accounts.get("wallet_1")!;
const user2 = accounts.get("wallet_2")!;
const user3 = accounts.get("wallet_3")!;

describe("Community Kitchen Collective - Kitchen Scheduling", () => {
  it("ensures simnet is well initialized", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("allows user registration for kitchen collective", () => {
    const registerUser = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("Alice Johnson"),
        Cl.some(Cl.stringAscii("Alice's Artisan Bakery")),
        Cl.stringAscii("alice@example.com"),
        Cl.stringAscii("business")
      ],
      user1
    );
    
    expect(registerUser.result).toBeOk(Cl.uint(1));
  });

  it("allows owner to register new kitchen space", () => {
    const registerKitchen = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-space",
      [
        Cl.stringAscii("Main Commercial Kitchen"),
        Cl.stringAscii("Fully equipped commercial kitchen with gas ranges, ovens, prep tables, and refrigeration"),
        Cl.uint(6),
        Cl.list([
          Cl.stringAscii("Gas Range"),
          Cl.stringAscii("Convection Oven"),
          Cl.stringAscii("Stand Mixer"),
          Cl.stringAscii("Prep Tables"),
          Cl.stringAscii("Refrigerator"),
          Cl.stringAscii("Freezer")
        ])
      ],
      deployer
    );
    
    expect(registerKitchen.result).toBeOk(Cl.uint(1));
  });

  it("prevents duplicate user registration", () => {
    // First registration should succeed
    const firstRegistration = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("Bob Baker"),
        Cl.none(),
        Cl.stringAscii("bob@baker.com"),
        Cl.stringAscii("individual")
      ],
      user2  // Use different user than previous test
    );
    
    expect(firstRegistration.result).toBeOk(Cl.uint(1)); // User ID should be 1 for fresh user
    
    // Second registration with same wallet should fail
    const duplicateRegistration = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("Bob Baker Duplicate"),
        Cl.none(),
        Cl.stringAscii("bob2@baker.com"),
        Cl.stringAscii("individual")
      ],
      user2  // Same user trying to register again
    );
    
    expect(duplicateRegistration.result).toBeErr(Cl.uint(102)); // err-already-exists
  });

  it("prevents non-owner from registering kitchen spaces", () => {
    const unauthorizedKitchen = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-space",
      [
        Cl.stringAscii("Unauthorized Kitchen"),
        Cl.stringAscii("This should fail"),
        Cl.uint(4),
        Cl.list([Cl.stringAscii("Basic Equipment")])
      ],
      user2 // Not the owner
    );
    
    expect(unauthorizedKitchen.result).toBeErr(Cl.uint(100)); // err-owner-only
  });

  it("validates membership types during registration", () => {
    const invalidMembership = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("Invalid User"),
        Cl.none(),
        Cl.stringAscii("invalid@example.com"),
        Cl.stringAscii("invalid-type") // Should be individual, business, or community
      ],
      user3  // Use fresh user to avoid conflicts
    );
    
    expect(invalidMembership.result).toBeErr(Cl.uint(103)); // err-invalid-time (reused for validation)
  });

  it("can query user information", () => {
    // Register a new user first
    const registerResult = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("Carol Chef"),
        Cl.some(Cl.stringAscii("Carol's Catering")),
        Cl.stringAscii("carol@catering.com"),
        Cl.stringAscii("business")
      ],
      user3  // Use user3 since user2 is already registered in previous test
    );
    
    expect(registerResult.result).toBeOk(Cl.uint(1));
    
    // Query the user information
    const userInfo = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-user-info",
      [Cl.principal(user3)],
      deployer
    );
    
    // Verify we got a result that contains user data
    expect(userInfo.result).toBeDefined();
    expect(userInfo.result.type).toBe("some");
  });

  it("can query kitchen space information", () => {
    // Register a kitchen space first
    const registerResult = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-space",
      [
        Cl.stringAscii("Demo Kitchen"),
        Cl.stringAscii("Kitchen for testing and demos"),
        Cl.uint(2),
        Cl.list([Cl.stringAscii("Basic Equipment")])
      ],
      deployer
    );
    
    expect(registerResult.result).toBeOk(Cl.uint(1)); // First kitchen gets ID 1
    
    // Query the kitchen information
    const kitchenInfo = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-kitchen-space",
      [Cl.uint(1)], // Query the kitchen we just registered
      deployer
    );
    
    // Verify we got a result that contains kitchen data
    expect(kitchenInfo.result).toBeDefined();
    expect(kitchenInfo.result.type).toBe("some");
  });

  it("can query scheduling statistics", () => {
    const stats = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-scheduling-stats",
      [],
      deployer
    );
    
    // Just verify the stats result is returned as a tuple
    expect(stats.result.type).toBe("tuple");
    expect(stats.result.value).toBeDefined();
    // Check that it contains expected fields
    expect(stats.result.value).toHaveProperty('hourly-rate');
    expect(stats.result.value).toHaveProperty('max-booking-hours');
    expect(stats.result.value).toHaveProperty('cancellation-window');
  });

  it("can check kitchen availability", () => {
    const hourSlot = 1000; // Some future hour slot
    const kitchenId = 1;
    
    const availability = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-kitchen-availability",
      [Cl.uint(kitchenId), Cl.uint(hourSlot)],
      deployer
    );
    
    // Should return none for uninitialized availability slot
    expect(availability.result).toBeNone();
  });

  it("can check for booking conflicts", () => {
    const kitchenId = 1;
    const startTime = 3600000; // Some future timestamp
    const endTime = 7200000; // 1 hour later
    
    const conflicts = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "check-booking-conflicts",
      [Cl.uint(kitchenId), Cl.uint(startTime), Cl.uint(endTime)],
      deployer
    );
    
    // Just verify the conflicts result is returned as a tuple
    expect(conflicts.result.type).toBe("tuple");
    expect(conflicts.result.value).toBeDefined();
    // Check that it contains expected fields
    expect(conflicts.result.value).toHaveProperty('conflicts');
    expect(conflicts.result.value).toHaveProperty('current-bookings');
    expect(conflicts.result.value).toHaveProperty('max-capacity');
    expect(conflicts.result.value).toHaveProperty('available');
  });

  it("validates kitchen capacity during registration", () => {
    const zeroCapacityKitchen = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-space",
      [
        Cl.stringAscii("Invalid Kitchen"),
        Cl.stringAscii("Kitchen with zero capacity"),
        Cl.uint(0), // Invalid capacity
        Cl.list([Cl.stringAscii("Equipment")])
      ],
      deployer
    );
    
    expect(zeroCapacityKitchen.result).toBeErr(Cl.uint(103)); // err-invalid-time
  });

  it("can retrieve kitchen user by user ID", () => {
    // Register a user first
    const registerResult = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("David Dough"),
        Cl.none(),
        Cl.stringAscii("david@dough.com"),
        Cl.stringAscii("individual")
      ],
accounts.get("wallet_7")! // Use valid wallet
    );
    
    expect(registerResult.result).toBeOk(Cl.uint(1));
    
    // Query user by ID
    const userInfo = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-kitchen-user",
      [Cl.uint(1)],
      deployer
    );
    
    // Verify we got a result that contains user data
    expect(userInfo.result).toBeDefined();
    expect(userInfo.result.type).toBe("some");
  });

  it("returns none for non-existent kitchen user", () => {
    const userInfo = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-kitchen-user",
      [Cl.uint(999)], // Non-existent user ID
      deployer
    );
    
    expect(userInfo.result).toBeNone();
  });

  it("returns none for non-existent kitchen space", () => {
    const kitchenInfo = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-kitchen-space",
      [Cl.uint(999)], // Non-existent kitchen ID
      deployer
    );
    
    expect(kitchenInfo.result).toBeNone();
  });

  it("returns none for non-existent booking", () => {
    const bookingInfo = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-booking",
      [Cl.uint(999)], // Non-existent booking ID
      deployer
    );
    
    expect(bookingInfo.result).toBeNone();
  });

  it("returns none for non-existent payment record", () => {
    const paymentInfo = simnet.callReadOnlyFn(
      "kitchen-scheduling",
      "get-payment-record",
      [Cl.uint(999)], // Non-existent payment ID
      deployer
    );
    
    expect(paymentInfo.result).toBeNone();
  });

  it("handles valid membership types correctly", () => {
    const individualMember = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("Individual User"),
        Cl.none(),
        Cl.stringAscii("individual@test.com"),
        Cl.stringAscii("individual")
      ],
      accounts.get("wallet_4")!
    );
    
    const businessMember = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("Business User"),
        Cl.some(Cl.stringAscii("Test Business")),
        Cl.stringAscii("business@test.com"),
        Cl.stringAscii("business")
      ],
      accounts.get("wallet_5")!
    );
    
    const communityMember = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-user",
      [
        Cl.stringAscii("Community User"),
        Cl.none(),
        Cl.stringAscii("community@test.com"),
        Cl.stringAscii("community")
      ],
      accounts.get("wallet_6")!
    );
    
    expect(individualMember.result).toBeOk(Cl.uint(1));
    expect(businessMember.result).toBeOk(Cl.uint(2));
    expect(communityMember.result).toBeOk(Cl.uint(3));
  });

  it("multiple kitchen spaces can be registered", () => {
    const kitchen1 = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-space",
      [
        Cl.stringAscii("Baking Kitchen"),
        Cl.stringAscii("Specialized for baking operations"),
        Cl.uint(4),
        Cl.list([Cl.stringAscii("Oven"), Cl.stringAscii("Mixer")])
      ],
      deployer
    );
    
    const kitchen2 = simnet.callPublicFn(
      "kitchen-scheduling",
      "register-kitchen-space",
      [
        Cl.stringAscii("Prep Kitchen"),
        Cl.stringAscii("For food preparation"),
        Cl.uint(6),
        Cl.list([Cl.stringAscii("Prep Tables"), Cl.stringAscii("Knives")])
      ],
      deployer
    );
    
    expect(kitchen1.result).toBeOk(Cl.uint(1));
    expect(kitchen2.result).toBeOk(Cl.uint(2));
  });
});
