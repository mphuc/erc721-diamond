import { expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";
import { callDiamond } from "../scripts/callDiamond";
import { deployFacet } from "../scripts/deployFacet";
import { getSelectors } from "../scripts/helpers";

describe("ERC721 Diamond", function () {
  before(async () => {
    const [deployer] = await ethers.getSigners();
    this.ctx.deployer = deployer;
    const facetNames = [
      { name: "AccessControlFacet", address: "" },
      { name: "ERC721URIStorage", address: "" },
      { name: "RentalFacet", address: "" },
      { name: "UnderlyingCurrencyFacet", address: "" },
      { name: "WithdrawalFacet", address: "" },
    ];
    const facets: Record<string, Contract> = {};
    const cuts: any[] = [];
    for (const facet of facetNames) {
      const deployedFacet = await deployFacet({ name: facet.name }, deployer);
      facets[facet.name] = deployedFacet;
      cuts.push({
        facetAddress: deployedFacet.address,
        functionSelectors: getSelectors(deployedFacet.interface),
        action: 0,
      });
    }
    this.ctx.newCuts = cuts;
    this.ctx.facets = facets;
    this.ctx.diamondAddress = "0x486a92035a73de83f393DBfFa2C1a72e047203E9";
  });
  it("remove cuts", async function () {
    const facetsKept = [
      "0x3CcAe8D3F0f59B1A50540d7fbed9a40Fd23ab719", // diamond cut
      "0xf3587E542eF8752dd455ED9900a9AF316B23378d", // diamond Loupe
      "0x1fcf146989FDd0C7A928e124e869E3F91A17A8E4", // ownership
    ];

    const facetsToRemove = (
      await callDiamond({
        address: this.diamondAddress,
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
      "DiamondCutFacet",
      this.diamondAddress
    );
    const tx = await diamond.diamondCut(
      removeCuts,
      ethers.constants.AddressZero,
      "0x"
    );
    await tx.wait();
    const facets = await callDiamond({
      address: this.diamondAddress,
      name: "ERC721Diamond",
      execute: {
        functionName: "facets()",
        args: [],
      },
    });
    expect(facets[0]).to.have.lengthOf(3);
  });
  it("add new cut", async () => {
    const initParams = {
      name: "Virtual Reality Lands",
      symbol: "vrLands",
      domainName: "bizverse-vrLands",
      version: "1",
      defaultMinter: this.ctx.deployer.address,
    };
    const ERC721Init = await ethers.getContractFactory(
      "ERC721Init",
      this.ctx.deployer
    );
    const initializer = await ERC721Init.deploy();
    await initializer.deployed();
    const diamond = await ethers.getContractAt(
      "DiamondCutFacet",
      this.ctx.diamondAddress
    );

    const tx = await diamond.diamondCut(
      this.ctx.newCuts,
      initializer.address,
      initializer.interface.encodeFunctionData("init", [initParams])
    );
    await tx.wait();
  });
  after(async () => {
    const ERC721Diamond = await ethers.getContractAt(
      "ERC721Diamond",
      this.ctx.diamondAddress
    );
    const userAddress = "0xA80Ca12BD13bF726C0fD127416d0cFa66bc33451";
    const usdtAddress = "0x4988a896b1227218e4a686fde5eabdcabd91571f";
    expect(await ERC721Diamond.balanceOf(userAddress)).to.eq(2);
    expect(await ERC721Diamond.owner()).to.eq(this.ctx.deployer.address);
    expect(
      await ERC721Diamond.pendingERC20(this.ctx.deployer.address, usdtAddress)
    ).to.gt(0);
    expect(await ERC721Diamond.pendingETH(this.ctx.deployer.address)).to.gt(0);

    const ERC721Holder = await (
      await ethers.getContractFactory("Greeter")
    ).deploy("Hello");

    await expect(ERC721Diamond.mint(ERC721Holder.address, 999, "fake")).to.not
      .reverted;

    await expect(ERC721Diamond.mint(this.ctx.deployer.address, 1000, "fake")).to
      .not.reverted;
  });
});
