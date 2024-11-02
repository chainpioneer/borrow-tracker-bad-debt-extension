// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {BorrowTrackerBadDebtExtension, IFactory, IBorrowable} from "../src/BorrowTrackerBadDebtExtension.sol";

contract BorrowTrackerBadDebtExtensionScrollTest is Test {
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("scroll"));
        vm.rollFork(10728165);
    }

    function test_getBadDebt() public {
        address borrowable = 0x56F98d1f75a6345312bf46FDb48aB4728Ff25aDf;
        address factory = IBorrowable(borrowable).factory();
        BorrowTrackerBadDebtExtension tracker = new BorrowTrackerBadDebtExtension(factory);

        vm.prank(IFactory(factory).admin());
        IBorrowable(borrowable)._setBorrowTracker(address(tracker));

        address[7] memory borrowers = [
            0x8e8AdEB64BCd257Fdd83645296045094d0CC1845,
            0xf255C69E2Aa13567ae4eFbF0E99dF89e8a28573d,
            0x0932AbaBa09744d16D280A190Abcc45DE6C92D48,
            0x542d929EcFF6ac4a1F318ea5CDed3D4F24dC30aa,
            0xBBA693B3CbDC2266a4f6E6b68182B43Ebd579f61,
            0xCB6586874cc04B01Cc4fDB777dE502cEa7b3D6c1, // no bad debt
            0x710c8cF05fdFD4eD321f060f4988629dA42b52eb
        ];

        for (uint256 i = 0; i < borrowers.length; i++) {
            IBorrowable(borrowable).trackBorrow(borrowers[i]);
        }

        // ensure healthy account is not marked as liquidatable
        address[] memory borrowersWithBadDebt = tracker.getLiquidatableAccounts(borrowable);
        assertEq(borrowersWithBadDebt.length, borrowers.length - 1);

        IBorrowable(borrowable).accrueInterest();

        uint256 underwaterPositionCount = tracker.getBorrowerCount(borrowable);
        uint256 badDebt = tracker.getBadDebt(borrowable);

        // print current bad debt
        console.log("borrower count", underwaterPositionCount);
        console.log("bad debt", badDebt);

        // repay account debt
        address repayer = borrowers[0];
        uint256 bb = IBorrowable(borrowable).borrowBalance(repayer);

        address underlying = IBorrowable(borrowable).underlying();
        uint256 borrowableBalance = IERC20(underlying).balanceOf(borrowable);
        deal(underlying, borrowable, borrowableBalance + bb);
        IBorrowable(borrowable).borrow(repayer, address(0), 0, new bytes(0));

        // ensure data is updated
        uint256 underwaterPositionCountNew = tracker.getBorrowerCount(borrowable);
        uint256 badDebtNew = tracker.getBadDebt(borrowable);
        assertEq(underwaterPositionCount - 1, underwaterPositionCountNew);
        assertEq(badDebt - badDebtNew, bb);
        (bool listed,) = tracker.borrowerInfo(borrowable, repayer);
        assertFalse(listed);
        assertEq(tracker.borrowers(borrowable, 0), borrowers[borrowers.length - 1]);
    }

    function test_gasUsageWithoutTracking() public {
        address borrowable = 0x56F98d1f75a6345312bf46FDb48aB4728Ff25aDf;
        address factory = IBorrowable(borrowable).factory();
        BorrowTrackerBadDebtExtension tracker = new BorrowTrackerBadDebtExtension(factory);

        address underlying = IBorrowable(borrowable).underlying();
        uint256 borrowableBalance = IERC20(underlying).balanceOf(borrowable);
        deal(underlying, borrowable, ++borrowableBalance);
        // warm up slots
        IBorrowable(borrowable).borrow(0x8e8AdEB64BCd257Fdd83645296045094d0CC1845, address(0), 0, new bytes(0));

        deal(underlying, borrowable, ++borrowableBalance);
        uint256 gasStart = gasleft();
        IBorrowable(borrowable).borrow(0x8e8AdEB64BCd257Fdd83645296045094d0CC1845, address(0), 0, new bytes(0));
        uint256 gasEnd = gasleft();

        uint256 gasUsageWithoutTracking = gasStart - gasEnd;

        console.log("gas usage without tracking", gasUsageWithoutTracking);

        // set borrow tracker
        vm.prank(IFactory(factory).admin());
        IBorrowable(borrowable)._setBorrowTracker(address(tracker));

        // track random borrower to initialize storage
        IBorrowable(borrowable).trackBorrow(0xf255C69E2Aa13567ae4eFbF0E99dF89e8a28573d);

        deal(underlying, borrowable, ++borrowableBalance);
        gasStart = gasleft();
        IBorrowable(borrowable).borrow(0x8e8AdEB64BCd257Fdd83645296045094d0CC1845, address(0), 0, new bytes(0));
        gasEnd = gasleft();

        uint256 gasUsageWithTracking = gasStart - gasEnd;
        console.log("max gas usage with tracking", gasUsageWithTracking);

        assertLt(gasUsageWithTracking - gasUsageWithoutTracking, 50_000);
    }
}
