//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;
import "./../libraries/UsingEIP712.sol";
import "hardhat-deploy/solc_0.8/diamond/libraries/LibDiamond.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract ERC721Init is UsingEIP712 {
    struct Init {
        string name;
        string symbol;
        string domainName;
        string version;
        address feeCollector;
        address defaultMinter;
    }

    function init(Init calldata data) external {
        s.name = data.name;
        s.symbol = data.symbol;
        s.domainName = data.domainName;
        s.version = data.version;
        s.feeCollector = data.feeCollector;
        s.supportsEther = true;
        s.roles[MINTER_ROLE].members[data.defaultMinter] = true;
        s.roles[DEFAULT_ADMIN_ROLE].members[msg.sender] = true;
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC721).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721Metadata).interfaceId] = true;
        ds.supportedInterfaces[type(IAccessControl).interfaceId] = true;

        bytes32 hashedName = keccak256(bytes(data.domainName));
        bytes32 hashedVersion = keccak256(bytes(data.domainName));
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        s._HASHED_NAME = hashedName;
        s._HASHED_VERSION = hashedVersion;
        s._CACHED_CHAIN_ID = block.chainid;
        s._CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(
            typeHash,
            hashedName,
            hashedVersion
        );
        s._CACHED_THIS = address(this);
        s._TYPE_HASH = typeHash;
    }
}
