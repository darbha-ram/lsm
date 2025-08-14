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

    // Raw payments - each payer can have multiple of these recorded, including several
    // to same payee of the same amount, as long as they have different timestamps. These
    // are intentions to pay, prior to netting.
    Common.PaymentLeg[] public rawPayments;

    // After raw payments are netted, they become netted payments. These would need to
    // be cleared and settled to complete one cycle of operations.
    Common.PaymentLeg[] public nettedPayments;

    // store the ID of the last raw payment as contract data, so it can be retrieved after
    // addRawPayment() has completed.
    string public lastRawPid;


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    constructor(address netter) {
        NETTER = INetter(netter);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function addRawPayment(address toAddr, uint amount, address erc20) public returns(string memory) {
        require(amount > 0, "amount must be positive value");
        require(toAddr != address(0), "toAddr must be non-zero");
        require(erc20  != address(0), "erc20 addr must be non-zero");

        Common.PaymentLeg memory leg = Common.newLeg(msg.sender, toAddr, amount, erc20);
        rawPayments.push(leg);

        string memory idStr = HashConverter.toHexString(leg.id);
        //console.log(string.concat("iTP: leg created ", idStr));

        lastRawPid = idStr;
        return idStr;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function performNetting() public {

        // invoke netter to do multi-lateral netting
        Common.PaymentLeg[] memory offsetted = NETTER.performNetting(rawPayments);

        // Copying of "Common.PaymentLeg memory[] memory" to storage (by assignment) is not supported,
        // so assign to memory var, then copy each element one by one to storage.
        delete nettedPayments;
        for (uint ii = 0; ii < offsetted.length; ii++) {
            nettedPayments.push(offsetted[ii]);
        }

        console.log("PaymentSystem netting pass done, #payments =", nettedPayments.length);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Ideally shouldn't need this method, if call contract.nettedPayments.length() works in JS.
    // That doesn't work via Hardhat (tooling dependent?) so use this custom method for now.
    //
    function numNetted() public view returns(uint) {
        return nettedPayments.length;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function getRawPayment(string memory pidString) public view returns(Common.PaymentLeg memory) {

        bytes memory myBytes = bytes(pidString);
        require(myBytes.length == 66, "input pidString length must be 66!");

        bool found = false;
        uint index = 0;

        // find leg with specified string ID (convert it to binary hash to compare to internal legs)
        for (uint ii = 0; ii < rawPayments.length; ii++) {
            if (rawPayments[ii].id == HashConverter.hexStringToBytes32(pidString)) {
                found = true;
                index = ii;
                break;
            }
        }
        if (!found)
            revert(string.concat("Invalid payment ID not found: ", pidString));

        return rawPayments[index];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function deleteRawPayment(string memory pidString) public returns(bool) {
        bool found = false;
        uint delIndex = 0;

        // find leg with specified string ID (convert it to binary hash to compare to internal legs)
        for (uint ii = 0; ii < rawPayments.length; ii++) {
            if (rawPayments[ii].id == HashConverter.hexStringToBytes32(pidString)) {
                found = true;
                delIndex = ii;
                break;
            }
        }

        // delete it and compact the array
        if (found) {
            // copy the last item to index to be deleted, then pop it from the array
            uint lastIndex = rawPayments.length - 1;
            rawPayments[delIndex] = rawPayments[lastIndex];
            rawPayments.pop();
            return true;
        }
        else
            return false;
    }

    function myver() public pure returns(string memory) {
        return "14Aug.1530";
    }



}
