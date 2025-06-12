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
import "./Common.sol";

contract PaymentSystem {

    // prior to netting, intentions to pay - each payer can have multiple
    // intentions to pay multiple payees.
    Common.PaymentLeg[] intentionsToPay;

    // after netting or other optimizations - payments that must be cleared
    // and settled to complete one cycle of operations.
    Common.PaymentLeg[] finalPayments;

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
    function pay(address toAddr, uint amount, address erc20) public returns(bytes32) {
        require(amount > 0);

        Common.PaymentLeg memory leg = Common.newLeg(msg.sender, toAddr, amount, erc20);
        intentionsToPay.push(leg);
        return leg.id;
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

        // look for payment item with specified ID
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
            uint    amount = intentionsToPay[ii].amount;
            
            //
            // TODO - erc20 is ignored at present, assuming all legs are on 1 supply.
            //   This should be updated so that netting is per each erc20 supply!
            //

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

            address dummyErc20 = address(0);
            if (netAmounts[endpt] == 0) continue;
            if (netAmounts[endpt] < 0) { // endpt is net payer
                finalPayments.push(Common.newLeg(endpt, address(0), uint(netAmounts[endpt]), dummyErc20));
            }
            else { // endpt is a net payee
                finalPayments.push(Common.newLeg(address(0), endpt, uint(netAmounts[endpt]), dummyErc20));
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
