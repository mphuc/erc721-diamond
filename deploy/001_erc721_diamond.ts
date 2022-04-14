import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { diamond } = deployments;

  const { deployer, feeCollector } = await getNamedAccounts();

  const initConfig = {
    name: "NFT",
    symbol: "NFT",
    domainName: "TestNFT",
    version: "1",
    feeCollector: feeCollector,
    defaultMinter: deployer,
  };

  await diamond.deploy("ERC721Diamond", {
    from: deployer,
    facets: [
      "ERC721Facet",
      "AccessControlFacet",
      "RentalFacet",
      "UnderlyingCurrencyFacet",
      "WithdrawalFacet",
    ],

    execute: {
      contract: "ERC721Init",
      methodName: "init",
      args: [initConfig],
    },
    log: true,
    autoMine: true, // speed up deployment on local network (ganache, hardhat), no effect on live networks
  });
};
export default func;
func.tags = ["ERC721Diamond"];
