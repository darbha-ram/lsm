///////////////////////////////////////////////////////////////////////////////////////////////////
// INetter.sol
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Common.sol";

interface INetter {

    // Given an input set of raw payments legs (possible spread over different supplies), compute
    // a set of netted payments over those supplies and return an array of those legs.
    function offsetPayments(Common.PaymentLeg[] memory) external returns(Common.PaymentLeg[] memory);

}

