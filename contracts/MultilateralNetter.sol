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
    function net(Common.PaymentLeg[] calldata rawPayments) external
        returns(Common.PaymentLeg[] memory)
    {
        // clear state prior to this offsetting pass - since the passes of different monies are
        // disjoint (i.e., their intersection is empty), clearing state once at the beginning is
        // sufficient rather than after a pass of each money.
        delete monies;
        delete netAmounts;
        delete nettedPayments;
        
        require(rawPayments.length > 0, "set of raw payments should not be empty");

        // first, find the monies that are represented in the raw payments
        for (uint ii = 0; ii < rawPayments.length; ii++) {

            bool found = false;
            for (uint jj = 0; jj < monies.length; ++jj) {
                if (monies[jj] == rawPayments[ii].erc20) {
                    found = true;
                    break;
                }
            }
            if (found) continue;

            // erc20 of this payment wasn't found in monies, add it
            monies.push(rawPayments[ii].erc20);
        }

        // now, iterate over the monies found, net by each one by one, accumulating result
        for (uint jj = 0; jj < monies.length; ++jj) {
            netOneMoney(rawPayments, monies[jj]);
        }

        // TBD - could delete monies and netAmounts here, but leave around for now
        // as it could be useful to query these to understand actions completed in
        // the most recent netting pass.

        console.log("All multilateral netting done, #payments =", nettedPayments.length);

        return nettedPayments;
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////////
    //
    function netOneMoney(Common.PaymentLeg[] calldata rawPayments, address money) internal
    {
        require(money != address(0), "money address must be non-zero");

        // run offsetting algorithm for payments in the specified money
        for (uint ii = 0; ii < rawPayments.length; ii++) {

            if (rawPayments[ii].erc20 != money)
            {
                //console.log("Skipping raw payment #", ii);
                continue;
            }

            address fromAddr  = rawPayments[ii].from;
            address toAddr    = rawPayments[ii].to;
            uint    amount    = rawPayments[ii].amount;

            // update net amounts
            updateNetForEndpt(fromAddr, int(amount) * -1, money);
            updateNetForEndpt(toAddr, int(amount), money);
        }

        // ofsetting has completed. generate resulting payments
        for (uint ii = 0; ii < netAmounts.length; ii++) {

            if (netAmounts[ii].erc20 != money)
                continue;

            address endpt  = netAmounts[ii].endpt;
            int     netAmt = netAmounts[ii].amount;

            if (netAmt == 0) continue;
            if (netAmt < 0) { // endpt is net payer - pays TO the PaymentSystem
                nettedPayments.push(Common.newLeg(endpt, address(0), uint(netAmt * -1), money));

                // temp
                console.log("Payer", endpt, "-->", uint(netAmt * -1));
            }
            else { // endpt is a net payee - is paid FROM the PaymentSystem
                nettedPayments.push(Common.newLeg(address(0), endpt, uint(netAmt), money));

                // temp
                console.log("Payee", endpt, "<--", uint(netAmt));
            }
        }

        console.log("Multilateral netting done for ERC20", money);
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

