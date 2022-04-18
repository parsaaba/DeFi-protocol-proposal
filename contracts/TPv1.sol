// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;
pragma solidity >=0.7.6;

import 'hardhat/console.sol';
// import './interfaces/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


struct Offer {
    address account;
    uint amount;
}

contract TPv1 is Ownable {
    address public feeRecipient;
    address public feeRecipientSetter;

    // address public factory;
    // address private _creator;
    // string public symbol;

    // account address => token address => balance amount
    mapping(address => mapping(address => uint)) public getBook;
    // TP symbol => token address => token balance
    mapping(string => mapping(address => uint)) public getTp;
    // TP symbol => owner address
    mapping(string => address) public getTpOwner;
    // Owner address => TP list
    mapping(address => string[]) public getOwnerTps;
    string[] public tpList;

    // account address => TP symbol => Offer list
    mapping(address => mapping(string => Offer[])) public getOffers;

    event Deposit(address account_, address token_, uint amount_);
    event Withdrawal(address account_, address token_, uint amount_);
    event Transfer(address token_, address from_, address to_, uint amount_);
    event Mint(string symbol_, address account_);
    event Fill(string symbol_, address token_, uint amount_);
    event Drain(string symbol_, address token_, uint amount_);
    event Assign(string symbol_, address from_, address to_);
    
    // constructor(address _feeRecipientSetter) Ownable() {
    //     feeRecipientSetter = _feeRecipientSetter;
    // }
    constructor() Ownable() {
        console.log("TPv1 constructor");
    }

    /* BOOK FUNCTIONS
    */
    function deposit(
        address _token,
        uint _amount
    ) public virtual {
        require(_amount > 0, 'TPv1: ILLEGAL DEPOSIT AMOUNT');

        uint currentBalance = 0;
        if (getBook[msg.sender][_token] > 0) {
            currentBalance = getBook[msg.sender][_token];
        }

        // Transfer amount from sender to contract for referenced token
        IERC20 fromToken = IERC20(_token);
        fromToken.transferFrom(msg.sender, address(this), _amount);

        // Increase the internal book balance to account for transfer
        getBook[msg.sender][_token] = currentBalance + _amount;
        emit Deposit(msg.sender, _token, _amount);
    }

    function withdraw(
        address _token,
        uint _amount
    ) public virtual {
        // Check available Book Balance
        uint bookBalance = getBook[msg.sender][_token];
        require(bookBalance >= _amount, 'TPv1: INSUFFICIENT BOOK BALANCE');
        
        // Transfer amount from contract to sender for referenced token
        IERC20 toToken = IERC20(_token);
        toToken.transfer(msg.sender, _amount);

        // Decrease the internal book balance to account for transfer
        getBook[msg.sender][_token] = getBook[msg.sender][_token] - _amount;
        emit Withdrawal(msg.sender, _token, _amount);
    }

    function transfer(
        address _token,
        address _to,
        uint _amount
    ) public virtual {
        _safeTransfer(_token, msg.sender, _to, _amount);
        emit Transfer(_token, msg.sender, _to, _amount);
    }

    /* TP FUNCTIONS
    */
    function mint(
        string memory _symbol
    ) public virtual {
        require(getTpOwner[_symbol] == address(0), 'TPv1: TOKEN_EXISTS');
        getTpOwner[_symbol] = msg.sender;
        getOwnerTps[msg.sender].push(_symbol);
        tpList.push(_symbol);

        emit Mint(_symbol, msg.sender);
    }

    function fill(
        string memory _symbol,
        address _token,
        uint _amount
    ) public virtual {
        // Check ownership
        require(getTpOwner[_symbol] == msg.sender, 'TPv1: UNAUTHORIZED');

        // Check available Book Balance
        uint bookBalance = getBook[msg.sender][_token];
        require(bookBalance >= _amount, 'TPv1: INSUFFICIENT BOOK BALANCE');

        // Transfer Book Balance to TP Balance
        getBook[msg.sender][_token] = getBook[msg.sender][_token] - _amount;
        getTp[_symbol][_token] = getTp[_symbol][_token] + _amount;

        emit Fill(_symbol, _token, _amount);

        // // Check all target token balances in this account's TPs
        // string[] memory ownerTps = getOwnerTps[msg.sender];
        // uint tpTokenTotalBalance = 0;
        // uint len = ownerTps.length;
        // for (uint i=0; i<len; i++) {
        //     if (keccak256(bytes(ownerTps[i])) == keccak256(bytes(_symbol))) {
        //         tpTokenTotalBalance += getTp[_symbol][_token];
        //     }
        // }
        
        // // The remaining book balance not allocated funds to TPs should cover the desired allocation.
        // require(bookBalance - tpTokenTotalBalance >= _amount, 'TPv1: INSUFFICIENT UNALLOCATED BOOK BALANCE');
        // getTp[_symbol][_token] = _amount;
    }

    function drain(
        string memory _symbol,
        address _token,
        uint _amount
    ) public virtual {
        // Check ownership
        require(getTpOwner[_symbol] == msg.sender, 'TPv1: UNAUTHORIZED');

        // Check available TP Balance
        uint tpBalance = getTp[_symbol][_token];
        require(tpBalance >= _amount, 'TPv1: INSUFFICIENT TP BALANCE');

        // Transfer Book Balance to TP Balance
        getTp[_symbol][_token] = getTp[_symbol][_token] - _amount;
        getBook[msg.sender][_token] = getBook[msg.sender][_token] + _amount;

        emit Drain(_symbol, _token, _amount);
    }

    function assign(
        string memory _symbol,
        address _to
    ) public virtual {
        // Check ownership
        require(getTpOwner[_symbol] == msg.sender, 'TPv1: UNAUTHORIZED');

        // Remove the symbol from the prior owner
        uint i = 0;
        while (keccak256(abi.encodePacked(getOwnerTps[msg.sender][i])) != keccak256(abi.encodePacked(_symbol))) { i++; }
        delete getOwnerTps[msg.sender][i];
        getOwnerTps[_to].push(_symbol);

        // console.log("from tps:");
        // string[] memory tps = getOwnerTps[msg.sender];
        // for(uint j=0; j<tps.length; j++){
        //     console.log(tps[j]);
        // }
        // console.log("to tps:");
        // tps = getOwnerTps[_to];
        // for(uint j=0; j<tps.length; j++){
        //     console.log(tps[j]);
        // }

        // Transfer Book Balance to TP Balance
        getTpOwner[_symbol] = _to;

        emit Assign(_symbol, msg.sender, _to);
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
