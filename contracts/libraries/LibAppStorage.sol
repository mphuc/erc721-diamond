//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "hardhat-deploy/solc_0.8/diamond/UsingDiamondOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

bytes32 constant AGREEMENT_TYPEHASH = keccak256(
    "RentalAgreement(uint256 tokenId,uint256 pricePerUnit,address currency,uint64 unitOfTime,uint64 deadline,uint32 numberOfUnits)"
);

bytes32 constant MINTING_PERMISSION_TYPEHASH = keccak256(
    "MintingPermission(uint256 tokenId,address to,address currency,uint256 mintingPrice,string uri)"
);

bytes32 constant PAYBACK_TYPEHASH = keccak256(
    "RentalPayback(uint256 tokenId,uint256 paybackAmount,address renter,uint64 deadline)"
);

bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

struct MintingPermission {
    uint256 tokenId;
    address to;
    address currency;
    uint256 mintingPrice;
    string uri;
    bytes signature;
}

struct RentalAgreement {
    uint256 tokenId;
    uint256 pricePerUnit;
    address currency;
    uint64 unitOfTime;
    uint64 deadline;
    uint32 numberOfUnits;
}

struct Rental {
    address owner;
    address renter;
    uint64 startingTimestamp;
    RentalAgreement agreement;
}

struct RentalPayback {
    uint256 tokenId;
    uint256 paybackAmount;
    address renter;
    uint64 deadline;
}

struct RoleData {
    mapping(address => bool) members;
    bytes32 adminRole;
}

// DO NOT MODIFIY FIELDS ORDER
// JUST ADD NEW FIELDS
struct AppStorage {
    // for ERC721 metadata
    string name;
    string symbol;
    mapping(uint256 => address) erc721Owners;
    mapping(address => uint256) erc721Balances;
    mapping(uint256 => address) erc721TokenApprovals;
    mapping(address => mapping(address => bool)) erc721OperatorApprovals;
    mapping(uint256 => string) erc721TokenURIs;
    // for withdrawal
    mapping(address => uint256) ethPending;
    mapping(address => mapping(address => uint256)) erc20Pending;
    // for access control
    mapping(bytes32 => RoleData) roles;
    // for rental
    mapping(uint256 => Rental) rentals;
    // for EIP712
    string domainName;
    string version;
    bytes32 _CACHED_DOMAIN_SEPARATOR;
    uint256 _CACHED_CHAIN_ID;
    address _CACHED_THIS;
    bytes32 _HASHED_NAME;
    bytes32 _HASHED_VERSION;
    bytes32 _TYPE_HASH;
    // for underlying currency facet
    bool supportsEther;
    mapping(address => bool) supportsCurrency;
    address feeCollector;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage s) {
        assembly {
            s.slot := 0
        }
    }
}

contract Modifiers is UsingDiamondOwner, Context {
    AppStorage internal s;

    modifier onlyRole(bytes32 role) {
        require(
            s.roles[role].members[msg.sender],
            string(
                abi.encodePacked(
                    "AccessControl: account ",
                    Strings.toHexString(uint160(msg.sender), 20),
                    " is missing role ",
                    Strings.toHexString(uint256(role), 32)
                )
            )
        );
        _;
    }
}
