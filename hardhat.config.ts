import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  networks:{
    // arbitirum:{
      
    //   url: `https://arb-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
    //   accounts:[PK as string],
    //   chainId:42161
    // },
    //arbitrum: 42161,
    hardhat:{
      forking: {
        url: "https://compatible-still-liquid.bsc.discover.quiknode.pro/fa2e4bdba8c837b245a4a295301dedb23a7936ab/",
        blockNumber: 29722936,//29036648
      },
    },
  },
  solidity: {
    compilers:[
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999,
          },
        },
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999,
          },
        },
      },
    ],
  },
};

export default config;
// BSC: {
//   url: "https://compatible-still-liquid.bsc.discover.quiknode.pro/fa2e4bdba8c837b245a4a295301dedb23a7936ab/",
//   //url: "https://compatible-still-liquid.bsc.discover.quiknode.pro/fa2e4bdba8c837b245a4a295301dedb23a7936ab/",
//   //url:"https://1rpc.io/bnb",
//   accounts: [PRIVATE_KEY],
//   //allowUnlimitedContractSize: true,
//   //gasPrice: 8000000000000000
// },