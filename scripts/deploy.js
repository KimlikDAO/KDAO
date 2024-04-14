import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as ethers from "ethers";
import { Wallet } from "zksync-ethers";

import dotenv from "dotenv";
dotenv.config();

/** @const {string} */
const PRIVATE_KEY = process.env.WALLET_PRIVATE_KEY || "";

if (!PRIVATE_KEY)
  throw "⛔️ Private key not detected! Add it to the .env file!";

/** @const {Array<any>} */
const CONSTRUCTOR_ARGS = [false];

console.log(`Running deploy script for the KDAO contract`);

// Initialize the wallet.

/** @const {Wallet} */
const wallet = new Wallet(PRIVATE_KEY);

// Create deployer object and load the artifact of the contract you want to deploy.
/** @const {Deployer} */
const deployer = new Deployer(hre, wallet);

/** @const {ZkSyncArtifact} */
const artifact = await deployer.loadArtifact("KDAO");

// Estimate contract deployment fee

/** @const {bigint} */
const deploymentFee = await deployer.estimateDeployFee(
  artifact,
  CONSTRUCTOR_ARGS
);

/** @const {bigint} */
const parsedFee = ethers.formatEther(deploymentFee);
console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

const greeterContract = await deployer.deploy(artifact, CONSTRUCTOR_ARGS);

console.log(
  "constructor args:" +
  greeterContract.interface.encodeDeploy(CONSTRUCTOR_ARGS)
);

/** @const {string} */
const contractAddress = await greeterContract.getAddress();
console.log(`${artifact.contractName} was deployed to ${contractAddress}`);

// Verify the contract on zkSync

/** @const {number} */
const verificationId = await hre.run("verify:verify", {
  address: contractAddress,
  contract: "contracts/KDAO.sol:KDAO",
  constructorArguments: CONSTRUCTOR_ARGS,
});

console.log(verificationId);

