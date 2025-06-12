///////////////////////////////////////////////////////////////////////////////////////////////////
// Common.sol
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
//import "hardhat/console.sol";

library Common {
        struct Payment {
        uint    id;   // TODO - compute as hash of fields and blocktime, as bytes32
        address from;
        address to;
        uint    amt;
    }


}

