const { Wallet, utils } = require("zksync-ethers");
const ethers = require("ethers");
const { Deployer } = require("@matterlabs/hardhat-zksync-deploy");

// load env file
const dotenv = require("dotenv");
dotenv.config();

// load wallet private key from env file
const PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY || "";

if (!PRIVATE_KEY)
  throw "⛔️ Private key not detected! Add it to the .env file!";

// An example of a deploy script that will deploy and call a simple contract.

async function main() {
  console.log(`Running deploy script for the KDAO contract`);

  // Initialize the wallet.
  const wallet = new Wallet(PRIVATE_KEY);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("KDAO");

  // Estimate contract deployment fee
  const greeting = "Hi there!";
  const deploymentFee = await deployer.estimateDeployFee(artifact, [false]);

  // ⚠️ OPTIONAL: You can skip this block if your account already has funds in L2
  // const depositHandle = await deployer.zkWallet.deposit({
  //   to: deployer.zkWallet.address,
  //   token: utils.ETH_ADDRESS,
  //   amount: deploymentFee.mul(2),
  // });
  // // Wait until the deposit is processed on zkSync
  // await depositHandle.wait();

  // Deploy this contract. The returned object will be of a `Contract` type, similar to ones in `ethers`.
  // `greeting` is an argument for contract constructor.
  const parsedFee = ethers.formatEther(deploymentFee);
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const greeterContract = await deployer.deploy(artifact, [false]);

  //obtain the Constructor Arguments
  console.log(
    "constructor args:" + greeterContract.interface.encodeDeploy([false])
  );

  // Show the contract info.
  const contractAddress = await greeterContract.getAddress();
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
}

main().catch((err) => console.log(err));
