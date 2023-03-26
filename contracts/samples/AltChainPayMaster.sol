pragma solidity ^0.8.12;

import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import "../../core/BasePaymaster.sol";

import 'protocol/packages/core/contracts/oracle/interfaces/OptimisticOracleV2Interface.sol';
contract AltChainPayMaster is BasePaymaster {
    IConnext public immutable connext;
    uint256 public immutable slippage = 10000;
    uint256 COST_OF_POST = 15000;

    mapping(address => bool) public userAlloweds;
    mapping(address=> Proposal) public props;


    constructor(
        address _connext,
        IEntryPoint _entryPoint
    ) BasePaymaster(_entryPoint) {
        connext = IConnext(_connext);
    }
     function requestData(address user,bool isFreeze) public {
        bytes memory ancillaryData = abi.encodePacked();
        requestTime = block.timestamp; // Set the request time to the current block time.
        IERC20 bondCurrency = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6); // Use Görli WETH as the bond currency.
        uint256 reward = 0; // Set the reward to 0 (so we dont have to fund it from this contract).*// Now, make the price request to the Optimistic oracle and set the liveness to 30 so it will settle quickly.
        oo.requestPrice(identifier, requestTime, ancillaryData, bondCurrency, reward);
        oo.setCustomLiveness(identifier, requestTime, ancillaryData, 30);
        props[user]=ancillaryData
    }
    function settleRequest(address user) public {
        Proposal storage prop = props[user];
        oo.settle(address(this), identifier, prop.time, prop.data);
        if (lastDeploymentProposal[IPFSHash].time == 0) return;
        int256 result = getSettledData(IPFSHash);
        string memory response =string.concat(IPFSHash,' has been', (newState == State.ACCEPTED ? 'accepted ' : 'refused'));

        
    }

    // Fetch the resolved price from the Optimistic Oracle that was settled.
       function getSettledData(string memory IPFSHash) public view returns (int256) {
        Proposal memory prop = lastDeploymentProposal[IPFSHash];
        return oo.getRequest(address(this), identifier, prop.time, prop.data).resolvedPrice;
    }

    function updatePropState(string memory IPFSHash) public {
        if (lastDeploymentProposal[IPFSHash].time == 0) return;
        int256 result = getSettledData(IPFSHash);
        State newState = State.REFUSED;
        if (result == 0) newState = State.ACCEPTED;
        propDetails[IPFSHash].state = newState;
        emit ProposalUpdated(
            propDetails[IPFSHash].DAOaddress,
            IPFSHash,
            newState,
            lastDeploymentProposal[IPFSHash].data
        );

        updatePropState(IPFSHash);
    }
    function getSettledData(address user) public view returns (int256) {
        Proposal memory prop = props[IPFSHash];
        return oo.getRequest(address(this), identifier, prop.time, prop.data).resolvedPrice;
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
