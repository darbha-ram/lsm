///////////////////////////////////////////////////////////////////////////////////////////////////
// SingleCurrencyNetter.sol
// Multi-lateral netting implementation for payments over a single currency supply.
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import { INetter } from "./INetter.sol";
import "./Common.sol";


contract SingleCurrencyNetter is INetter {

    // make netAmounts contract storage, in order to pass it by reference to helper
    struct NetAmountByAddr {
        address endpt;
        int     netAmount;
    }
    NetAmountByAddr[] netAmounts;
    Common.PaymentLeg[] nettedPayments;


    function offsetPayments(Common.PaymentLeg[] calldata intentionsToPay, address erc20) external
        returns(Common.PaymentLeg[] memory)
    {
        // clear state prior to running this offsetting pass. Note - cannot move
        // this to local memory data, because push() is only permitted on storage data.
        delete netAmounts;
        delete nettedPayments;

        require(intentionsToPay.length > 0, "Set of raw payments must be non-empty");

        // temp - for now erc20 must be passed in as null. later, if not null, use that to net.
        // if null, iterate over all erc20 to net by each of them, and compose the final answer
        // from those intermediate results.
        require(erc20 == address(0), "Multi-currency netting not supported at this time");

        // temp - assume all payments use same erc20, read it from 1st leg        
        address currToNet = intentionsToPay[0].erc20;

        // run offsetting algorithm
        for (uint ii = 0; ii < intentionsToPay.length; ii++) {
            address fromAddr  = intentionsToPay[ii].from;
            address toAddr    = intentionsToPay[ii].to;
            uint    amount = intentionsToPay[ii].amount;
            
            // update net amounts
            updateNetForEndpt(fromAddr, int(amount) * -1);
            updateNetForEndpt(toAddr, int(amount));
        }

        // ofsetting has completed. generate resulting payments
        for (uint ii = 0; ii < netAmounts.length; ii++) {
            address endpt = netAmounts[ii].endpt;
            int     net   = netAmounts[ii].netAmount;

            if (net == 0) continue;
            if (net < 0) { // endpt is net payer
                nettedPayments.push(Common.newLeg(endpt, address(0), uint(net * -1), currToNet));
            }
            else { // endpt is a net payee
                nettedPayments.push(Common.newLeg(address(0), endpt, uint(net), currToNet));
            }
        }

        console.log("Single currency multi-lateral netting complete");
        return nettedPayments;
    }

    // Given a positive or negative increment value, update net amount for the specified
    // endpt by that increment. A negative value means net amount decreases after update.
    //
    function updateNetForEndpt(address _endpt, int _value) internal {

        for (uint ii = 0; ii < netAmounts.length; ii++) {
            if (netAmounts[ii].endpt == _endpt) {
                // record for endpt exists, update it
                netAmounts[ii].netAmount += _value;
                return;
            }
        }

        // record for endpt doesn't exist, add it
        netAmounts.push(NetAmountByAddr(_endpt, _value));
    }





}

