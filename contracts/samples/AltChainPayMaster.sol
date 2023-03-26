pragma solidity ^0.8.12;

import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import "../../core/BasePaymaster.sol";

import "protocol/packages/core/contracts/optimistic-oracle-v2/interfaces/OptimisticOracleV2Interface.sol";

contract AltChainPayMaster is BasePaymaster {
    IConnext public immutable connext;
    uint256 public immutable slippage = 10000;
    uint256 COST_OF_POST = 15000;
    struct User {
        bool isWL;
        bool isFrozen;
    }

    mapping(address => User) public users;
    OptimisticOracleV2Interface public oo;
    bytes32 public  identifier  = bytes32("YES_OR_NO_QUERY");
    uint256 public  limitValue  = 0.005 ether;
    uint256 requestTime;

    constructor(
        address _connext,
        IEntryPoint _entryPoint,
        address umacontract
    ) BasePaymaster(_entryPoint) {
        connext = IConnext(_connext);
        oo = OptimisticOracleV2Interface(umacontract);
    }

    function requestData(address currency, address user, bool freeze) public {
        bytes memory ancillaryData = abi.encodePacked(user, freeze);
        requestTime = block.timestamp; // Set the request time to the current block time.
        IERC20 bondCurrency = IERC20(currency); // Use Görli WETH as the bond currency.
        uint256 reward = 0; // Set the reward to 0 (so we dont have to fund it from this contract).

        // Now, make the price request to the Optimistic oracle and set the liveness to 30 so it will settle quickly.
        oo.requestPrice(
            identifier,
            requestTime,
            ancillaryData,
            bondCurrency,
            reward
        );
        oo.setCustomLiveness(identifier, requestTime, ancillaryData, 30);
    }

    function settleRequest(address user, bool freeze) public {
        bytes memory ancillaryData = abi.encodePacked(user, freeze);
        oo.settle(address(this), identifier, requestTime, ancillaryData);
    }

    function freezeAccountPM(address user) public {
        bytes memory ad = abi.encodePacked(user, true);
    }

    // Fetch the resolved price from the Optimistic Oracle that was settled.
    function getSettledData(
        address user,
        bool freeze
    ) public view returns (int256) {
        bytes memory ancillaryData = abi.encodePacked(user, freeze);
        return
            oo
                .getRequest(
                    address(this),
                    identifier,
                    requestTime,
                    ancillaryData
                )
                .resolvedPrice;
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
        (string memory newGreeting, uint256 value) = abi.decode(
            _callData,
            (string, uint256)
        );
        if (
            keccak256(bytes(newGreeting)) ==
            keccak256(bytes("deposit(uint256)"))
        ) {
            entryPoint.depositTo{value: _amount}(address(this));
        } else if (
            keccak256(bytes(newGreeting)) ==
            keccak256(bytes("wlAccount(uint256)"))
        ) {
            // address = convert amount to address
            address to = payable(address(uint160(value)));
            users[to].isWL = true;
        } else if (
            keccak256(bytes(newGreeting)) ==
            keccak256(bytes("freezeAccount(uint256)"))
        ) {
            // address = convert amount to address
            address to = payable(address(uint160(value)));
            delete users[to].isWL;
        }
    }
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
                users[userOp.sender].isWL,
                "user not allowed (pre-create))"
            );
        } else {
            require(users[userOp.sender].isWL, "user not allowed ");
        }

        return (abi.encode(userOp.sender), 0);
    }
}

//   function
