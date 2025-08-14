///////////////////////////////////////////////////////////////////////////////////////////////////
// INetter.sol
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Common.sol";

interface INetter {

    // Given an input set of raw payments legs, possibly spread over different money supplies,
    // compute a set of netted payments over all monies, and return an array of payments.
    //
    // Note: return value must be declared as memory, and a dynamically sized return value as below
    // must be returned _from_ memory by an implementation. The input arg is declared as calldata,
    // so is read-only and avoids copying.
    function performNetting(Common.PaymentLeg[] calldata) external returns(Common.PaymentLeg[] memory);

}

