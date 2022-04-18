pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

// import 'hardhat/console.sol';

contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;
    address public feeToSetter;
    bytes32 public INIT_CODE_PAIR_HASH; // = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
        INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));
    }

    function getInitPairHash() external view returns (bytes32) {
        return INIT_CODE_PAIR_HASH;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // uint g0 = gasleft(); // GAS CALC
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // uint g1 = gasleft(); // GAS CALC
        // console.log("GAS: FACTORY: CREATE PAIR - TOKEN SORT:", g0 - g1); // GAS CALC
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        // uint g2 = gasleft(); // GAS CALC
        // console.log("GAS: FACTORY: CREATE PAIR - BYTECODE & SALT:", g1 - g2); // GAS CALC
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // uint g3 = gasleft(); // GAS CALC
        // console.log("GAS: FACTORY: CREATE PAIR - ADDRESS CREATE2:", g2 - g3); // GAS CALC
        IUniswapV2Pair(pair).initialize(token0, token1);
        // uint g4 = gasleft(); // GAS CALC
        // console.log("GAS: FACTORY: CREATE PAIR - PAIR INIT:", g3 - g4); // GAS CALC
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        // uint g5 = gasleft(); // GAS CALC
        // console.log("GAS: FACTORY: CREATE PAIR - PAIR STORAGE:", g4 - g5); // GAS CALC
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
