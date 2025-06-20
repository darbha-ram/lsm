require("./lsmtasks.config")
require("@nomicfoundation/hardhat-ethers");

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

// Notes:
// 1. added "hardhat" and "localhost" networks, to allow EVM testing locally in Hardhat
// 2. added accounts in 'opencbdc' network
// 3. lsmtasks.config.js is included _before_ the customary include of hardhat-ethers
//


/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        // RamD: change from 0.8.17, to permit compilation of newer solidity code. Enable
        //     optimization to decrease size of compiled contracts, since SablierFlow
        //     runs into error about too big to deploy.
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },

      },
    ],
  },
  allowUnlimitedContractSize: true,

  defaultNetwork: "opencbdc",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,          // TBD - doesn't do anything?
    },                                           // local testing
    localhost: {
      url:"http://127.0.0.1:8545",               // local hardhat node
      allowUnlimitedContractSize: true,
    },
    opencbdc: {
      // This URL is the PArSEC agent Node endpoint
      // NOTE: "localhost" (instead of 127.0.0.1) may work on some systems
      url: "http://127.0.0.1:8888/",

      // RamD: add private keys of Hardhat testing accounts
      accounts: ["59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", // CoA1
                 "5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a", // CorrA
                 "7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6", // CorrB
                 "47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a" // CoB1
      ]
    }
  }
};

