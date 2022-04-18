// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;
pragma solidity >=0.7.6;

import 'hardhat/console.sol';

contract GasCosts {
    // constructor() {}

    bytes32 public testnum;
    function testset() external {
        testnum = bytes32('0x1');
    }

    function testSet() internal {
        testnum = bytes32('0x1');
    }

    function AbiEncode() internal pure {
        // (1) As facilitated by the compiler
        string memory sm0 = "0"; 
        string memory sm1 = "1"; 
        string(abi.encodePacked(sm0, sm1));
    }
    function CreateReport() public {
        GasCost("AbiEncode ", AbiEncode);
        GasCost("testSet ", testSet);
        // GasCost("BaseExternal ", BaseExternal);
        // GasCost("ComponentExternal ", ComponentExternal);
        // GasCost("LibraryInternal ", LibraryInternal);
        // GasCost("LibraryExternal ", LibraryExternal);
    }
    function GasCost(string memory name, function() fun) internal {
        uint u0 = gasleft();
        fun();
        uint u1 = gasleft();
        uint diff = u0 - u1;
        console.log(name, diff);
    }
}
