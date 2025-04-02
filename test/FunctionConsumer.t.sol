// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import "forge-std/Function.sol";
import "../src/FunctionConsumer.sol";
import {FunctionsRouter} from "@chainlink/functions/v1_0_0/FunctionsRouter.sol";

contract MockFunctionsRouter is FunctionsRouter {
    bytes32 public lastRequestId;
    bytes public lastRequestCBOR;
    uint64 public lastSubscriptionId;
    uint32 public lastGasLimit;
    bytes32 public lastDonId;
    
    constructor() FunctionsRouter(address(0)) {}
    
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
    
    function simulateFulfillment(
        bytes32 requestId,
        address consumer,
        bytes memory response,
        bytes memory err
    ) external {
        APIConsumer(consumer).handleOracleFulfillment(requestId, response, err);
    }
}

contract APIConsumerTest is Test {
    MockFunctionsRouter public mockRouter;
    APIConsumer public apiConsumer;
    
    bytes32 public constant DON_ID = keccak256("test-don-id");
    uint64 public constant SUBSCRIPTION_ID = 12345;
    
    event RequestSent(bytes32 indexed requestId);
    event ResponseReceived(bytes32 indexed requestId, bytes response, bytes err);
    
    function setUp() public {
        mockRouter = new MockFunctionsRouter();
        apiConsumer = new APIConsumer(
            address(mockRouter),
            DON_ID,
            SUBSCRIPTION_ID
        );
    }
    
    function testInitialization() public {
        assertEq(apiConsumer.donId(), DON_ID);
        assertEq(apiConsumer.subscriptionId(), SUBSCRIPTION_ID);
        assertEq(apiConsumer.gasLimit(), 300000);
        assertEq(apiConsumer.owner(), address(this));
    }
    
    function testRequestAPIData() public {
        string memory endpoint = "posts";
        string memory id = "1";
        
        vm.expectEmit(true, false, false, false);
        emit RequestSent(bytes32(0));
        
        bytes32 requestId = apiConsumer.requestAPIData(endpoint, id);
        
        assertEq(mockRouter.lastSubscriptionId(), SUBSCRIPTION_ID);
        assertEq(mockRouter.lastGasLimit(), 300000);
        assertEq(mockRouter.lastDonId(), DON_ID);
        assertTrue(mockRouter.lastRequestCBOR().length > 0);
    }
    
    function testFulfillRequest() public {
       
        string memory endpoint = "posts";
        string memory id = "1";
        bytes32 requestId = apiConsumer.requestAPIData(endpoint, id);

        bytes memory mockResponse = bytes('{"id":1,"title":"Test Post Title"}');
        bytes memory emptyError = "";

        vm.expectEmit(true, true, true, true);
        emit ResponseReceived(requestId, mockResponse, emptyError);
        
        mockRouter.simulateFulfillment(requestId, address(apiConsumer), mockResponse, emptyError);
        
        assertEq(apiConsumer.lastResponse(), mockResponse);
        
        string memory decodedResponse = apiConsumer.decodeResponse();
        assertEq(decodedResponse, '{"id":1,"title":"Test Post Title"}');
    }
   
}