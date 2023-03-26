// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;
import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import "../../core/BasePaymaster.sol";

// import "../../interfaces/IPaymaster.sol";
contract MasterPayMaster {
    mapping(uint32 => BasePaymaster) public chainsPayMaster;
    IConnext public immutable connext;
    uint256 public immutable slippage = 10000;
    struct Chain{
        uint32 chainId;
        uint32 domainId;
        address paymaster;
    }
    Chain[] public chains;

    constructor(address _connext) {
        connext = IConnext(_connext);
        
    }
    function addAChain(uint32 chainId, uint32 domainId, address paymaster) public {
        chains.push(Chain(chainId, domainId, paymaster));
    }
    


    function setPayMaster(uint32 chainId, BasePaymaster payMaster) public {
        chainsPayMaster[chainId] = payMaster;
    }
   

    function addAmount(
        uint32 destinationDomain,
        uint256 relayerFee,
        uint256 depositAmount
    ) public {
        bytes memory callData = abi.encode(
            "deposit(uint256)",
            depositAmount
        );
        // decode the callData and chech the function signature and the amount
        (string memory funcSig, uint256 amount) = abi.decode(
            callData,
            (string, uint256)
        );

        connext.xcall{value: relayerFee}(
            destinationDomain, // _destination: Domain ID of the destination chain
            address(chainsPayMaster[destinationDomain]), // _to: address of the target contract
            address(0), // _asset: address of the token contract
            msg.sender, // _delegate: address that can revert or forceLocal on destination
            0, // _amount: amount of tokens to transfer
            slippage, // _slippage: max slippage the user will accept in BPS (e.g. 300 = 3%)
            callData // _callData: the encoded calldata to send
        );
    }
    function depositOnL2(uint32 destinationDomain, uint256 relayerFee,uint256 amount) public payable {
        sendMessageFromL1(destinationDomain, relayerFee, amount, "deposit(uint256)");
    }
    function wlAccountOnL2(uint32 destinationDomain, uint256 relayerFee,address account) public payable {
        sendMessageFromL1(destinationDomain, relayerFee, uint256(uint160(account)), "wlAccount(uint256)");
    }
    function unWlAccountOnL2(uint32 destinationDomain, uint256 relayerFee,address account) public payable {
        sendMessageFromL1(destinationDomain, relayerFee, uint256(uint160(account)), "unWlAccount(uint256)");
    }
    function freezeAccountOnL2(uint32 destinationDomain, uint256 relayerFee,address account) public payable {
        // call the freezeAccount function on the L2 contract for each chain
        for(uint i = 0; i < chains.length; i++){
            if(chains[i].chainId == destinationDomain){
                sendMessageFromL1(chains[i].domainId, relayerFee, uint256(uint160(account)), "freezeAccount(uint256)");
            }
        }
    }
    function sendMessageFromL1(
        uint32 destinationDomain,
        uint256 relayerFee,
        uint256 depositAmount,
        string memory message
    ) public payable{
        bytes memory callData = abi.encode(
            message,
            depositAmount
        );
        // decode the callData and chech the function signature and the amount

        connext.xcall{value: relayerFee}(
            destinationDomain, // _destination: Domain ID of the destination chain
            address(chainsPayMaster[destinationDomain]), // _to: address of the target contract
            address(0), // _asset: address of the token contract
            msg.sender, // _delegate: address that can revert or forceLocal on destination
            0, // _amount: amount of tokens to transfer
            slippage, // _slippage: max slippage the user will accept in BPS (e.g. 300 = 3%)
            callData // _callData: the encoded calldata to send
        );
    }

}
