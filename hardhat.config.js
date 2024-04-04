require("@matterlabs/hardhat-zksync-deploy");
require("@matterlabs/hardhat-zksync-verify");
require("@matterlabs/hardhat-zksync-solc");
require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  zksolc: {
    version: "1.4.0", // Uses latest available in https://github.com/matter-labs/zksolc-bin/
    settings: {},
  },
  solidity: {
    version: "0.8.24",
    eraVersion: "1.0.0", //optional. Compile contracts with EraVM compiler
  },
  defaultNetwork: "zkSyncTestnet",
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/<API_KEY>", // The Ethereum Web3 RPC URL (optional).
      zksync: false, // disables zksolc compiler
    },
    zkSyncTestnet: {
      url: "https://sepolia.era.zksync.dev", // The testnet RPC URL of zkSync Era network.
      ethNetwork: "sepolia", // The Ethereum Web3 RPC URL, or the identifier of the network (e.g. `mainnet` or `sepolia`)
      zksync: true, // enables zksolc compiler
      verifyURL:
        "https://explorer.sepolia.era.zksync.dev/contract_verification",
    },
  },
  sourcify: {
    enabled: true,
  },
};
