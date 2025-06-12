///////////////////////////////////////////////////////////////////////////////////////////////////
// PaymentSystem.sol
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";
//import { INetter } from "./INetter.sol";

contract PaymentSystem {

    struct Payment {
        uint    id;   // TODO - compute as hash of fields and blocktime, as bytes32
        address from;
        address to;
        uint    amt;
    }

    // prior to netting, intentions to pay - each payer can have multiple
    // intentions to pay multiple payees.
    Payment[] intentionsToPay;

    // after netting or other optimizations - payments that must be cleared
    // and settled to complete one cycle of operations.
    Payment[] finalPayments;

    //
    // netting related data - TODO move into another Netting contract where this
    // state information can be cleaned up and managed before/after netting.
    //

    // unique endpoints encountered during the netting process
    address[] endpoints;

    // net inflow/outflow computed during netting process
    mapping(address => int) netAmounts;


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    constructor() { }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function pay(address toAddr, uint amount) public returns(uint) {
        require(amount > 0);
        uint pindex = intentionsToPay.length; // index of this payment

        intentionsToPay.push(Payment(pindex, msg.sender, toAddr, amount));
        //console.log("Added payment at [%d]: amount %d, %s --> %s",
        //    pindex, amount, msg.sender, toAddr);

        // TODO - return the payment items' unique invariant ID. For now ID is the
        // initial index in the array, is invariant even if item's position in array
        // changes. Make this a hash computed from block timestamp and payment info.
        return pindex;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function getPayment(uint index) public view returns(Payment memory) {
        require(index >= 0);
        require(index < intentionsToPay.length);
        return intentionsToPay[index];
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function deletePayment(uint pid) public returns(bool) {
        bool found = false;
        uint delIndex = 0;

        // look for payment item with specified ID
        for (uint ii = 0; ii < intentionsToPay.length; ii++) {
            if (intentionsToPay[ii].id == pid) {
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

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function doNetting() public {

        clearNetAmounts();
        delete endpoints;
        delete finalPayments;

        // run netting algorithm
        for (uint ii = 0; ii < intentionsToPay.length; ii++) {
            address payer  = intentionsToPay[ii].from;
            address payee  = intentionsToPay[ii].to;
            uint    amount = intentionsToPay[ii].amt;

            // update net amounts
            netAmounts[payer] -= int(amount);
            netAmounts[payee] += int(amount);

            // update list of unique endpoints with payer & payee
            addEndpointIfNotExists(payer);
            addEndpointIfNotExists(payee);
        }

        // netting has completed. generate resulting payments
        for (uint ii = 0; ii < endpoints.length; ii++) {
            address endpt = endpoints[ii];

            if (netAmounts[endpt] == 0) continue;
            if (netAmounts[endpt] < 0) { // endpt is net payer
                finalPayments.push(Payment(finalPayments.length, endpt, address(0), uint(netAmounts[endpt])));
            }
            else { // endpt is a net payee
                finalPayments.push(Payment(finalPayments.length, address(0), endpt, uint(netAmounts[endpt])));
            }
        }

        console.log("Multi-lateral netting complete");
    }

    function addEndpointIfNotExists(address endpt) private {
        bool found = false;
        for (uint ii = 0; ii < endpoints.length; ii++) {
            if (endpoints[ii] == endpt) {
                found = true;
                break;
            }
        }
        if (!found)
            endpoints.push(endpt);
    }

    // important - endpoints[] must be populated for this to work
    function clearNetAmounts() private {
        for (uint ii = 0; ii < endpoints.length; ii++) {
            delete netAmounts[endpoints[ii]];
        }
    }

}
