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
import "./HashConverter.sol";

contract PaymentSystem {

    // Multi-lateral netting implementation
    INetter public immutable NETTER;

    // Intentions to pay - each payer can have multiple intentions recorded, including several
    // to same payee of the same amount, as long as they have different timestamps.
    Common.PaymentLeg[] public rawIntentions;

    // Intentions aftey they've been subject to netting. These are 'final' payments that would
    // need to be cleared and settled to complete one cycle of operations.
    Common.PaymentLeg[] public nettedIntentions;

    // store the ID of the last payment intention as contract data, so it can be retrieved after
    // intentToPay() has completed.
    string public lastPid;


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    constructor(address netter) {
        NETTER = INetter(netter);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function intentToPay(address toAddr, uint amount, address erc20) public returns(string memory) {
        require(amount > 0, "amount must be positive value");
        require(toAddr != address(0), "toAddr must be non-zero");
        require(erc20  != address(0), "erc20 addr must be non-zero");

        Common.PaymentLeg memory leg = Common.newLeg(msg.sender, toAddr, amount, erc20);
        rawIntentions.push(leg);

        string memory idStr = HashConverter.toHexString(leg.id);
        //console.log(string.concat("iTP: leg created ", idStr));

        lastPid = idStr;
        return idStr;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function netIntentions() public {

        // invoke netter to do multi-lateral netting
        Common.PaymentLeg[] memory offsetted = NETTER.offsetPayments(rawIntentions);

        // Copying of "Common.PaymentLeg memory[] memory" to storage (by assignment) is not supported,
        // so assign to memory var, then copy each element one by one to storage.
        delete nettedIntentions;
        for (uint ii = 0; ii < offsetted.length; ii++) {
            nettedIntentions.push(offsetted[ii]);
        }

        console.log("PaymentSystem netting pass done, #payments =", nettedIntentions.length);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Ideally shouldn't need this method, if call contract.nettedIntentions.length() works in JS.
    // That doesn't work via Hardhat (tooling dependent?) so use this custom method for now.
    function numNetted() public view returns(uint) {
        return nettedIntentions.length;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function getRawPayment(string memory pidString) public view returns(Common.PaymentLeg memory) {

        bytes memory myBytes = bytes(pidString);
        require(myBytes.length == 66, "input pidString length must be 66!");

        bool found = false;
        uint index = 0;

        // find leg with specified string ID (convert it to binary hash to compare to internal legs)
        for (uint ii = 0; ii < rawIntentions.length; ii++) {
            if (rawIntentions[ii].id == HashConverter.hexStringToBytes32(pidString)) {
                found = true;
                index = ii;
                break;
            }
        }
        if (!found)
            revert(string.concat("Invalid payment ID not found: ", pidString));

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

    function myver() public pure returns(string memory) {
        return "13Aug.1230";
    }



}
