// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract JSONPlaceholderConsumer is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    // Chainlink Configuration
    bytes32 public donId;
    uint64 public subscriptionId;
    uint32 public gasLimit = 300000;

    // API Response Storage
    bytes public lastResponse;
    string public lastUserName; 

    // Custom Errors
    error EmptyUserId();
    error RequestFailed(bytes err);

    // Events
    event RequestSent(bytes32 indexed requestId, string userId);
    event ResponseReceived(
        bytes32 indexed requestId, 
        string userName,
        bytes response,
        bytes err
    );

    string source =
        "const userId = args[0];" // No default - we validate in Solidity
        "const response = await Functions.makeHttpRequest({"
        "  url: `https://jsonplaceholder.typicode.com/users/${userId}`"
        "});"
        "if (response.error) {"
        "  throw Error('API request failed');"
        "}"
        "return Functions.encodeString(response.data.name);";

    constructor(
        address router,
        bytes32 _donId,
        uint64 _subscriptionId
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        donId = _donId;
        subscriptionId = _subscriptionId;
    }

    /**
     * @notice Fetches user data from JSONPlaceholder API
     * @param userId The user ID to fetch (1-10 for test data)
     */
    function fetchUserData(
        string calldata userId
    ) external onlyOwner returns (bytes32 requestId) {
        if (bytes(userId).length == 0) revert EmptyUserId();

        string[] memory args = new string[](1);
        args[0] = userId;

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        req.setArgs(args);

        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donId
        );

        emit RequestSent(requestId, userId);
        return requestId;
    }

    /**
     * @notice Chainlink callback with API response
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        lastResponse = response;
        
        if (err.length > 0) {
            revert RequestFailed(err);
        }
        
        lastUserName = string(response);
        emit ResponseReceived(requestId, lastUserName, response, err);
    }

    function updateChainlinkConfig(
        uint64 newSubscriptionId,
        uint32 newGasLimit,
        bytes32 newDonId
    ) external onlyOwner {
        subscriptionId = newSubscriptionId;
        gasLimit = newGasLimit;
        donId = newDonId;
    }
}