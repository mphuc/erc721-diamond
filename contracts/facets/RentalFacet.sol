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

    function storageLayout() internal pure returns (RentalData storage) {
        return LibAppStorage.RentalStorage();
    }

    function rent(
        RentalAgreement calldata agreement,
        bytes calldata ownerSignature,
        bytes calldata renterSignature
    ) external {
        // CHECKS
        Rental memory rental;
        ERC721Data storage ed = LibAppStorage.ERC721Storage();
        WithdrawalData storage wd = LibAppStorage.WithdrawalStorage();
        CurrencyData storage cd = LibAppStorage.CurrencyStorage();
        RentalData storage rd = LibAppStorage.RentalStorage();

        {
            require(
                agreement.numberOfUnits > 0 && agreement.unitOfTime >= 1 hours
            );
            require(agreement.deadline >= block.timestamp);
            require(!_isRenting(agreement.tokenId));

            address rentalOwner = _verifyAgreement(agreement, ownerSignature);
            address renter = _verifyAgreement(agreement, renterSignature);

            require(
                msg.sender == renter &&
                    rentalOwner == ed.owners[agreement.tokenId] &&
                    rentalOwner != address(0)
            );
            require(
                agreement.currency != address(0) &&
                    cd.supportsCurrency[agreement.currency]
            );
            require(
                IERC20(agreement.currency).allowance(
                    msg.sender,
                    address(this)
                ) >= agreement.pricePerUnit.mul(agreement.numberOfUnits)
            );
            rental = Rental({
                agreement: agreement,
                owner: rentalOwner,
                renter: renter,
                startingTimestamp: uint64(block.timestamp)
            });
        }

        // EFFECTS
        {
            wd.erc20Pending[rental.agreement.currency][rental.owner] = wd
            .erc20Pending[rental.agreement.currency][rental.owner].add(
                    agreement.pricePerUnit.mul(agreement.numberOfUnits)
                );

            // clear approvals
            _transfer(rental.owner, rental.renter, rental.agreement.tokenId);
            rd.rentals[agreement.tokenId] = rental;
        }

        // INTERACTIONS
        IERC20(rental.agreement.currency).safeTransferFrom(
            msg.sender,
            address(this),
            agreement.pricePerUnit.mul(agreement.numberOfUnits)
        );
        emit RentalCreated(
            rental.agreement.tokenId,
            rental.owner,
            rental.renter,
            rental.agreement.currency,
            uint64(block.timestamp),
            rental.agreement.unitOfTime,
            rental.agreement.numberOfUnits
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
        WithdrawalData storage wd = LibAppStorage.WithdrawalStorage();
        RentalData storage rd = LibAppStorage.RentalStorage();
        require(signer == rd.rentals[payback.tokenId].owner);
        Rental memory rental = rd.rentals[payback.tokenId];
        if (payback.paybackAmount > 0) {
            IERC20 token = IERC20(rental.agreement.currency);
            require(
                token.allowance(rental.owner, address(this)) >=
                    payback.paybackAmount
            );

            uint256 before = wd.erc20Pending[address(token)][rental.renter];
            wd.erc20Pending[address(token)][rental.renter] = before.add(
                payback.paybackAmount
            );

            token.safeTransferFrom(
                rental.owner,
                address(this),
                payback.paybackAmount
            );
        }
        _transfer(rental.renter, rental.owner, payback.tokenId);
        delete rd.rentals[payback.tokenId];
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
        RentalData storage rd = LibAppStorage.RentalStorage();
        Rental memory rental = rd.rentals[tokenId];
        require(msg.sender == rental.owner);
        require(_isRenting(tokenId));
        uint256 duration = uint256(rental.agreement.unitOfTime).mul(
            rental.agreement.numberOfUnits
        );
        require(
            block.timestamp > uint256(rental.startingTimestamp).add(duration)
        );
        _transfer(rental.renter, rental.owner, tokenId);
        delete rd.rentals[tokenId];
        assert(!_isRenting(tokenId));
        emit RentalEnd(tokenId, rental.renter, rental.owner);
    }

    function isRenting(uint256 tokenId) public view returns (bool) {
        return _isRenting(tokenId);
    }

    function getRental(uint256 tokenId) public view returns (Rental memory) {
        require(_isRenting(tokenId));
        return storageLayout().rentals[tokenId];
    }

    function _isRenting(uint256 tokenId) internal view returns (bool) {
        return
            storageLayout().rentals[tokenId].owner != address(0) &&
            storageLayout().rentals[tokenId].renter != address(0);
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
        ERC721Data storage ed = LibAppStorage.ERC721Storage();
        ed.tokenApprovals[tokenId] = address(0);
        ed.balances[from] -= 1;
        ed.balances[to] += 1;
        ed.owners[tokenId] = to;
    }
}
