///////////////////////////////////////////////////////////////////////////////////////////
// CommonTest.sol
// 
// This is not a production contract, instead just for testing the Common & HashConverter
// libraries.
//
// Author: Ram Darbha
///////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Common.sol";
import "./HashConverter.sol";

contract MyLibsTest {

    // Note: must be "view" rather than "pure" because Common.newLeg() non-intuitively
    // needs to read state -- to get timestamp that is used to compute hash!
    //
    function callNewLeg(address _from, address _to, uint _amount, address _erc20)
        public view returns(Common.PaymentLeg memory) {
        return Common.newLeg(_from, _to, _amount, _erc20);
    }

    function callToHexString(bytes32 _data) public pure returns(string memory) {
        return HashConverter.toHexString(_data);
    }

    // Note: can't specify data location "memory" for bytes32, only for array,
    // struct or mapping types.
    function callHexStringToBytes32(string memory _s) public pure returns (bytes32) {
        return HashConverter.hexStringToBytes32(_s);
    }

    function myver() public pure returns(string memory) {
        return "12Aug.1510";
    }


}

