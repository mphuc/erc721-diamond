import { Signer } from "ethers";
import { ethers } from "hardhat";

export type Facet = {
  name: string;
  address?: string;
  include?: string[];
  exclude?: string[];
};

export const deployFacet = async (options: Facet, deployer: Signer) => {
  if (!options.address) {
    const Facet = await ethers.getContractFactory(options.name, deployer);
    const facet = await Facet.deploy();
    await facet.deployed();
    console.log(`${options.name} is deployed at ${facet.address}`);
    return facet;
  } else {
    console.log(`${options.name} is deployed at ${options.address}`);
    return await ethers.getContractAt(options.name, options.address, deployer);
  }
};
