///////////////////////////////////////////////////////////////////////////////////////////////////
// Common.sol
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library Common {

    // a payment in a single money supply (i.e., one contract)
    struct PaymentLeg {
        bytes32   id;       // globally unique ID of this leg 
        address  from;
        address  to;
        uint     amount;   // in token decimals
        address  erc20;    // currency of payment
    }

    // helper function to instantiate new PaymentLeg
    function newLeg(address _from, address _to, uint _amount, address _erc20)
        public view returns(PaymentLeg memory) {
        return PaymentLeg({
            id:     keccak256(abi.encodePacked(_from, _to, _amount, _erc20, block.timestamp)),
            from:   _from,
            to:     _to,
            amount: _amount,
            erc20:  _erc20
        });
    }



}


