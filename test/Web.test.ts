import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers } from "hardhat";

import DOXERC20 from "../artifacts/contracts/DOXERC20.sol/DOXERC20.json";
import DOXERC20Factory from "../artifacts/contracts/DOXERC20Factory.sol/DOXERC20Factory.json";
import ParadoxV1 from "../artifacts/contracts/ParadoxV1.sol/ParadoxV1.json";

let owner: SignerWithAddress;
let addr1: SignerWithAddress;
let addr2: SignerWithAddress;
let addrs: SignerWithAddress[];
let tokenFactoryAddress: string = "0xb0f05d25e41fbc2b52013099ed9616f1206ae21b";
let tokenAddress: string = "0x477fb3313e6858aa9833353ad3f84ff4795fd1c3";
let doxAddress: string = "0x5feaebfb4439f3516c74939a9d04e95afe82c4ae";
let accountAddress: string = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";

async function test() {
  [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

  const tokenFactory = new ethers.Contract(
    tokenFactoryAddress,
    DOXERC20Factory.abi,
    owner
  );
  const token = new ethers.Contract(tokenAddress, DOXERC20.abi, owner);
  const dox = new ethers.Contract(doxAddress, ParadoxV1.abi, owner);

  const balance = await token.balanceOf(accountAddress);
  console.log("balance: ", ethers.utils.formatEther(balance));

  const book = await dox.getBook(accountAddress, tokenAddress);
  console.log("book: ", ethers.utils.formatEther(book));
}

test();
