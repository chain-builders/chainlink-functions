// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {JSONPlaceholderConsumer} from "../src/FunctionConsumer.sol";

contract MockFunctionsRouter {

    bytes32 public lastRequestId;
    bytes public lastRequestCBOR;
    uint64 public lastSubscriptionId;
    uint32 public lastGasLimit;
    bytes32 public lastDonId;

    function sendRequest(
        uint64 subscriptionId,
        bytes calldata requestCBOR,
        uint32 gasLimit,
        bytes32 donId
    ) external returns (bytes32) {
        lastRequestId = keccak256(abi.encodePacked(subscriptionId, requestCBOR, block.timestamp));
        lastRequestCBOR = requestCBOR;
        lastSubscriptionId = subscriptionId;
        lastGasLimit = gasLimit;
        lastDonId = donId;
        return lastRequestId;
    }
}

contract JSONPlaceholderConsumerTest is Test {
    MockFunctionsRouter public mockRouter;
    JSONPlaceholderConsumer public consumer;
    
    bytes32 public constant DON_ID = keccak256("test-don");
    uint64 public constant SUBSCRIPTION_ID = 1;
    uint32 public constant GAS_LIMIT = 300000;

    event RequestSent(bytes32 indexed requestId, string userId);
    event ResponseReceived(
        bytes32 indexed requestId,
        string userName,
        bytes response,
        bytes err
    );

    function setUp() public {
        mockRouter = new MockFunctionsRouter();
        consumer = new JSONPlaceholderConsumer(
            address(mockRouter),
            DON_ID,
            SUBSCRIPTION_ID
        );
    }

    // Test initialization
    function testInitialization() public {
        assertEq(consumer.donId(), DON_ID);
        assertEq(consumer.subscriptionId(), SUBSCRIPTION_ID);
        assertEq(consumer.gasLimit(), GAS_LIMIT);
        assertEq(consumer.owner(), address(this));
    }

    // Test successful request flow
    function testFetchUserData() public {
        string memory userId = "1";
        
        vm.expectEmit(true, false, false, false);
        emit RequestSent(bytes32(0), userId);
        
        bytes32 requestId = consumer.fetchUserData(userId);
        
        // Verify request parameters
        assertEq(mockRouter.lastSubscriptionId(), SUBSCRIPTION_ID);
        assertEq(mockRouter.lastGasLimit(), GAS_LIMIT);
        assertEq(mockRouter.lastDonId(), DON_ID);
        assertTrue(mockRouter.lastRequestCBOR().length > 0);
    }

    // Test successful fulfillment
    function testSuccessfulFulfillment() public {
        string memory userId = "1";
        bytes32 requestId = consumer.fetchUserData(userId);

        bytes memory mockResponse = bytes("Leanne Graham"); // Expected name from API
        bytes memory emptyErr;
        
        vm.expectEmit(true, true, true, true);
        emit ResponseReceived(requestId, string(mockResponse), mockResponse, emptyErr);
        
      
        vm.prank(address(mockRouter));
        
       
        assertEq(consumer.lastResponse(), mockResponse);
        assertEq(consumer.lastUserName(), "Leanne Graham");
    }

    // Test failed fulfillment
    function testFailedFulfillment() public {
        string memory userId = "1";
        bytes32 requestId = consumer.fetchUserData(userId);

        bytes memory mockErr = bytes("API Error");
        bytes memory emptyResponse;
        
       
        vm.expectRevert(
            abi.encodeWithSelector(
                JSONPlaceholderConsumer.RequestFailed.selector,
                mockErr
            )
        );
        
        vm.prank(address(mockRouter));
    }

    // Test empty user ID reverts
    function testEmptyUserIdReverts() public {
        vm.expectRevert(JSONPlaceholderConsumer.EmptyUserId.selector);
        consumer.fetchUserData("");
    }

    // Test config updates
    function testUpdateConfig() public {
        uint64 newSubId = 999;
        uint32 newGasLimit = 400000;
        bytes32 newDonId = keccak256("new-don");
        
        consumer.updateChainlinkConfig(newSubId, newGasLimit, newDonId);
        
        assertEq(consumer.subscriptionId(), newSubId);
        assertEq(consumer.gasLimit(), newGasLimit);
        assertEq(consumer.donId(), newDonId);
    }

    // Test onlyOwner restrictions
    function testOnlyOwnerRestrictions() public {
        address attacker = makeAddr("attacker");
        
        // Test fetchUserData
        vm.prank(attacker);
        vm.expectRevert("Only callable by owner");
        consumer.fetchUserData("1");
        
        // Test updateConfig
        vm.prank(attacker);
        vm.expectRevert("Only callable by owner");
        consumer.updateChainlinkConfig(1, 1, bytes32(0));
    }
}