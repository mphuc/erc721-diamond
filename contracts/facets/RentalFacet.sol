//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;
import "./../libraries/LibAppStorage.sol";
import "./../libraries/UsingEIP712.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RentalFacet is UsingEIP712 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    event RentalCreated(
        uint256 tokenId,
        address indexed owner,
        address indexed renter,
        address indexed currency,
        uint64 startingTimestamp,
        uint64 unitOfTime,
        uint32 numberOfUnits
    );

    event RentalRefund(
        uint256 tokenId,
        address indexed owner,
        address indexed renter,
        uint256 amount
    );

    event RentalEnd(
        uint256 tokenId,
        address indexed owner,
        address indexed renter
    );

    function rent(
        RentalAgreement calldata agreement,
        bytes calldata ownerSignature,
        bytes calldata renterSignature
    ) external {
        // CHECKS
        address rentalOwner;
        address renter;
        IERC20 token = IERC20(agreement.currency);
        uint256 total;
        {
            require(
                agreement.numberOfUnits > 0 && agreement.unitOfTime >= 1 hours
            );
            require(agreement.deadline >= block.timestamp);
            require(!_isRenting(agreement.tokenId));

            {
                rentalOwner = _verifyAgreement(agreement, ownerSignature);
                renter = _verifyAgreement(agreement, renterSignature);
            }
            require(
                msg.sender == renter &&
                    rentalOwner == s.erc721Owners[agreement.tokenId] &&
                    rentalOwner != address(0)
            );
            require(
                agreement.currency != address(0) &&
                    s.supportsCurrency[agreement.currency]
            );
            total = agreement.pricePerUnit.mul(agreement.numberOfUnits);
            require(token.allowance(msg.sender, address(this)) >= total);
        }

        // EFFECTS
        {
            uint256 before = s.erc20Pending[address(token)][rentalOwner];
            s.erc20Pending[address(token)][rentalOwner] = before.add(total);

            // clear approvals
            _transfer(rentalOwner, renter, agreement.tokenId);
            s.rentals[agreement.tokenId] = Rental({
                agreement: agreement,
                owner: rentalOwner,
                renter: renter,
                startingTimestamp: uint64(block.timestamp)
            });
        }

        // INTERACTIONS
        token.safeTransferFrom(msg.sender, address(this), total);
        emit RentalCreated(
            agreement.tokenId,
            rentalOwner,
            renter,
            agreement.currency,
            uint64(block.timestamp),
            agreement.unitOfTime,
            agreement.numberOfUnits
        );
    }

    function endRental(
        RentalPayback calldata payback,
        bytes calldata ownerSignature
    ) external {
        // CHECKS
        require(payback.deadline >= block.timestamp);
        require(_isRenting(payback.tokenId));
        address signer = _verifyPayback(payback, ownerSignature);
        require(signer == s.rentals[payback.tokenId].owner);
        Rental memory rental = s.rentals[payback.tokenId];
        if (payback.paybackAmount > 0) {
            IERC20 token = IERC20(rental.agreement.currency);
            require(
                token.allowance(rental.owner, address(this)) >=
                    payback.paybackAmount
            );

            uint256 before = s.erc20Pending[address(token)][rental.renter];
            s.erc20Pending[address(token)][rental.renter] = before.add(
                payback.paybackAmount
            );

            token.safeTransferFrom(
                rental.owner,
                address(this),
                payback.paybackAmount
            );
        }
        _transfer(rental.renter, rental.owner, payback.tokenId);
        delete s.rentals[payback.tokenId];
        assert(!_isRenting(payback.tokenId));
        emit RentalEnd(payback.tokenId, rental.renter, rental.owner);
        emit RentalRefund(
            payback.tokenId,
            rental.owner,
            rental.renter,
            payback.paybackAmount
        );
    }

    function revoke(uint256 tokenId) external {
        Rental memory rental = s.rentals[tokenId];
        require(msg.sender == rental.owner);
        require(_isRenting(tokenId));
        uint256 duration = uint256(rental.agreement.unitOfTime).mul(
            rental.agreement.numberOfUnits
        );
        require(
            block.timestamp > uint256(rental.startingTimestamp).add(duration)
        );
        _transfer(rental.renter, rental.owner, tokenId);
        delete s.rentals[tokenId];
        assert(!_isRenting(tokenId));
        emit RentalEnd(tokenId, rental.renter, rental.owner);
    }

    function onRenting(uint256 tokenId) public view returns (bool) {
        return _isRenting(tokenId);
    }

    function getRental(uint256 tokenId) public view returns (Rental memory) {
        require(_isRenting(tokenId));
        return s.rentals[tokenId];
    }

    function _isRenting(uint256 tokenId) internal view returns (bool) {
        return
            s.rentals[tokenId].owner != address(0) &&
            s.rentals[tokenId].renter != address(0);
    }

    function _verifyPayback(
        RentalPayback calldata payback,
        bytes calldata signature
    ) internal view returns (address) {
        bytes32 digest = _hashPayback(payback);
        return ECDSA.recover(digest, signature);
    }

    function _hashPayback(RentalPayback calldata payback)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        PAYBACK_TYPEHASH,
                        payback.tokenId,
                        payback.paybackAmount,
                        payback.renter,
                        payback.deadline
                    )
                )
            );
    }

    function _verifyAgreement(
        RentalAgreement calldata agreement,
        bytes calldata signature
    ) internal view returns (address) {
        bytes32 digest = _hashAgreement(agreement);
        return ECDSA.recover(digest, signature);
    }

    function _hashAgreement(RentalAgreement calldata agreement)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        AGREEMENT_TYPEHASH,
                        agreement.tokenId,
                        agreement.pricePerUnit,
                        agreement.currency,
                        agreement.unitOfTime,
                        agreement.deadline,
                        agreement.numberOfUnits
                    )
                )
            );
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        s.erc721TokenApprovals[tokenId] = address(0);
        s.erc721Balances[from] -= 1;
        s.erc721Balances[to] += 1;
        s.erc721Owners[tokenId] = to;
    }
}
