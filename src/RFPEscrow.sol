// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Escrow, IERC20, SafeERC20} from "../lib/openrd/src/Escrow.sol";
import {ITasks} from "../lib/openrd/src/ITasks.sol";

contract RFPEscrow is Escrow {
    using SafeERC20 for IERC20;

    /// @notice Initializes the additional RFP logic and performs the base Escrow init.
    function __RFPEscrow_init(ITasks _spender, ITasks.ERC20Transfer[] calldata _budget) public payable {
        __Escrow_init();

        for (uint256 i; i < _budget.length;) {
            // Approve unlimited spending by the Tasks contract to save on gas fees
            _budget[i].tokenContract.forceApprove(address(_spender), type(uint256).max);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice The Escrow created the task, so that any refunds will flow back to this, instead of the RFPs contract.
    /// They can be withdrawn if no further tasks are desired to be funded by calling emptyRFP.
    function createTask(
        ITasks _tasks,
        string calldata _metadata,
        uint64 _deadline,
        address _manager,
        address _disputeManager,
        uint96 _nativeBudget,
        ITasks.ERC20Transfer[] calldata _budget,
        ITasks.PreapprovedApplication[] calldata _preapprove
    ) external returns (uint256) {
        if (msg.sender != owner) {
            revert NotOwner();
        }

        return _tasks.createTask{value: _nativeBudget}(
            _metadata, _deadline, _manager, _disputeManager, _budget, _preapprove
        );
    }
}
