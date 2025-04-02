// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract APIConsumer is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

  
    bytes32 public donId; 
    uint64 public subscriptionId; 
    uint32 public gasLimit = 300000; 

   
    string public source =
        "const endpoint = args[0] || 'posts';"
        "const id = args[1] || '0';"
        "const apiUrl = `https://jsonplaceholder.typicode.com/${endpoint}`;"
        "const finalUrl = parseInt(id) > 0 ? `${apiUrl}/${id}` : apiUrl;"
        "try {"
        "  const apiResponse = await Functions.makeHttpRequest({ url: finalUrl, method: 'GET' });"
        "  if (!apiResponse || apiResponse.status >= 300) {"
        "    throw new Error(`Request failed with status ${apiResponse?.status}`);"
        "  }"
        "  const responseData = apiResponse.data;"
        "  let processedData;"
        "  if (Array.isArray(responseData)) {"
        "    processedData = responseData.slice(0, 1).map(item => ({ id: item.id, title: item.title?.substring(0, 20) || '' }));"
        "  } else {"
        "    processedData = { id: responseData.id, title: responseData.title?.substring(0, 20) || '' };"
        "  }"
        "  const resultString = JSON.stringify(processedData);"
        "  if (resultString.length > 200) {"
        "    return Functions.encodeString(JSON.stringify({ error: 'Response too large' }));"
        "  }"
        "  return Functions.encodeString(resultString);"
        "} catch (error) {"
        "  return Functions.encodeString(JSON.stringify({ error: 'Request failed', message: error.message.substring(0, 50) }));"
        "}";

    bytes public lastResponse;
    error UnexpectedRequestID(bytes32 requestId);

   
    // event RequestSent(bytes32 indexed requestId);
    event ResponseReceived(bytes32 indexed requestId, bytes response, bytes err);

    constructor(
        address router,
        bytes32 _donId,
        uint64 _subscriptionId
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        donId = _donId;
        subscriptionId = _subscriptionId;
    }

    function requestAPIData(
        string calldata endpoint,
        string calldata id
    ) external onlyOwner returns (bytes32 requestId) {
        string[] memory args = new string[](2);
        args[0] = endpoint;
        args[1] = id;

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); 
        req.setArgs(args); 

        
        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donId
        );
        emit RequestSent(requestId);
        return requestId;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        lastResponse = response;
        emit ResponseReceived(requestId, response, err);
    }

    function decodeResponse() public view returns (string memory) {
        return string(lastResponse);
    }
}