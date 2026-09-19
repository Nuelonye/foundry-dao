// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGovernorTest is Test {
    Box box;
    GovToken govToken;
    MyGovernor myGovernor;
    TimeLock timelock;

    address public user = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    uint256 public MIN_DELAY;
    uint256 public VOTING_DELAY;
    uint256 public VOTING_PERIOD;

    function setUp() public {
        govToken = new GovToken(msg.sender);
        govToken.mint(user, INITIAL_SUPPLY);

        vm.startPrank(user);
        govToken.delegate(user);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        myGovernor = new MyGovernor(govToken, timelock);

        bytes32 proposarRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposarRole, address(myGovernor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, user);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));

        VOTING_DELAY = myGovernor.votingDelay(); // how many blocks till a vote is active
        VOTING_PERIOD = myGovernor.votingPeriod(); // This is one Week, exactly how it was implemented in Governor contract
        MIN_DELAY = timelock.getMinDelay(); // 1 hour - delay after a vote passes
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
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
        uint256 proposalId = myGovernor.propose(targets, values, calldatas, description);

        // View the state of the proposal
        console.log("Delay: ", myGovernor.votingDelay());
        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));

        vm.warp(block.timestamp + myGovernor.votingDelay() + 1);
        vm.roll(block.number + myGovernor.votingDelay() + 1);

        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));

        // 2. Vote on proposal
        string memory reason = "Whatever reason you like";

        // enum VoteType{
        //     Against, // 0
        //     For,     // 1
        //     Abstain, // 2
        // }

        uint8 voteWay = 1; // voting yes
        vm.prank(user);
        myGovernor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. Queue the Tx
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 4. Execute the TX
        myGovernor.execute(targets, values, calldatas, descriptionHash);

        assert(box.getNumber() == valueToStore);
        console.log("Box Value: ", box.getNumber());
    }
}
