// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IBorrowTracker {
    function trackBorrow(address borrower, uint256 borrowBalance, uint256 borrowIndex) external;
}

interface IFactory {
    function admin() external view returns (address);
}

interface ICollateral {
    function accountLiquidity(address account) external view returns (uint256 liquidity, uint256 shortfall);
}

interface IBorrowable {
    function collateral() external view returns (address);
    function underlying() external view returns (address);
    function factory() external view returns (address);
    function borrowBalance(address borrower) external view returns (uint256);
    function _setBorrowTracker(address newBorrowTracker) external;
    function trackBorrow(address borrower) external;
    function borrow(address borrower, address receiver, uint256 borrowAmount, bytes calldata data) external;
    function accrueInterest() external;
}

contract BorrowTrackerBadDebtExtension is IBorrowTracker {
    struct BorrowerInfo {
        bool isListed;
        uint248 index;
    }

    address public immutable factory;

    mapping(address => mapping(address => BorrowerInfo)) public borrowerInfo;

    mapping(address => address) public borrowTracker;

    mapping(address => address[]) public borrowers;

    event NewBorrowTracker(address indexed borrowable, address indexed newBorrowTracker);

    constructor(address _factory) {
        factory = _factory;
    }

    function _setBorrowTracker(address borrowable, address newBorrowTracker) external {
        require(msg.sender == IFactory(factory).admin(), "Impermax: UNAUTHORIZED");
        borrowTracker[borrowable] = newBorrowTracker;
        emit NewBorrowTracker(borrowable, newBorrowTracker);
    }

    function trackBorrow(address borrower, uint256 accountBorrows, uint256 borrowIndex) external {
        BorrowerInfo memory bInfo = borrowerInfo[msg.sender][borrower];
        if (bInfo.isListed && accountBorrows == 0) {
            uint256 lastIndex = borrowers[msg.sender].length - 1;
            address lastBorrower = borrowers[msg.sender][lastIndex];
            borrowerInfo[msg.sender][lastBorrower].index = bInfo.index;
            borrowers[msg.sender][bInfo.index] = lastBorrower;
            borrowers[msg.sender].pop();
            delete borrowerInfo[msg.sender][borrower];
        } else if (!bInfo.isListed && accountBorrows != 0) {
            borrowers[msg.sender].push(borrower);
            borrowerInfo[msg.sender][borrower] =
                BorrowerInfo({isListed: true, index: uint248(borrowers[msg.sender].length - 1)});
        }
        address _borrowTracker = borrowTracker[msg.sender];
        if (_borrowTracker == address(0)) return;
        IBorrowTracker(_borrowTracker).trackBorrow(borrower, accountBorrows, borrowIndex);
    }

    function getBorrowers(address borrowable) external view returns (address[] memory) {
        return borrowers[borrowable];
    }

    function getBorrowerCount(address borrowable) public view returns (uint256) {
        return borrowers[borrowable].length;
    }

    function getBadDebt(address borrowable) external view returns (uint256) {
        return getBadDebt(borrowable, 0, getBorrowerCount(borrowable));
    }

    function getBadDebt(address borrowable, uint256 startIndex, uint256 endIndex) public view returns (uint256) {
        uint256 badDebt = 0;
        address collateral = IBorrowable(borrowable).collateral();
        for (uint256 i = startIndex; i < endIndex; i++) {
            address borrower = borrowers[borrowable][i];
            (, uint256 shortfall) = ICollateral(collateral).accountLiquidity(borrower);
            if (shortfall != 0) {
                badDebt += IBorrowable(borrowable).borrowBalance(borrower);
            }
        }
        return badDebt;
    }

    function getLiquidatableAccounts(address borrowable) external view returns (address[] memory) {
        return getLiquidatableAccounts(borrowable, 0, getBorrowerCount(borrowable));
    }

    function getLiquidatableAccounts(address borrowable, uint256 startIndex, uint256 endIndex)
        public
        view
        returns (address[] memory)
    {
        address collateral = IBorrowable(borrowable).collateral();
        uint positionCount = endIndex - startIndex;
        address[] memory underwaterAccounts = new address[](positionCount);
        uint256 healthyPositionCount = 0;
        for (uint256 i = startIndex; i < endIndex; i++) {
            address borrower = borrowers[borrowable][i];
            (, uint256 shortfall) = ICollateral(collateral).accountLiquidity(borrower);
            if (shortfall == 0) {
                healthyPositionCount++;
            } else {
                underwaterAccounts[i - healthyPositionCount] = borrower;
            }
        }

        // Reduces the length of the liquidatable positions array by `healthyPositionCount`
        assembly {
          mstore(underwaterAccounts, sub(positionCount, healthyPositionCount))
        }
        return underwaterAccounts;
    }
}
