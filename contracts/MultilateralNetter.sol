///////////////////////////////////////////////////////////////////////////////////////////////////
// MultilateralNetter.sol
// Multi-lateral netting implementation for payments in multiple money supplies.
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import { INetter } from "./INetter.sol";
import "./Common.sol";


contract MultilateralNetter is INetter {

    //
    // Transient netting data - netAmounts, monies
    // Result of netting      - nettedPayments
    //
    // Note: can't move transient data to local memory because push() is only permitted on
    // storage variables. Also, netAmounts must be contract storage in order to pass it by
    // reference to helper.
    //
    // Note: these collections are implemented as arrays rather than mappings, because we'd 
    // like to delete them for each netting run, but Solidity doesn't support delete on a
    // mapping. Arrays require linear search, a bit clunky compared to O(1) hashmap lookup,
    // but acceptable for this proof of concept.
    //
    // Make all contract data public so it can be read via getters for ease of testing.
    //

    struct AmountByEndpt {
        address endpt;
        int     amount;
        address erc20;
    }
    AmountByEndpt[] public netAmounts;

    // result of netting - set of payment legs, each specifying its money supply
    Common.PaymentLeg[] public nettedPayments;

    // set of money supplies in which raw payments are specified
    address[] public monies;


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Do multilateral netting across all monies in payment set
    //
    function performNetting(Common.PaymentLeg[] calldata intentionsToPay) external
        returns(Common.PaymentLeg[] memory)
    {
        // clear state prior to this offsetting pass - since the passes of different monies are
        // disjoint (i.e., their intersection is empty), clearing state once at the beginning is
        // sufficient rather than after a pass of each money.
        delete monies;
        delete netAmounts;
        delete nettedPayments;
        
        require(intentionsToPay.length > 0, "set of raw payments should not be empty");

        // first, find the monies that are represented in the raw payments
        for (uint ii = 0; ii < intentionsToPay.length; ii++) {

            bool found = false;
            for (uint jj = 0; jj < monies.length; ++jj) {
                if (monies[jj] == intentionsToPay[ii].erc20) {
                    found = true;
                    break;
                }
            }
            if (found) continue;

            // erc20 of this payment wasn't found in monies, add it
            monies.push(intentionsToPay[ii].erc20);
        }

        // now, iterate over the monies found, net by each one by one, accumulating result
        for (uint jj = 0; jj < monies.length; ++jj) {
            offsetInMoney(intentionsToPay, monies[jj]);
        }

        // TBD - could delete monies and netAmounts here, but leave around for now
        // as it could be useful to query these to understand actions completed in
        // the most recent netting pass.

        console.log("All multilateral netting done, #payments =", nettedPayments.length);

        return nettedPayments;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function offsetInMoney(Common.PaymentLeg[] calldata intentionsToPay, address money) internal
    {
        require(money != address(0), "money address must be non-zero");

        // run offsetting algorithm for payments in the specified money
        for (uint ii = 0; ii < intentionsToPay.length; ii++) {

            if (intentionsToPay[ii].erc20 != money)
            {
                //console.log("Skipping intention #", ii);
                continue;
            }

            address fromAddr  = intentionsToPay[ii].from;
            address toAddr    = intentionsToPay[ii].to;
            uint    amount    = intentionsToPay[ii].amount;

            // update net amounts
            updateNetForEndpt(fromAddr, int(amount) * -1, money);
            updateNetForEndpt(toAddr, int(amount), money);
        }

        // ofsetting has completed. generate resulting payments
        for (uint ii = 0; ii < netAmounts.length; ii++) {

            if (netAmounts[ii].erc20 != money)
                continue;

            address endpt = netAmounts[ii].endpt;
            int     net   = netAmounts[ii].amount;

            if (net == 0) continue;
            if (net < 0) { // endpt is net payer - pays TO the money contract
                nettedPayments.push(Common.newLeg(endpt, money, uint(net * -1), money));

                // temp
                console.log("Payer -->");
                console.log(endpt);
                console.log(uint(net*-1));
            }
            else { // endpt is a net payee - is paid FROM the money contract
                nettedPayments.push(Common.newLeg(money, endpt, uint(net), money));

                // temp
                console.log("Payee <-- ");
                console.log(endpt);
                console.log(uint(net));
            }
        }

        console.log("Multilateral netting done for money", money);
        // storage var nettedPayments has been updated, nothing to return
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    // Given a positive or negative increment value in a specified money, update net amount for the
    // specified endpt by that increment. A negative value means net amount decreases after update.
    //
    function updateNetForEndpt(address _endpt, int _value, address _erc20) internal {

        for (uint ii = 0; ii < netAmounts.length; ii++) {
            if ((netAmounts[ii].endpt == _endpt) && (netAmounts[ii].erc20 == _erc20)) {
                // record for endpt exists, update it
                netAmounts[ii].amount += _value;
                return;
            }
        }

        // record for endpt doesn't exist, create it
        netAmounts.push(AmountByEndpt(_endpt, _value, _erc20));
    }

    function myver() public pure returns(string memory) {
        return "13Aug.1225";
    }




}

