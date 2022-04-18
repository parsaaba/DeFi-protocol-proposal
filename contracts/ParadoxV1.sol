// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;
pragma solidity >=0.7.6;
pragma abicoder v2;

import 'hardhat/console.sol';
// import './interfaces/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


struct Offer {
    address account;
    uint amount;
}

// x * y = k; a * b = k
// a,b represent token pool amounts, so x,y are not used
// as representations, since which is x or y changes in the equation.
struct CPI {
    uint a;
    uint b;
    uint k;
}

contract ParadoxV1 is Ownable {
    using SafeMath for uint;
    
    address public feeRecipient;
    address public feeRecipientSetter;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'ParadoxV1: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /* BOOK | BALANCES
    */
    // account address => token address => balance amount
    mapping(address => mapping(address => uint)) public getBook;
    address[] public getAccount; //TODO: transfer to backend? Adds gas costs.
    mapping(address => address[]) public getBookList; //TODO: transfer to backend? Adds gas costs.
    mapping(address => uint) public getBookListLength; //TODO: transfer to backend? Adds gas costs.
    // TODO: Add token list storage? Currently using TokenFactory for frontend lookup.

    /* TOKEN POOLS
    */
    // TP symbol => token address => token balance
    mapping(string => mapping(address => uint)) public getTp;
    // TP symbol => owner address
    mapping(string => address) public getTpOwner;
    // Owner address => DOX list
    mapping(address => string[]) public getOwnerTps;
    string[] public tpList;

    // account address => TP symbol => Offer list
    mapping(address => mapping(string => Offer[])) public getOffers;

    /* CONST. PROD. AMM
    */
    // token0 => token1 => CPI <~~ tokens always ordered by address (smallest first)
    mapping(address => mapping(address => CPI)) public getCPI;
    mapping(address => mapping(address => mapping(address => uint))) public getLP; //LP token balances
    event AddLiquidity(address account_, address token0_, address token1_, uint token0input_, uint token1input_);
    event Swap(address account_, address tokenHave_, address tokenWant_, uint input_, uint output_);

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
        console.log("ParadoxV1 constructor");
    }

    /* CP AMM FUNCTIONS
    */
    function findCPI(
        address _token0,
        address _token1
    ) public view virtual returns (CPI memory foundCPI, bool orderCorrect) {
        (foundCPI, orderCorrect) = _safeGetCPI(_token0, _token1);
    }

    function addLiquidity(
        address _token0,
        address _token1,
        uint _token0input,
        uint _token1input
    ) public virtual lock {
        require(_token0 != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_token1 != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_token0input > 0, 'ParadoxV1: INVALID_LIQUIDITY_AMOUNT');
        require(_token1input > 0, 'ParadoxV1: INVALID_LIQUIDITY_AMOUNT');

        // Liquidity must come from book balances. Ensure the account
        // has enough book balances to cover the liquidity.
        require(getBook[msg.sender][_token0] >= _token0input, 'ParadoxV1: INSUFFICIENT_BOOK_BALANCE');
        require(getBook[msg.sender][_token1] >= _token1input, 'ParadoxV1: INSUFFICIENT_BOOK_BALANCE');

        // Reduce the book balance
        getBook[msg.sender][_token0] = getBook[msg.sender][_token0] - _token0input;
        getBook[msg.sender][_token1] = getBook[msg.sender][_token1] - _token1input;

        // Update the CPI amounts
        (CPI memory tempCPI, bool aIsToken0) = _safeGetCPI(_token0, _token1);
        // require(tempCPI.k != 0, 'ParadoxV1: TOKEN PAIR NOT FOUND');
        if (tempCPI.k == 0) {
            tempCPI.a = aIsToken0 ? _token0input : _token1input;
            tempCPI.b = aIsToken0 ? _token1input : _token0input;
            tempCPI.k = _token0input * _token1input;
        } else {
            // Update the stored CPI
            uint a = aIsToken0 ? tempCPI.a.add(_token0input) : tempCPI.a.add(_token1input);
            uint b = aIsToken0 ? tempCPI.b.add(_token1input) : tempCPI.b.add(_token0input);
            tempCPI.a = a;
            tempCPI.b = b;
            tempCPI.k = a * b;
        }

        // TODO: Add contribution amt to CPI
        _safeSaveCPI(_token0, _token1, tempCPI);
        emit AddLiquidity(msg.sender, _token0, _token1, _token0input, _token1input);
    }

    function swap(
        address _token0,
        address _token1,
        uint _give
    ) public virtual lock {
        // uint g0 = gasleft(); // GAS CALC
        require(_token0 != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_token1 != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_give > 0, 'ParadoxV1: INVALID_SWAP_AMOUNT');

        uint output12 = _swap(_token0, _token1, _give);

        emit Swap(msg.sender, _token0, _token1, _give, output12);
        // uint g1 = gasleft(); // GAS CALC
        // console.log("GAS: ParadoxV1: SWAP - SWAP:", g0 - g1); // GAS CALC
    }

    function _swap(
        address _tokenHave,
        address _tokenWant,
        uint _give
    ) private returns (uint output) {
        CPI memory swapCPI;
        bool aIsHave;
        (swapCPI, aIsHave, output) = swapCalc(_tokenHave, _tokenWant, _give);
        // console.log("swap output: ", output);
        // uint oldPx = swapCPI.a.mul(1000).div(swapCPI.b);

        // Update the stored CPI
        swapCPI.a = aIsHave ? swapCPI.a.add(_give) : swapCPI.a.sub(output);
        swapCPI.b = aIsHave ? swapCPI.b.sub(output) : swapCPI.b.add(_give);
        // console.log("NEW swapCPI: ", swapCPI.a, swapCPI.b, swapCPI.k);
        // console.log("OLD y price (in x thousandths): ", oldPx);
        // console.log("NEW y price (in x thousandths): ", swapCPI.a.mul(1000).div(swapCPI.b));
        // console.log("y price slippage (in x thousandths): ", swapCPI.a.mul(1000).div(swapCPI.b) - oldPx);
        _safeSaveCPI(_tokenHave, _tokenWant, swapCPI);

        // Adjust the account's balances
        _safeUpdateBook(msg.sender, _tokenHave, 0, _give);
        _safeUpdateBook(msg.sender, _tokenWant, output, 0);
    }

    function swapCalc(
        address _tokenHave,
        address _tokenWant,
        uint _give
    ) public view returns (CPI memory swapCPI, bool aIsHave, uint output) {
        require(_tokenHave != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_tokenWant != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_give > 0, 'ParadoxV1: INVALID_SWAP_AMOUNT');

        // Get the token pair Constant Product Invariant data (and liquidity amounts)
        // x * y = k; a * b = k; b - (k / (a + _give));

        // CPI data is stored with the lower-value-address token as "a" and the other as "b"
        (swapCPI, aIsHave) = _safeGetCPI(_tokenHave, _tokenWant);
        require(swapCPI.k != 0, 'ParadoxV1: TOKEN_PAIR_NOT_FOUND');

        // Calculate the amount of wanted token to return
        // Invariant / (tokenHave + give) = tokenWant new LP amount
        // tokenWant current - tokenWant new LP amount = tokenWant return amount

        // x * y = k; y - (k / (x + _give));
        // want_output = pool_want_start - (k / (pool_have_start + have_give));
        // uint poolHave = aIsHave ? swapCPI.a : swapCPI.b;
        // uint poolWant = aIsHave ? swapCPI.b : swapCPI.a;
        // output = poolWant.sub(swapCPI.k.div(poolHave.add(_give)));
        output = aIsHave ? swapCPI.b.sub(swapCPI.k.div(swapCPI.a.add(_give))) : swapCPI.a.sub(swapCPI.k.div(swapCPI.b.add(_give)));
    }

    /* BOOK FUNCTIONS
    */
    function accountListLength() external view returns (uint) {
        return getAccount.length;
    }

    // The account should have already approved a sufficient amount for transfer.
    function deposit(
        address _token,
        uint _amount
    ) public virtual lock {
        require(_token != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_amount > 0, 'ParadoxV1: INVALID_DEPOSIT_AMOUNT');

        IERC20 fromToken = IERC20(_token);
        require(fromToken.balanceOf(msg.sender) >= _amount, 'ParadoxV1: INSUFFICIENT_TOKEN_BALANCE');

        uint currentBalance;
        if (getBook[msg.sender][_token] > 0) {
            currentBalance = getBook[msg.sender][_token];
        } else {
            currentBalance = 0;
        }

        // Ensure the token is listed for this user
        address[] memory aList = getBookList[msg.sender];
        uint aListLength = aList.length;
        bool exists = false;
        for (uint i=0; i<aListLength; i++) {
            if (aList[i] == _token) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            getBookList[msg.sender].push(_token);
            getBookListLength[msg.sender] = getBookListLength[msg.sender] + 1;
        }

        // Transfer amount from sender to contract for referenced token
        fromToken.transferFrom(msg.sender, address(this), _amount);

        // Increase the internal book balance to account for transfer
        getBook[msg.sender][_token] = currentBalance.add(_amount);

        // Add the account to the address list if it does not yet exist
        if (!_findAccount(msg.sender)) {
            getAccount.push(msg.sender);
        }
        emit Deposit(msg.sender, _token, _amount);
    }

    function withdraw(
        address _token,
        uint _amount
    ) public virtual lock {
        require(_token != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_amount > 0, 'ParadoxV1: INVALID_WITHDRAW_AMOUNT');
        
        // Check available Book Balance
        uint bookBalance = getBook[msg.sender][_token];
        require(bookBalance >= _amount, 'ParadoxV1: INSUFFICIENT_BOOK_BALANCE');
        
        // Transfer amount from contract to sender for referenced token
        IERC20 toToken = IERC20(_token);
        toToken.transfer(msg.sender, _amount);

        // Decrease the internal book balance to account for transfer
        getBook[msg.sender][_token] = getBook[msg.sender][_token].sub(_amount);
        emit Withdrawal(msg.sender, _token, _amount);
    }

    function transfer(
        address _token,
        address _to,
        uint _amount
    ) public virtual lock {
        require(_token != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        require(_to != address(0), 'ParadoxV1: INVALID_ACCOUNT_ADDRESS');
        require(_amount > 0, 'ParadoxV1: INVALID_TRANSFER_AMOUNT');
        
        _safeTransfer(_token, msg.sender, _to, _amount);

        // Ensure the token is listed for this user
        address[] memory aList = getBookList[_to];
        uint aListLength = aList.length;
        bool exists = false;
        for (uint i=0; i<aListLength; i++) {
            if (aList[i] == _token) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            getBookList[_to].push(_token);
            getBookListLength[_to] = getBookListLength[_to] + 1;
        }

        emit Transfer(_token, msg.sender, _to, _amount);
    }

    function _findAccount(address account) private view returns (bool exists) {
        exists = false;
        uint alLength = getAccount.length;
        for (uint i=0; i<alLength; i++) {
            if (getAccount[i] == account) {
                exists = true;
                break;
            }
        }
    }

    /* TP FUNCTIONS
    */
    function mint(
        string memory _symbol
    ) public virtual lock {
        require(getTpOwner[_symbol] == address(0), 'ParadoxV1: TOKEN_EXISTS');
        getTpOwner[_symbol] = msg.sender;
        getOwnerTps[msg.sender].push(_symbol);
        tpList.push(_symbol);

        emit Mint(_symbol, msg.sender);
    }

    function fill(
        string memory _symbol,
        address _token,
        uint _amount
    ) public virtual lock {
        require(_token != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        
        // Check ownership
        require(getTpOwner[_symbol] == msg.sender, 'ParadoxV1: UNAUTHORIZED');

        // Check available Book Balance
        uint bookBalance = getBook[msg.sender][_token];
        require(bookBalance >= _amount, 'ParadoxV1: INSUFFICIENT_BOOK_BALANCE');

        // Transfer Book Balance to TP Balance
        getBook[msg.sender][_token] = getBook[msg.sender][_token].sub(_amount);
        getTp[_symbol][_token] = getTp[_symbol][_token].add(_amount);

        emit Fill(_symbol, _token, _amount);

        // // Check all target token balances in this account's Tps
        // string[] memory ownerTps = getOwnerTps[msg.sender];
        // uint tpTokenTotalBalance = 0;
        // uint len = ownerTps.length;
        // for (uint i=0; i<len; i++) {
        //     if (keccak256(bytes(ownerTps[i])) == keccak256(bytes(_symbol))) {
        //         tpTokenTotalBalance += getTp[_symbol][_token];
        //     }
        // }
        
        // // The remaining book balance not allocated funds to TPs should cover the desired allocation.
        // require(bookBalance - tpTokenTotalBalance >= _amount, 'ParadoxV1: INSUFFICIENT UNALLOCATED BOOK BALANCE');
        // getTp[_symbol][_token] = _amount;
    }

    function drain(
        string memory _symbol,
        address _token,
        uint _amount
    ) public virtual lock {
        require(_token != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        
        // Check ownership
        require(getTpOwner[_symbol] == msg.sender, 'ParadoxV1: UNAUTHORIZED');

        // Check available TP Balance
        uint tpBalance = getTp[_symbol][_token];
        require(tpBalance >= _amount, 'ParadoxV1: INSUFFICIENT_TP_BALANCE');

        // Transfer Book Balance to TP Balance
        getTp[_symbol][_token] = getTp[_symbol][_token].sub(_amount);
        getBook[msg.sender][_token] = getBook[msg.sender][_token].add(_amount);

        emit Drain(_symbol, _token, _amount);
    }

    function assign(
        string memory _symbol,
        address _to
    ) public virtual lock {
        require(_to != address(0), 'ParadoxV1: INVALID_TOKEN_ADDRESS');
        
        // Check ownership
        require(getTpOwner[_symbol] == msg.sender, 'ParadoxV1: UNAUTHORIZED');

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
        require(getBook[_from][_token] >= _amount, 'ParadoxV1: INSUFFICIENT_FUNDS');
        getBook[_from][_token] = getBook[_from][_token].sub(_amount);
        getBook[_to][_token] = getBook[_to][_token].add(_amount);
    }

    function _safeUpdateBook(address _account, address _token, uint add, uint subtract) private {
        require(_account != address(0) && _token != address(0), 'ParadoxV1: INVALID_ADDRESS');
        // require(add > 0 && subtract > 0, 'ParadoxV1: INVALID ADJUSTMENT AMOUNT');
        uint currentBal = getBook[_account][_token];
        console.log("_safeUpdateBook (current, add, subtract): ", currentBal, add, subtract);
        getBook[_account][_token] = currentBal.add(add).sub(subtract);
    }

    // Will find CPI (if exists) regardless of the order of addresses passed
    function _safeGetCPI(address _token0, address _token1) private view returns (CPI memory gotCPI, bool inputOrder) {
        require(_token0 != address(0) && _token1 != address(0), 'ParadoxV1: INVALID_ADDRESS');
        address tokenA = _token0 < _token1 ? _token0 : _token1;
        address tokenB = _token0 < _token1 ? _token1 : _token0;
        inputOrder = tokenA == _token0 ? true : false;
        gotCPI = getCPI[tokenA][tokenB];
    }
    // Will save CPI correctly regardless of the order of addresses passed
    function _safeSaveCPI(address _token0, address _token1, CPI memory newCPI) private {
        require(_token0 != address(0) && _token1 != address(0), 'ParadoxV1: INVALID_ADDRESS');
        require(newCPI.k != 0, 'ParadoxV1: INVALID CPI DATA');
        address tokenA = _token0 < _token1 ? _token0 : _token1;
        address tokenB = _token0 < _token1 ? _token1 : _token0;
        getCPI[tokenA][tokenB] = newCPI;
    }

    /* FEE FUNCTIONS
    */
    function setFeeRecipient(address _feeRecipient) external {
        require(msg.sender == feeRecipient, 'ParadoxV1: FORBIDDEN');
        feeRecipient = _feeRecipient;
    }

    function setFeeRecipientSetter(address _feeRecipientSetter) external {
        require(msg.sender == feeRecipient, 'ParadoxV1: FORBIDDEN');
        feeRecipient = _feeRecipientSetter;
    }
}
