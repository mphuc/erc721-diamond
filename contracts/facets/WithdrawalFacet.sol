//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;
import "./../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract WithdrawalFacet is Modifiers {
    using SafeERC20 for IERC20;
    event WithdrawETH(address indexed account, uint256 amount);

    event WithdrawERC20(
        address indexed account,
        address indexed token,
        uint256 amount
    );

    function withdrawETH() external {
        uint256 balance = s.ethPending[msg.sender];
        s.ethPending[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
        emit WithdrawETH(msg.sender, balance);
    }

    function withdrawERC20(address token) external {
        uint256 balance = s.erc20Pending[token][msg.sender];
        s.erc20Pending[token][msg.sender] = 0;
        IERC20(token).safeTransfer(msg.sender, balance);
        emit WithdrawERC20(msg.sender, token, balance);
    }

    function pendingETH(address account) external view returns (uint256) {
        return s.ethPending[account];
    }

    function pendingERC20(address account, address token)
        external
        view
        returns (uint256)
    {
        return s.erc20Pending[token][account];
    }
}
