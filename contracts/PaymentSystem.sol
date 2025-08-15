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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    // Among netted payments, the ones incoming to the PaymentSystem are stored here
    // when they clear, i.e., when funds have transferred from sender to this contract.
    // During a clearing operation, this array serves as a running list of those already
    // cleared, so if #8 of 10 fails, the 7 in this array would need to be reverted.
    Common.PaymentLeg[] public clearedPayments;

    // store the ID of the last raw payment as contract data, so it can be retrieved after
    // addRawPayment() has completed.
    string public lastRawPid;


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    constructor(address netter) {
        NETTER = INetter(netter);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Sender must invoke ERC20.approve(this, amount) prior to calling addRawPayment(). The actual
    // funds transferred will depend on the result of netting, maybe less than 'amount'.
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
    function net() public {

        // invoke netter to do multi-lateral netting
        Common.PaymentLeg[] memory offsetted = NETTER.net(rawPayments);

        // Copying of "Common.PaymentLeg memory[] memory" to storage (by assignment) is not supported,
        // so assign to memory var, then copy each element one by one to storage.
        delete nettedPayments;

        for (uint ii = 0; ii < offsetted.length; ii++) {

            // Every netted payment is incoming (to the payment system) or outgoing. The Netter sets
            // the "system" to be address(0). Find these and replace them with the address of this
            // contract, so that when this payment is actually attempted, money moves from sending
            // parties to this contract, and then from this contract to receiving parties.

            if (offsetted[ii].from == address(0))
                offsetted[ii].from = address(this);
            if (offsetted[ii].to == address(0))
                offsetted[ii].to = address(this);

            nettedPayments.push(offsetted[ii]);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Ideally shouldn't need this method, but calling contract.nettedPayments.length() fails in JS
    // (Hardhat tooling dependent?). So use this custom method for now.
    //
    function numNetted() public view returns(uint) {
        return nettedPayments.length;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function clearAndSettle() public returns(bool) {
        bool retval = clear();
        if (retval)
            retval = settle();

        return retval;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function clear() internal returns(bool) {

        // reset state before starting a clearing pass
        delete clearedPayments;

        // We could iterate over all payments of one ERC20 supply, then move to the next, etc.
        // There may be legal reasons to in a prod system, but for now it is ok to iterate
        // over payments on different ERC20 contracts in an interleaved manner.

        // execute incoming payments one by one, using approval given by senders at the time they
        // invoked addRawPayment().
        bool success = true;
        for (uint ii = 0; ii < nettedPayments.length; ++ii) {

            Common.PaymentLeg memory leg = nettedPayments[ii];
            IERC20 erc20Con = IERC20(leg.erc20);

            if (leg.to != address(this)) { // not an incoming transfer, skip it
                continue;
            }

            // temp
            console.log("Clearing: PaySys", "<--", leg.from, leg.amount);

            // TBD some ERC20 implementations may return false on failure, others may revert.
            // This assumes a false return value. Instead if it reverts, catch and undo earlier ones.
            try erc20Con.transferFrom(leg.from, address(this), leg.amount) {
                // this leg cleared successfully, store it, proceed to next leg
                clearedPayments.push(leg);
            }
            catch (bytes memory) { // revert or other catch-all
                console.log("-- clearing transaction failed! aborting..");
                undoClear();
                success = false;
                break;
            }
        }

        // Could delete clearedPayments at this point, but don't, in case it is needed to
        // investigate what payments were finalized in the ERC20 contract(s).
        // CAUTION! don't delete nettedPayments yet, since outgoing payments in that array
        // must be processed for settlement to complete!
        return success;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function undoClear() internal {

        // Undo the incoming payments already completed, by issuing a bunch of corresponding
        // _outgoing_ payments. They should not fail since the funds were transferred into this
        // contract successfully a short while ago and can be paid out.

        console.log("Reverting previously cleared incoming payments..");

        for (uint ii = 0; ii < clearedPayments.length; ++ii) {
            Common.PaymentLeg memory leg = clearedPayments[ii];

            IERC20 erc20Con = IERC20(leg.erc20);
            try erc20Con.transfer(leg.from, leg.amount) {
                console.log("- Reverted", leg.amount, "back to", leg.from);
            }
            catch (bytes memory lowLevelData) {
                console.log("- Error: revert", string(lowLevelData));
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function settle() internal returns(bool) {

        // We could iterate over all payments of one ERC20 supply, then move to the next, etc.
        // There may be legal reasons to in a prod system, but for now it is ok to iterate
        // over payments on different ERC20 contracts in an interleaved manner.

        // If clearing succeeded, enough funds for settlment are guaranteed.
        // However, could still verify that sufficient funds exist in each ERC20 contract in the
        // balance of the PaymentSystem's address, prior to starting settlement loop below
        // (not implemented for now).

        // make outgoing payments one by one
        bool success = false;
        for (uint ii = 0; ii < nettedPayments.length; ++ii) {

            Common.PaymentLeg memory leg = nettedPayments[ii];
            IERC20 erc20Con = IERC20(leg.erc20);

            if (leg.from != address(this)) { // not an outgoing transfer, skip it
                continue;
            }

            // temp
            console.log("Settling: PaySys -->", leg.to, leg.amount);

            // TBD some ERC20 implementations may return false on failure, others may revert.
            // This assumes a false return value.
            success = erc20Con.transfer(leg.to, leg.amount);
            if (!success) {
                // should never get here, as funds were cleared in performClearing()
                console.log("-- settling transaction failed!? aborting..");
                break;
            }
        }

        if (!success)
        {
            // No way to undo payments that have been paid OUT to other parties
            // earlier in this loop. But we should never get here.
            console.log ("Settlement failed!");
        }
    
        return success;
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
