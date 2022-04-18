// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;
pragma solidity >=0.7.6;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

struct LimitDetail {
    address account;
    uint limit;
    uint amount;
}

contract OBv1 is Ownable {
    address public feeRecipient;
    address public feeRecipientSetter;

    // address public factory;
    // address private _creator;
    // string public symbol;
    mapping(address => mapping(address => uint)) public getBook;
    // mapping(address => mapping(uint => mapping(address => uint))) public getBuys;
    mapping(address => LimitDetail[]) public getBuys;
    mapping(address => LimitDetail[]) public getSells;

    event NewDeposit(address address_, uint amount_);
    
    constructor(address _feeRecipientSetter) Ownable() {
        feeRecipientSetter = _feeRecipientSetter;
    }

    /* BOOK FUNCTIONS
    */
    function deposit(
        address _token,
        uint _amount
    ) public virtual {
        require(_amount > 0, 'TPv1: ILLEGAL NEGATIVE DEPOSIT AMOUNT');
        // TODO: transferFrom msg.sender
        getBook[_token][msg.sender] = getBook[_token][msg.sender] + _amount;
        emit NewDeposit(msg.sender, _amount);
    }

    function transfer(
        address _token,
        address _to,
        uint _amount
    ) public virtual {
        _safeTransfer(_token, msg.sender, _to, _amount);
    }

    /* ORDER BOOK FUNCTIONS
    */
    function limitOrderBuy(
        address _token,
        uint _limit,
        uint _amount
    ) public virtual onlyOwner() {
        // getBuys[_token][_limit][msg.sender] = amount;
        getBuys[_token].push(LimitDetail(msg.sender, _limit, _amount));
    }

    function limitOrderSell(
        address _token,
        uint _limit,
        uint _amount
    ) public virtual onlyOwner() {
        // // Check whether an available order exists.
        // LimitDetail[] toUse; 
        // for (uint i = 0; i < getBuys[_token].length; i++) {
        //     if (getBuys[_token][i].limit >= _limit) {
        //         data[n] = i;
        //         if (++n >= length) break;
        //     }
        // }
        // getBuys[_token][]
        // getSells[_token][_limit][msg.sender] = _amount;
        getSells[_token].push(LimitDetail(msg.sender, _limit, _amount));
    }

    /* PRIVATE UTILITY FUNCTIONS
    */
    function _safeTransfer(
        address _token,
        address _from,
        address _to,
        uint _amount
    ) private {
        // Ensure the from address has enough balance for the transfer
        require(getBook[_from][_token] >= _amount, 'TPv1: INSUFFICIENT FUNDS');
        getBook[_from][_token] = getBook[_from][_token] - _amount;
        getBook[_to][_token] = getBook[_to][_token] + _amount;
    }

    /* FEE FUNCTIONS
    */
    function setFeeRecipient(address _feeRecipient) external {
        require(msg.sender == feeRecipient, 'TPv1: FORBIDDEN');
        feeRecipient = _feeRecipient;
    }

    function setFeeRecipientSetter(address _feeRecipientSetter) external {
        require(msg.sender == feeRecipient, 'TPv1: FORBIDDEN');
        feeRecipient = _feeRecipientSetter;
    }
}
