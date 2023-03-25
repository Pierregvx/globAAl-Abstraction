pragma solidity ^0.8.12;

import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import "../../core/BasePaymaster.sol";

contract AltChainPayMaster is BasePaymaster {
    IConnext public immutable connext;
    uint256 public immutable slippage = 10000;
    uint256 COST_OF_POST = 15000;

    mapping(address => bool) public userAlloweds;

    constructor(
        address _connext,
        IEntryPoint _entryPoint
    ) BasePaymaster(_entryPoint) {
        connext = IConnext(_connext);
    }

    function xReceive(
        bytes32 _transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes memory _callData
    ) external returns (bytes memory) {
        // Unpack the _callData
        (string memory newGreeting,uint256 value) = abi.decode(_callData, (string, uint256));
        if(keccak256(bytes(newGreeting)) == keccak256(bytes("deposit(uint256)"))) {
            entryPoint.depositTo{value: _amount}(address(this));
        }
        else if(keccak256(bytes(newGreeting)) == keccak256(bytes("wlAccount(uint256)"))) {
            // address = convert amount to address
            address to = payable(address(uint160(value)));
            userAlloweds[to] = true;
        }
        else if(keccak256(bytes(newGreeting)) == keccak256(bytes("freezeAccount(uint256)"))) {
            // address = convert amount to address
            address to = payable(address(uint160(value)));
            delete userAlloweds[to];
        }

    }

    //   function _validateConstructor(
    //         UserOperation calldata userOp
    //     ) internal view virtual {
    //         address factory = address(bytes20(userOp.initCode[0:20]));
    //         require(factory == theFactory, "TokenPaymaster: wrong account factory");
    //     }
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 /*requiredPreFund*/
    )
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        // verificationGasLimit is dual-purposed, as gas limit for postOp. make sure it is high enough
        // make sure that verificationGasLimit is high enough to handle postOp
        require(
            userOp.verificationGasLimit > COST_OF_POST,
            "TokenPaymaster: gas too low for postOp"
        );

        if (userOp.initCode.length != 0) {
            require(
                userAlloweds[userOp.sender],
                "user not allowed (pre-create))"
            );
        } else {
            require(userAlloweds[userOp.sender], "user not allowed ");
        }

        return (abi.encode(userOp.sender), 0);
    }
}
