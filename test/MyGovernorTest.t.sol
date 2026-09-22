// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyGovernorTest is Test {
    Box box;
    GovToken govToken;
    MyGovernor governor;
    TimeLock timelock;

    address public user = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    // NOTE: on Ethereum, we assume a block takes 12 seconds to be comleted
    // Therefore 3600 * 12 = 43,200 i.e The MIN_DELAY == 12 hours and NOT actually 2 hours (3600sec)
    uint256 public constant MIN_DELAY = 3600;
    uint256 public VOTING_DELAY;
    uint256 public VOTING_PERIOD;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(user, INITIAL_SUPPLY);

        vm.startPrank(user);
        // having token != can vote, you delegate your token to whoever(in this case ourself) in oder to have voting power
        govToken.delegate(user);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timelock);

        // Get the different roles
        bytes32 proposarRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        // Grant roles
        timelock.grantRole(proposarRole, address(governor)); // only governor can propose
        timelock.grantRole(executorRole, address(0)); // anyone can execute
        timelock.revokeRole(adminRole, user); // user will no longer be the admin
        vm.stopPrank();

        box = new Box();
        // DAO(MyGovernor) owns -> TimeLock owns -> Box
        box.transferOwnership(address(timelock));

        VOTING_DELAY = governor.votingDelay(); // 7200 - 1 day before a proposal is active for voting
        VOTING_PERIOD = governor.votingPeriod(); // 50400 - 1 Week before it can be executed, exactly how it's implemented in Governor
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSelector(Box.store.selector, valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // View the state of the proposal
        console.log("Delay: ", VOTING_DELAY);
        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        // 2. Vote on proposal
        string memory reason = "Whatever reason you like";

        // enum VoteType{
        //     Against, // 0
        //     For,     // 1
        //     Abstain, // 2
        // }

        uint8 voteWay = 1; // voting yes
        vm.prank(user);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the Tx - Proposal has passed but we have to wait
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute the TX
        governor.execute(targets, values, calldatas, descriptionHash);

        assert(box.getNumber() == valueToStore);
        console.log("Box Value: ", box.getNumber());
    }
}
