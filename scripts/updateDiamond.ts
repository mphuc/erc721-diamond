import { Contract } from "ethers";
import { ethers } from "hardhat";
import { callDiamond } from "./callDiamond";
import { deployFacet } from "./deployFacet";
import { getSelectors } from "./helpers";

const updateDiamond = async (
  inputs: { diamondAddress: string; domainName: string; version: string }[]
) => {
  const [deployer] = await ethers.getSigners();

  const facetNames = [
    {
      name: "AccessControlFacet",
      address: "0x306A633E9bB041a870D4473B6a2C7C72370c98de",
    },
    {
      name: "ERC721URIStorage",
      address: "0xE5717529108C0A355CAee17A1617841101712a51",
    },
    {
      name: "RentalFacet",
      address: "0xBe01fB9C126B62A028A01AF081e2C73658DECfF4",
    },
    {
      name: "UnderlyingCurrencyFacet",
      address: "0xAFA2Be01c42eFcac38dBaFfCeFcB78C7d5C89395",
    },
    {
      name: "WithdrawalFacet",
      address: "0xd107B75955e59e055ab59eCf7A8caB90D044d8B0",
    },
  ];

  const facets: Record<string, Contract> = {};
  const cuts: any[] = [];
  for (const facet of facetNames) {
    const deployedFacet = await deployFacet(
      { name: facet.name, address: facet.address },
      deployer
    );
    facets[facet.name] = deployedFacet;
    cuts.push({
      facetAddress: deployedFacet.address,
      functionSelectors: getSelectors(deployedFacet.interface),
      action: 0,
    });
  }
  const newCuts = cuts;

  const facetsKept = [
    "0x3CcAe8D3F0f59B1A50540d7fbed9a40Fd23ab719", // diamond cut
    "0xf3587E542eF8752dd455ED9900a9AF316B23378d", // diamond Loupe
    "0x1fcf146989FDd0C7A928e124e869E3F91A17A8E4", // ownership
  ];

  // const ERC721Init = await ethers.getContractFactory("ERC721Init", deployer);
  // const initializer = await ERC721Init.deploy();
  // await initializer.deployed();
  const initializer = await ethers.getContractAt(
    "ERC721Init",
    "0x1bf91f2F784EE2599e812e65865eB6BfE6201d6B"
  );

  for (const opts of inputs) {
    const facetsToRemove = (
      await callDiamond({
        address: opts.diamondAddress,
        name: "ERC721Diamond",
        execute: {
          functionName: "facets()",
          args: [],
        },
      })
    )[0].filter((e: any) => {
      return !facetsKept.includes(e.facetAddress);
    });
    const removeCuts = facetsToRemove.map((e: any) => {
      return {
        facetAddress: ethers.constants.AddressZero,
        functionSelectors: e.functionSelectors,
        action: 2,
      };
    });

    const diamond = await ethers.getContractAt(
      "ERC721Diamond",
      opts.diamondAddress
    );
    let tx = await diamond.diamondCut(
      removeCuts,
      ethers.constants.AddressZero,
      "0x"
    );
    await tx.wait();

    const initParams = {
      domainName: opts.domainName,
      version: opts.version,
    };
    tx = await diamond.diamondCut(
      newCuts,
      initializer.address,
      initializer.interface.encodeFunctionData("init", [initParams])
    );
    await tx.wait();

    console.log(`${opts.diamondAddress} ${opts.domainName} DONE!`);
  }
};

updateDiamond([
  {
    diamondAddress: "0xF1E98aF9743AB5aea46c53ae7172895fb348F1D1",
    domainName: "bizverse-vrLands",
    version: "1",
  },
  // {
  //   diamondAddress: "0x01812EBEFD998e27BD19A0578cB71b87d6E7c43D",
  //   domainName: "bizverse-vrStores",
  //   version: "1",
  // },
  // {
  //   diamondAddress: "0x5BF4017DFe679c13910236427509fd088f8D6138",
  //   domainName: "bizverse-vrMalls",
  //   version: "1",
  // },
  // {
  //   diamondAddress: "0x1797C36a07D234DC9e342fb828031f7Ed297e75F",
  //   domainName: "bizverse-vrHomes",
  //   version: "1",
  // },
  // {
  //   diamondAddress: "0x88976c2A0AF6f969d51E2e757AfD5bDaDaC5D6C5",
  //   domainName: "bizverse-vrStableNFTs",
  //   version: "1",
  // },
  // {
  //   diamondAddress: "0xF676974c0EC86E7169D5f3dD29889c6979e3D877",
  //   domainName: "bizverse-vrAssets",
  //   version: "1",
  // },
  // {
  //   diamondAddress: "0xa5DCBdbaB9a9268f754D80C9d98A47Fd4EbE2b2e",
  //   domainName: "bizverse-vr3DNFTs",
  //   version: "1",
  // },
  // {
  //   diamondAddress: "0x23447E29E39aA42aa444A70e248C1A4349E54409",
  //   domainName: "bizverse-charity",
  //   version: "1",
  // },
]).catch((err) => {
  throw err;
});
