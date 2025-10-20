// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/operatorforwarder/Operator.sol";

/**
 * @title Oracle Contract
 * @author Pair Pong Team
 * @notice This contract serves as a custom Chainlink Operator to facilitate secure and efficient communication between the Pair Pong betting platform and Chainlink oracles.
 * @dev Inherits from Chainlink's Operator contract to leverage built-in functionalities for request forwarding
**/

contract MyOperator is Operator{
    constructor(address _link) Operator(_link, msg.sender) {}
}