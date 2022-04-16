import { Signer } from "ethers";
import { ethers } from "hardhat";

export type Facet = {
  name: string;
  address: string;
  functionSelectors: string[];
};

export type Diamond = {
  name: string | any[];
  address: string;
  facets?: string[] | Facet[];
  execute: {
    functionName: string;
    args: any[];
  };
};

export const callDiamond = async (options: Diamond, caller?: Signer) => {
  const Diamond = await ethers.getContractAt(options.name, options.address);
  const result = await Diamond.functions[options.execute.functionName](
    options.execute.args
  );
  return result;
};
