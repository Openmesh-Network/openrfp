// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRFPs, IERC20, Escrow, ITasks, SafeERC20} from "./IRFPs.sol";

contract RFPs is IRFPs {
    using SafeERC20 for IERC20;

    /// @notice The Tasks deployment where accepted projects will be created.
    ITasks public immutable tasks;

    /// @notice The incremental ID for RFPs.
    uint256 private rfpCounter;

    /// @notice A mapping between RFP IDs and RFP information.
    mapping(uint256 => RFP) internal rfps;

    /// @notice The base escrow contract that will be cloned for every RFP.
    address public immutable escrowImplementation;

    constructor(ITasks _tasks) {
        tasks = _tasks;
        escrowImplementation = address(new Escrow());
    }

    receive() external payable {}

    /// @inheritdoc IRFPs
    function rfpCount() external view returns (uint256) {
        return rfpCounter;
    }

    /// @inheritdoc IRFPs
    function getRFP(uint256 _rfpId) public view returns (OffChainRFP memory offchainRFP) {
        RFP storage rfp = _getRFP(_rfpId);
        offchainRFP = _toOffchainRFP(rfp);
    }

    /// @inheritdoc IRFPs
    function getRFPs(uint256[] memory _rfpIds) public view returns (OffChainRFP[] memory) {
        OffChainRFP[] memory offchainRFPs = new OffChainRFP[](_rfpIds.length);
        for (uint256 i; i < _rfpIds.length;) {
            offchainRFPs[i] = getRFP(_rfpIds[i]);

            unchecked {
                ++i;
            }
        }
        return offchainRFPs;
    }

    /// @inheritdoc IRFPs
    function createRFP(
        string calldata _metadata,
        uint64 _deadline,
        ITasks.ERC20Transfer[] calldata _budget,
        address _tasksManager,
        address _disputeManager,
        address _manager
    ) external payable returns (uint256 rfpId) {
        rfpId = rfpCounter++;
        RFP storage rfp = rfps[rfpId];
        rfp.metadata = _metadata;
        rfp.deadline = _deadline;
        {
            Escrow escrow = Escrow(payable(clone(escrowImplementation)));
            escrow.__Escrow_init{value: msg.value}();
            rfp.escrow = escrow;
            // Gas optimization
            if (msg.value != 0) {
                rfp.nativeBudget = _toUint96(msg.value);
            }
            rfp.budgetCount = _toUint8(_budget.length);
            for (uint8 i; i < uint8(_budget.length);) {
                _budget[i].tokenContract.safeTransferFrom(msg.sender, address(escrow), _budget[i].amount);
                // use balanceOf in case there is a fee asoosiated with the transfer
                rfp.budget[i] = _budget[i].tokenContract;
                unchecked {
                    ++i;
                }
            }
        }

        rfp.manager = _manager;
        rfp.tasksManager = _tasksManager;
        rfp.disputeManager = _disputeManager;
        rfp.creator = msg.sender;

        emit RFPCreated(
            rfpId,
            _metadata,
            _deadline,
            _toUint96(msg.value),
            _budget,
            msg.sender,
            _tasksManager,
            _disputeManager,
            _manager
        );
    }

    /// @inheritdoc IRFPs
    function submitProject(
        uint256 _rfpId,
        string calldata _metadata,
        uint64 _deadline,
        ITasks.NativeReward[] calldata _nativeReward,
        ITasks.Reward[] calldata _reward
    ) external returns (uint32 projectId) {
        RFP storage rfp = _getRFP(_rfpId);

        // Ensure not past deadline
        if (rfp.deadline <= block.timestamp) {
            revert RFPClosed();
        }
        // Ensure reward ends with next token
        unchecked {
            if (_reward.length != 0 && !_reward[_reward.length - 1].nextToken) {
                revert RewardDoesntEndWithNextToken();
            }
        }

        projectId = rfp.projectCount++;
        Project storage project = rfp.projects[projectId];
        project.metadata = _metadata;
        project.deadline = _deadline;
        project.representative = msg.sender;

        // Gas optimization
        if (_nativeReward.length != 0) {
            project.nativeRewardCount = _toUint8(_nativeReward.length);
            for (uint8 i; i < uint8(_nativeReward.length);) {
                project.nativeReward[i] = _nativeReward[i];
                unchecked {
                    ++i;
                }
            }
        }

        // Gas optimization
        if (_reward.length != 0) {
            project.rewardCount = _toUint8(_reward.length);
            for (uint8 i; i < uint8(_reward.length);) {
                project.reward[i] = _reward[i];
                unchecked {
                    ++i;
                }
            }
        }

        emit ProjectSubmitted(_rfpId, projectId, _metadata, msg.sender, _deadline, _nativeReward, _reward);
    }

    /// @inheritdoc IRFPs
    function acceptProject(uint256 _rfpId, uint32 _projectId) external {
        RFP storage rfp = _getRFP(_rfpId);

        // Ensure sender is manager
        if (rfp.manager != msg.sender) {
            revert NotManager();
        }
        // Ensure project exists
        if (_projectId >= rfp.projectCount) {
            revert ProjectDoesNotExist();
        }

        Project storage project = rfp.projects[_projectId];

        // Ensure project not accepted
        if (project.accepted) {
            revert ProjectAlreadyAccepted();
        }

        uint96 taskNativeBudget;
        ITasks.NativeReward[] memory taskNativeReward = new ITasks.NativeReward[](project.nativeRewardCount);
        for (uint8 i; i < taskNativeReward.length;) {
            taskNativeReward[i] = project.nativeReward[i];
            taskNativeBudget += taskNativeReward[i].amount;

            unchecked {
                ++i;
            }
        }
        rfp.escrow.transferNative(payable(address(this)), taskNativeBudget);

        ITasks.ERC20Transfer[] memory taskBudget = new ITasks.ERC20Transfer[](rfp.budgetCount);
        ITasks.Reward[] memory taskReward = new ITasks.Reward[](project.rewardCount);
        {
            uint8 j;
            for (uint8 i; i < taskBudget.length;) {
                IERC20 erc20 = rfp.budget[i];
                uint96 projectBudget;
                while (j < taskReward.length) {
                    taskReward[j] = project.reward[j];
                    projectBudget += taskReward[j].amount;

                    unchecked {
                        ++j;
                    }

                    if (taskReward[j - 1].nextToken) {
                        break;
                    }
                }

                taskBudget[i] = ITasks.ERC20Transfer(erc20, projectBudget);
                rfp.escrow.transfer(erc20, address(this), projectBudget);
                erc20.forceApprove(address(tasks), projectBudget);

                unchecked {
                    ++i;
                }
            }
        }

        ITasks.PreapprovedApplication[] memory preapproved = new ITasks.PreapprovedApplication[](1);
        preapproved[0] = ITasks.PreapprovedApplication(project.representative, taskNativeReward, taskReward);

        uint256 taskId = tasks.createTask{value: taskNativeBudget}(
            project.metadata, project.deadline, rfp.tasksManager, rfp.disputeManager, taskBudget, preapproved
        );
        project.accepted = true;
        emit ProjectAccepted(_rfpId, _projectId, taskId);
    }

    /// @inheritdoc IRFPs
    function emptyRFP(uint256 _rfpId) external {
        RFP storage rfp = _getRFP(_rfpId);

        // Ensure sender is manager
        if (rfp.manager != msg.sender) {
            revert NotManager();
        }

        rfp.escrow.transferNative(payable(rfp.creator), address(rfp.escrow).balance);

        uint8 budgetCount = rfp.budgetCount;
        for (uint8 i; i < budgetCount;) {
            IERC20 erc20 = rfp.budget[i];

            rfp.escrow.transfer(erc20, rfp.creator, erc20.balanceOf(address(rfp.escrow)));

            unchecked {
                ++i;
            }
        }

        emit RFPEmptied(_rfpId);
    }

    function _getRFP(uint256 _rfpId) internal view returns (RFP storage rfp) {
        if (_rfpId >= rfpCounter) {
            revert RFPDoesNotExist();
        }

        rfp = rfps[_rfpId];
    }

    function _toOffchainRFP(RFP storage rfp) internal view returns (OffChainRFP memory offchainRFP) {
        offchainRFP.metadata = rfp.metadata;
        offchainRFP.deadline = rfp.deadline;
        offchainRFP.creator = rfp.creator;
        offchainRFP.tasksManager = rfp.tasksManager;
        offchainRFP.manager = rfp.manager;
        offchainRFP.escrow = rfp.escrow;
        offchainRFP.nativeBudget = rfp.nativeBudget;

        offchainRFP.budget = new IERC20[](rfp.budgetCount);
        for (uint8 i; i < offchainRFP.budget.length;) {
            offchainRFP.budget[i] = rfp.budget[i];
            unchecked {
                ++i;
            }
        }

        offchainRFP.projects = new OffchainProject[](rfp.projectCount);
        for (uint8 i; i < offchainRFP.projects.length;) {
            Project storage project = rfp.projects[i];
            offchainRFP.projects[i].metadata = project.metadata;
            offchainRFP.projects[i].deadline = project.deadline;
            offchainRFP.projects[i].representative = project.representative;
            offchainRFP.projects[i].accepted = project.accepted;

            offchainRFP.projects[i].nativeReward = new ITasks.NativeReward[](project.nativeRewardCount);
            for (uint8 j; j < offchainRFP.projects[i].nativeReward.length;) {
                offchainRFP.projects[i].nativeReward[j] = project.nativeReward[j];
                unchecked {
                    ++j;
                }
            }

            offchainRFP.projects[i].reward = new ITasks.Reward[](project.rewardCount);
            for (uint8 j; j < offchainRFP.projects[i].reward.length;) {
                offchainRFP.projects[i].reward[j] = project.reward[j];
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    // From: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/Clones.sol
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(0, 0x09, 0x37)
        }
        if (instance == address(0)) {
            revert ERC1167FailedCreateClone();
        }
    }

    function _toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert Overflow();
        }
        return uint8(value);
    }

    function _toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert Overflow();
        }
        return uint96(value);
    }
}
