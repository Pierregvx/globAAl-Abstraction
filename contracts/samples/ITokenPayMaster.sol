// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;
import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import "../../core/BasePaymaster.sol";
// import "../../interfaces/IPaymaster.sol";
import "hardhat/console.sol";

interface ITokenPayMaster {
        enum StandardType {
        ERC4337,
        SAFE,
        ZKSYNC
    }
        struct Account {
        uint8 chainID;
        address accountAddress;
        StandardType standardType;
    }
}