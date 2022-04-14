import { expect } from "chai";
import { deployments, ethers, getNamedAccounts } from "hardhat";

describe("ERC721 Diamond", function () {
  it("test", async function () {
    await deployments.fixture("ERC721Diamond");
    const { deployer } = await getNamedAccounts();
    const ERC721Diamond = await deployments.get("ERC721Diamond");
    console.log(ERC721Diamond.facets);
    const ERC721Contract = await ethers.getContract("ERC721Diamond", deployer);
    console.log(ERC721Contract);
    // expect(await ERC721Contract.supportsInterface("0x80ac58cd")).to.be.true;
    // expect(await ERC721Contract.supportsInterface("0x5b5e139f")).to.be.true;
  });
});
