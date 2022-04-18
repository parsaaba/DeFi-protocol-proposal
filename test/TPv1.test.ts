import {
  ContractFactory,
  Contract,
  ContractReceipt,
  ContractTransaction,
  Event,
} from "@ethersproject/contracts";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { Address } from "cluster";
import { ethers } from "hardhat";

describe("TPv1 contract", function () {
  // `before`, `beforeEach`, `after`, `afterEach`.

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addrs: SignerWithAddress[];

  let tokenFactory: ContractFactory;
  let token1: Contract;
  let token2: Contract;
  let tpFactory: ContractFactory;
  let tp: Contract;

  var account2 = ethers.Wallet.createRandom();

  before(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    // console.log("Created signers. Owner:", owner.address);

    // Deploy the test ERC20 token
    tokenFactory = await ethers.getContractFactory("DOXERC20");
    token1 = await tokenFactory.deploy("BASH token", "BASH", owner.address);
    token2 = await tokenFactory.deploy("DASH token", "DASH", owner.address);
    console.log("Deployed tokens");

    // Deploy the TP Wallet
    tpFactory = await ethers.getContractFactory("TPv1");
    tp = await tpFactory.deploy();
    console.log("Deployed TP");

    // Approve and transfer 100 from ERC20 to TP Wallet
    await token1.approve(tp.address, 100);
    await tp.deposit(token1.address, 100);
    console.log(
      "Deployed TP Wallet and deposited initial 100 to owner on token1"
    );
  });

  describe("Deployment", function () {
    it("Should have set the right owner", async function () {
      expect(await tp.owner()).to.equal(owner.address);
    });
  });

  describe("Balance", function () {
    it("Should have book value of 100 erc20 for sender", async function () {
      const book = await tp.getBook(owner.address, token1.address);
      expect(book).to.equal(100);
    });

    it("Should have token balance of 49900 for sender on deployed erc20", async function () {
      const balance = await token1.balanceOf(owner.address);
      expect(balance).to.equal(49900);
    });
  });

  describe("Deposit", function () {
    it("Should have deposited 100 more for a book value of 200 for sender on erc20", async function () {
      await token1.approve(tp.address, 100);
      await tp.deposit(token1.address, 100);
      const book = await tp.getBook(owner.address, token1.address);
      expect(book).to.equal(200);
    });
  });

  describe("Balance", function () {
    it("Should have book value of 200 erc20 for sender", async function () {
      const book = await tp.getBook(owner.address, token1.address);
      expect(book).to.equal(200);
    });

    it("Should have token balance of 49800 for sender on deployed erc20", async function () {
      const balance = await token1.balanceOf(owner.address);
      expect(balance).to.equal(49800);
    });
  });

  // describe("Transfer", function () {
  //   it("Should have transferred 30 from owner", async function () {
  //     await tp.transfer(token1.address, account2.address, 30);
  //     const book = await tp.getBook(owner.address, token1.address);
  //     expect(book).to.equal(170);
  //   });
  //   it("Should have transferred 30 to account2", async function () {
  //     const book = await tp.getBook(account2.address, token1.address);
  //     expect(book).to.equal(30);
  //   });
  // });

  // describe("Mint", function () {
  //   it("Should have minted an TP token with symbol nDASH", async function () {
  //     await tp.mint("nDASH");
  //     const tpOwner = await tp.getTpOwner("nDASH");
  //     expect(tpOwner).to.equal(owner.address);
  //   });
  // });

  // describe("Fill", function () {
  //   it("Should have filled the TP token with 100 erc20", async function () {
  //     await tp.fill("nDASH", token1.address, 100);
  //     const tpBalance = await tp.getTp("nDASH", token1.address);
  //     expect(tpBalance).to.equal(100);
  //   });
  // });

  // describe("Balance", function () {
  //   it("Should have book value of 70 erc20 for sender", async function () {
  //     const book = await tp.getBook(owner.address, token1.address);
  //     expect(book).to.equal(70);
  //   });
  // });

  // describe("Drain", function () {
  //   it("Should have drained the TP token down to 40 erc20", async function () {
  //     await tp.drain("nDASH", token1.address, 60);
  //     const tpBalance = await tp.getTp("nDASH", token1.address);
  //     expect(tpBalance).to.equal(40);
  //   });
  // });

  // describe("Balance", function () {
  //   it("Should have book value of 130 erc20 for sender", async function () {
  //     const book = await tp.getBook(owner.address, token1.address);
  //     expect(book).to.equal(130);
  //   });
  // });

  // describe("Assign", function () {
  //   it("Should have assigned TP token from owner to account2", async function () {
  //     // const ns = Array.from(Array(2000).keys());
  //     // ns.forEach(async (n) => await tp.mint("nDASH" + n));
  //     await tp.assign("nDASH", account2.address);
  //     const tpOwner = await tp.getTpOwner("nDASH");
  //     expect(tpOwner).to.equal(account2.address);
  //   });
  // });

  // describe("Withdraw", function () {
  //   it("Should have withdrawn 100 for sender on erc20", async function () {
  //     await tp.withdraw(token1.address, 100);
  //     const book = await tp.getBook(owner.address, token1.address);
  //     expect(book).to.equal(30);
  //   });
  // });

  // describe("Balance", function () {
  //   it("Should have book value of 30 erc20 for sender", async function () {
  //     const book = await tp.getBook(owner.address, token1.address);
  //     expect(book).to.equal(30);
  //   });

  //   it("Should have token balance of 400 for sender on deployed erc20", async function () {
  //     const balance = await token1.balanceOf(owner.address);
  //     expect(balance).to.equal(400);
  //   });
  // });
});
