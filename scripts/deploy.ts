import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const tokenFactoryFactory = await ethers.getContractFactory(
    "DOXERC20Factory"
  );
  const tokenFactory = await tokenFactoryFactory.deploy();
  console.log("ERC20Factory address:", tokenFactory.address);

  const doxFactory = await ethers.getContractFactory("ParadoxV1");
  const dox = await doxFactory.deploy();
  console.log("ParadoxV1 address: ", dox.address);

  // // Deploy the test ERC20 token
  // const tokenFactory = await ethers.getContractFactory("DOXERC20");
  // const token1 = await tokenFactory.deploy(
  //   "BASH token",
  //   "BASH",
  //   deployer.address,
  //   50000000
  // );
  // const token2 = await tokenFactory.deploy(
  //   "CASH token",
  //   "CASH",
  //   deployer.address,
  //   50000000
  // );
  // const token3 = await tokenFactory.deploy(
  //   "DASH token",
  //   "DASH",
  //   deployer.address,
  //   50000000
  // );
  // console.log(
  //   "Deployed tokens: ",
  //   token1.address,
  //   token2.address,
  //   token3.address
  // );
  // console.log(
  //   "token1 supply: ",
  //   ethers.BigNumber.from(await token1.totalSupply()).toString()
  // );

  // const doxFactory = await ethers.getContractFactory("ParadoxV1");
  // const dox = await doxFactory.deploy(
  //   token1.address,
  //   token2.address,
  //   token3.address
  // );
  // console.log("dox address:", dox.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
