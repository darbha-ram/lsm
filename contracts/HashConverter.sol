// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//
// Helper functions to convert to/fro a bytes32 binary hash to a human-readable hex string.
//

library HashConverter {

    ////////////////////////////////////////////////////////////////////////////////////
    // binary hash --> hex string
    //

    // Convert one byte to 2 hex chars
    function byteToHexString(bytes1 b) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(2);
        str[0] = hexChars[uint8(b) >> 4];
        str[1] = hexChars[uint8(b) & 0x0f];
        return string(str);
    }

    // Convert bytes32 to 0x-prefixed hex string
    function toHexString(bytes32 data) public pure returns (string memory) {
        bytes memory result = new bytes(2 + 64);
        result[0] = "0";
        result[1] = "x";
        for (uint i = 0; i < 32; i++) {
            bytes1 b = data[i];
            bytes memory hexStr = bytes(byteToHexString(b));
            result[2 + i * 2] = hexStr[0];
            result[3 + i * 2] = hexStr[1];
        }
        return string(result);
    }

    ////////////////////////////////////////////////////////////////////////////////////
    // hex string --> binary hash
    //

    // Convert single hex char to its integer value
    function fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
            return 10 + c - uint8(bytes1('A'));
        }
        revert("Invalid hex char");
    }

    // Convert 0x-prefixed hex string to bytes32
    function hexStringToBytes32(string memory s) public pure returns (bytes32 result) {
        bytes memory strBytes = bytes(s);
        require(strBytes.length == 66, "Invalid length"); // 2 for 0x + 64 hex chars
        require(strBytes[0] == '0' && strBytes[1] == 'x', "Missing 0x prefix");

        for (uint i = 0; i < 32; i++) {
            uint8 high = fromHexChar(uint8(strBytes[2 + i * 2]));
            uint8 low = fromHexChar(uint8(strBytes[3 + i * 2]));
            result |= bytes32(uint256(high * 16 + low) << (8 * (31 - i)));
        }
    }
}

