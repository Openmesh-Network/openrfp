// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RFPEscrow, IERC20, SafeERC20} from "./RFPEscrow.sol";
import {ITasks} from "../lib/openrd-foundry/src/ITasks.sol";

interface IRFPs {
    error RFPDoesNotExist();
    error RFPClosed();
    error NotManager();
    error ProjectDoesNotExist();
    error ProjectAlreadyAccepted();
    error RewardDoesntEndWithNextToken();

    error Overflow();
    error ERC1167FailedCreateClone();

    event RFPCreated(
        uint256 indexed rfpId,
        string metadata,
        uint64 deadline,
        uint256 nativeBudget,
        ITasks.ERC20Transfer[] budget,
        address creator,
        address tasksManager,
        address disputeManager,
        address manager,
        RFPEscrow escrow
    );
    event ProjectSubmitted(
        uint256 indexed rfpId,
        uint32 projectId,
        string metadata,
        address representative,
        uint64 deadline,
        ITasks.NativeReward[] nativeReward,
        ITasks.Reward[] reward
    );
    event ProjectAccepted(
        uint256 indexed rfpId, uint32 projectId, uint96[] nativeReward, uint88[] reward, uint256 taskId
    );
    event RFPEmptied(uint256 indexed rfpId);

    /// @notice A container for a RFP project.
    /// @param metadata Metadata of the project. (IPFS hash)
    /// @param representative Who has submitted this project.
    /// @param deadline The deadline after which the project should be completed.
    /// @param accepted If the project has been accepted. To prevent 2 OpenR&D tasks from being created.
    /// @param nativeReward How much native currency the representative wants for completion.
    /// @param reward How much rewards the representative wants for completion.
    struct Project {
        string metadata;
        address representative;
        uint64 deadline;
        bool accepted;
        uint8 nativeRewardCount;
        uint8 rewardCount;
        mapping(uint8 => ITasks.NativeReward) nativeReward;
        mapping(uint8 => ITasks.Reward) reward;
    }

    struct OffchainProject {
        string metadata;
        address representative;
        uint64 deadline;
        bool accepted;
        ITasks.NativeReward[] nativeReward;
        ITasks.Reward[] reward;
    }

    /// @notice A container for RFP-related information.
    /// @param metadata Metadata of the RFP. (IPFS hash)
    /// @param deadline Block timestamp at which the RFP closes.
    /// @param budget The ERC20 contracts that compose the budget.
    /// @param creator Who has created the RFP.
    /// @param tasksManager Who has the permission to manage the OpenR&D tasks.
    /// @param disputeManager Who has the permission to manage disputes on the OpenR&D tasks.
    /// @param manager Who has the permission to manage the RFP.
    /// @param projects Projects that want to be funded by the RFP.
    struct RFP {
        string metadata;
        // Storage block separator
        uint64 deadline;
        RFPEscrow escrow;
        // Storage block separator
        address creator;
        // Storage block separator
        address tasksManager;
        // Storage block separator
        address disputeManager;
        // Storage block separator
        address manager;
        uint8 budgetCount;
        uint32 projectCount;
        // Storage block separator
        mapping(uint8 => IERC20) budget;
        mapping(uint32 => Project) projects;
    }

    struct OffChainRFP {
        string metadata;
        uint64 deadline;
        RFPEscrow escrow;
        address creator;
        address tasksManager;
        address disputeManager;
        address manager;
        IERC20[] budget;
        OffchainProject[] projects;
    }

    /// @notice Retrieves the current amount of created RFPs.
    function rfpCount() external view returns (uint256);

    /// @notice Retrieves all RFP information by id.
    /// @param _rfpId Id of the RFP.
    function getRFP(uint256 _rfpId) external view returns (OffChainRFP memory);

    /// @notice Retrieves multiple RFPs.
    /// @param _rfpIds Ids of the RFPs.
    function getRFPs(uint256[] calldata _rfpIds) external view returns (OffChainRFP[] memory);

    /// @notice Create a new RFP.
    /// @param _metadata Metadata of the RFP. (IPFS hash)
    /// @param _deadline Block timestamp at which the RFP closes.
    /// @param _budget Maximum ERC20 rewards available for projects of the RFP.
    /// @param _tasksManager Who will manage the project Tasks (become the OpenR&D manager).
    /// @param _manager Who will manage the RFP (become the manager).
    /// @return rfpId Id of the newly created RFP.
    function createRFP(
        string calldata _metadata,
        uint64 _deadline,
        ITasks.ERC20Transfer[] calldata _budget,
        address _tasksManager,
        address _disputeManager,
        address _manager
    ) external payable returns (uint256 rfpId);

    /// @notice Propose a project to be funded by an RFP.
    /// @param _rfpId Id of the RFP.
    /// @param _metadata Metadata of your project.
    /// @param _deadline Before when the proposed project will be completed.
    /// @param _nativeReward Wanted native currency from the RFP for the project.
    /// @param _reward Wanted rewards from the RFP for the project.
    function submitProject(
        uint256 _rfpId,
        string calldata _metadata,
        uint64 _deadline,
        ITasks.NativeReward[] calldata _nativeReward,
        ITasks.Reward[] calldata _reward
    ) external returns (uint32 projectId);

    /// @notice Accept project to be funded by the RFP.
    /// @param _rfpId Id of the RFP.
    /// @param _projectId Id of the project to accept.
    /// @param _nativeReward Native reward granted to the project (can be lower or higher than requested).
    /// @param _reward Reward granted to the project (can be lower or higher than requested).
    function acceptProject(
        uint256 _rfpId,
        uint32 _projectId,
        uint96[] calldata _nativeReward,
        uint88[] calldata _reward
    ) external;

    /// @notice Refunds any leftover budget to the creator.
    /// @param _rfpId Id of the RFP.
    function emptyRFP(uint256 _rfpId) external;
}
