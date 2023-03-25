// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

/* solhint-disable reason-string */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../../core/BasePaymaster.sol";
import "./ITokenPayMaster.sol";
import "./MasterPayMaster.sol";
import {IConnext} from "@connext/interfaces/core/IConnext.sol";

/**
 * A sample paymaster that defines itself as a token to pay for gas.
 * The paymaster IS the token to use, since a paymaster cannot use an external contract.
 * Also, the exchange rate has to be fixed, since it can't reference an external Uniswap or other exchange contract.
 * subclass should override "getTokenValueOfEth" to provide actual token exchange rate, settable by the owner.
 * Known Limitation: this paymaster is exploitable when put into a batch with multiple ops (of different accounts):
 * - while a single op can't exploit the paymaster (if postOp fails to withdraw the tokens, the user's op is reverted,
 *   and then we know we can withdraw the tokens), multiple ops with different senders (all using this paymaster)
 *   in a batch can withdraw funds from 2nd and further ops, forcing the paymaster itself to pay (from its deposit)
 * - Possible workarounds are either use a more complex paymaster scheme (e.g. the DepositPaymaster) or
 *   to whitelist the account and the called method ids.
 */
contract TokenPayMaster is BasePaymaster, ERC721,MasterPayMaster {
    //calculated cost of the postOp
    uint256 public constant COST_OF_POST = 15000;
    //2**16 = 65536
    address public immutable theFactory;
    

    mapping(uint256 => uint256) public bondReserve;
    uint256 public reserve = 0.01 ether;
    uint256 public freezingPoint = 0.001 ether;
    error InsufficientReserve();

    constructor(
        address accountFactory,
        IEntryPoint _entryPoint,
        address _connext
    ) ERC721("fees wrapped ether", "fWETH") BasePaymaster(_entryPoint) MasterPayMaster(_connext) {
        theFactory = accountFactory;
        //make it non-empty
        _mint(address(this), 1);
    }

    /**
     * create a new account.
     * the account is created with a pre-funded balance of tokens.
     * the paymaster is the owner of the account.
     *
     */
    function createBond(address to) external payable {
        _mint(to, uint256(keccak256(abi.encode(to))));
        
        _topUpBond(to, msg.value);
    }

    function topUpBond(address to) external payable {
        _topUpBond(to, msg.value);
    }

    function _topUpBond(address to, uint256 amount) private {
        bondReserve[uint256(keccak256(abi.encode(to)))] += amount;
    }




    /**
     * validate the request:
     * if this is a constructor call, make sure it is a known account.
     * verify the sender has enough tokens.
     * (since the paymaster is also the token, there is no notion of "approval")
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 requiredPreFund
    )
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        uint256 tokenPrefund = requiredPreFund;

        // verificationGasLimit is dual-purposed, as gas limit for postOp. make sure it is high enough
        // make sure that verificationGasLimit is high enough to handle postOp
        require(
            userOp.verificationGasLimit > COST_OF_POST,
            "TokenPaymaster: gas too low for postOp"
        );

        if (userOp.initCode.length != 0) {
            // _validateConstructor(userOp);
            require(
                bondReserve[uint256(keccak256(abi.encode(userOp.sender)))] >=
                    tokenPrefund,
                "TokenPaymaster: no balance (pre-create)"
            );
        } else {
            require(
                bondReserve[uint256(keccak256(abi.encode(userOp.sender)))] >=
                    tokenPrefund,
                "TokenPaymaster: no balance"
            );
        }

        return (abi.encode(userOp.sender), 0);
    }

    // when constructing an account, validate constructor code and parameters
    // we trust our factory (and that it doesn't have any other public methods)
    // function _validateConstructor(
    //     UserOperation calldata userOp
    // ) internal view virtual {
    //     address factory = address(bytes20(userOp.initCode[0:20]));
    //     require(factory == theFactory, "TokenPaymaster: wrong account factory");
    // }

    /**
     * actual charge of user.
     * this method will be called just after the user's TX with mode==OpSucceeded|OpReverted (account pays in both cases)
     * BUT: if the user changed its balance in a way that will cause  postOp to revert, then it gets called again, after reverting
     * the user's TX , back to the state it was before the transaction started (before the validatePaymasterUserOp),
     * and the transaction should succeed there.
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        //we don't really care about the mode, we just pay the gas with the user's tokens.
        (mode);
        address sender = abi.decode(context, (address));
        uint256 charge = actualGasCost + COST_OF_POST;
        //actualGasCost is known to be no larger than the above requiredPreFund, so the transfer should succeed.
        _transfer(sender, address(this), charge);
    }
}