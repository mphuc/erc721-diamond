//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;
import "./../libraries/LibAppStorage.sol";

contract UnderlyingCurrencyFacet is Modifiers {
    event CurrencySet(address tokenAddress, bool flag);

    function setCurrency(address tokenAddress, bool flag) external onlyOwner {
        if (tokenAddress == address(0)) {
            s.supportsEther = flag;
        } else {
            s.supportsCurrency[tokenAddress] = flag;
        }
        emit CurrencySet(tokenAddress, flag);
    }

    function supportsCurrency(address tokenAddress)
        external
        view
        returns (bool)
    {
        return
            tokenAddress == address(0)
                ? s.supportsEther
                : s.supportsCurrency[tokenAddress];
    }
}
