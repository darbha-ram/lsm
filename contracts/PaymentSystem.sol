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
    // this contract should only use a Netter that handles many supplies.
    INetter public immutable SINGLENTR;
    INetter public immutable MANYNTR;

    // intentions to pay - each payer can have multiple intentions recorded, including several
    // to same payee of the same amount.
    Common.PaymentLeg[] rawIntentions;

    // payment intentions aftey they've been subject to netting. these must be cleared
    // and settled to complete one cycle of operations.
    Common.PaymentLeg[] nettedIntentions;


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
        rawIntentions.push(leg);
        return leg.id;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function netIntentions() public {

        // Use Netter of choice to do offsetting
        Common.PaymentLeg[] memory offsetted = SINGLENTR.offsetPayments(rawIntentions);

        // Copying of "Common.PaymentLeg memory[] memory" to storage (by assignment) is not supported,
        // so assign to memory var, then copy each element one by one to storage.
        delete nettedIntentions;
        for (uint ii = 0; ii < offsetted.length; ii++) {
            nettedIntentions.push(offsetted[ii]);
        }

    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function getPayment(uint index) public view returns(Common.PaymentLeg memory) {
        require(index >= 0);
        require(index < rawIntentions.length);
        return rawIntentions[index];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function deletePayment(string memory pidString) public returns(bool) {
        bool found = false;
        uint delIndex = 0;

        // find leg with specified string ID (convert it to binary hash to compare to internal legs)
        for (uint ii = 0; ii < rawIntentions.length; ii++) {
            if (rawIntentions[ii].id == HashConverter.hexStringToBytes32(pidString)) {
                found = true;
                delIndex = ii;
                break;
            }
        }

        // delete it and compact the array
        if (found) {
            // copy the last item to index to be deleted, then pop it from the array
            uint lastIndex = rawIntentions.length - 1;
            rawIntentions[delIndex] = rawIntentions[lastIndex];
            rawIntentions.pop();
            return true;
        }
        else
            return false;
    }


}
