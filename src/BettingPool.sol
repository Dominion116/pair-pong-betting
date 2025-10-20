// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IPool.sol";

/**
*  @title BettingPool
*  @notice A contract to manage the betting pool for pair pong.
*  @dev This contract will handle the matching algorithm for the users that want to go for and against.
*  @dev if there are no match found, the users bet will be placed against us( we go against the player, if won we pay the user from the vault).
*  @author Pair Pong Team
**/
contract BettingPool is Ownable, ReentrancyGuard {
    //the escense of this contract is to manage the betting pool for the pair pong game.
    //it is meant for single persons bets, not for paired bets.
    //user comes to place a bet on a coin and the money is put into the pool
    //others can come and take the other side of the bet while depositing their money into the pool
    //if no match is found, the bet is placed against the house.
    //wins are paid from the vault or from the users who placed bets on the other side.
    //e.g if a user bets 100 on player A, and another user bets 100 on player B, the pool has 200.
    //if player A wins, the first user gets 200 from the pool.
    //eventually the pool should be topped up from the vault to ensure liquidity.
    //the contract should also keep track of the bets placed and their outcomes.
    //also add a mechanism to prevent users from placing bets on both sides of the same match.
    //and a mechanism to limit the maximum bet amount to prevent large losses.
    //and a mechanism to limit the minimum bet amount to prevent spam bets.
    //and a mechanism to prevent users from withdrawing their bets before the match is over.
    //and a mechanism to prevent users from placing bets after the match has started.
    //and a mechanism to prevent users from placing bets on matches that are not yet scheduled.
    //and a mechanism to prevent users from placing bets on matches that are already over.
    //and a mechanism to prevent users from placing bets on matches that are not valid.
    //and a mechanism to prevent users from placing bets on matches that are not approved by the admin.
    //the match approval shhould be automated via an oracle
    //anyother stuff that comes to mind regarding betting pools.
}