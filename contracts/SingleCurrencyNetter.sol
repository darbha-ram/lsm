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


    function offsetPayments(Common.PaymentLeg[] calldata intentionsToPay) external
        returns(Common.PaymentLeg[] memory)
    {
        // clear state prior to running this offsetting pass. Note - cannot move
        // this to local memory data, because push() is only permitted on storage data.
        delete netAmounts;
        delete nettedPayments;

        address erc20;

        // run offsetting algorithm
        for (uint ii = 0; ii < intentionsToPay.length; ii++) {
            address fromAddr  = intentionsToPay[ii].from;
            address toAddr    = intentionsToPay[ii].to;
            uint    amount = intentionsToPay[ii].amount;
            
            // store this from any one leg, assumed all legs have same erc20
            erc20 = intentionsToPay[ii].erc20;
            
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
                nettedPayments.push(Common.newLeg(endpt, address(0), uint(net * -1), erc20));
            }
            else { // endpt is a net payee
                nettedPayments.push(Common.newLeg(address(0), endpt, uint(net), erc20));
            }
        }

        console.log("Single currency multi-lateral netting complete");
        return nettedPayments;
    }

    // Given a positive or negative value, update net amount for specified endpt by that value.
    // A negative value means net amount decreases after update.
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

