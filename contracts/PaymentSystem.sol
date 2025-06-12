///////////////////////////////////////////////////////////////////////////////////////////////////
// PaymentSystem.sol
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import { INetter } from "./INetter.sol";
import "./Common.sol";

contract PaymentSystem {

    // Netting implementations for a single currency supply, and multiple supplies. Eventually
    // this contract should only use the mu
    INetter public immutable SINGLENTR;
    INetter public immutable MANYNTR;

    // prior to netting, intentions to pay - each payer can have multiple
    // intentions to pay multiple payees.
    Common.PaymentLeg[] intentionsToPay;

    // after netting or other optimizations - payments that must be cleared
    // and settled to complete one cycle of operations.
    Common.PaymentLeg[] finalPayments;


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    constructor(address singleNetter, address manyNetter) {
        SINGLENTR  = INetter(singleNetter);
        MANYNTR    = INetter(manyNetter);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function intentToPay(address toAddr, uint amount, address erc20) public returns(bytes32) {
        require(amount > 0);

        Common.PaymentLeg memory leg = Common.newLeg(msg.sender, toAddr, amount, erc20);
        intentionsToPay.push(leg);
        return leg.id;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function netIntentions() public {

    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function getPayment(uint index) public view returns(Common.PaymentLeg memory) {
        require(index >= 0);
        require(index < intentionsToPay.length);
        return intentionsToPay[index];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function deletePayment(string memory pidString) public returns(bool) {
        bool found = false;
        uint delIndex = 0;

        // find leg with specified string ID (convert it to binary hash to compare to internal legs)
        for (uint ii = 0; ii < intentionsToPay.length; ii++) {
            if (intentionsToPay[ii].id == HashConverter.hexStringToBytes32(pidString)) {
                found = true;
                delIndex = ii;
                break;
            }
        }

        // delete it and compact the array
        if (found) {
            // copy the last item to index to be deleted, then pop it from the array
            uint lastIndex = intentionsToPay.length - 1;
            intentionsToPay[delIndex] = intentionsToPay[lastIndex];
            intentionsToPay.pop();
            return true;
        }
        else
            return false;
    }


}
