// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AILending
 * @dev AI借贷合约
 */
contract AILending is Ownable {
    
    struct LoanRequest {
        uint256 id;
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        string purpose;
        uint256 requestedAt;
        LoanStatus status;
        address lender;
        uint256 fundedAt;
    }
    
    enum LoanStatus { Pending, Funded, Repaying, Repaid, Defaulted, Cancelled }
    
    mapping(uint256 => LoanRequest) public loanRequests;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;
    
    uint256 public loanCounter;
    uint256 public constant DEFAULT_PENALTY_PERCENT = 20;
    
    event LoanRequested(uint256 indexed loanId, address indexed borrower, uint256 amount, uint256 interestRate);
    event LoanFunded(uint256 indexed loanId, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event LoanDefaulted(uint256 indexed loanId);
    
    constructor() Ownable() {}
    
    function requestLoan(
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        string calldata purpose,
        uint256 creditScore
    ) external returns (uint256) {
        require(amount > 0, "Invalid amount");
        require(interestRate <= 100, "Interest rate too high");
        
        uint256 loanId = ++loanCounter;
        
        LoanRequest storage loan = loanRequests[loanId];
        loan.id = loanId;
        loan.borrower = msg.sender;
        loan.amount = amount;
        loan.interestRate = interestRate;
        loan.duration = duration;
        loan.purpose = purpose;
        loan.requestedAt = block.timestamp;
        loan.status = LoanStatus.Pending;
        
        borrowerLoans[msg.sender].push(loanId);
        
        emit LoanRequested(loanId, msg.sender, amount, interestRate);
        return loanId;
    }
    
    function fundLoan(uint256 loanId) external payable {
        LoanRequest storage loan = loanRequests[loanId];
        
        require(loan.status == LoanStatus.Pending, "Loan not pending");
        require(msg.value >= loan.amount, "Insufficient funds");
        
        loan.lender = msg.sender;
        loan.status = LoanStatus.Funded;
        loan.fundedAt = block.timestamp;
        
        payable(loan.borrower).transfer(loan.amount);
        
        if (msg.value > loan.amount) {
            payable(msg.sender).transfer(msg.value - loan.amount);
        }
        
        lenderLoans[msg.sender].push(loanId);
        
        emit LoanFunded(loanId, msg.sender, loan.amount);
    }
    
    function repayLoan(uint256 loanId) external payable {
        LoanRequest storage loan = loanRequests[loanId];
        
        require(loan.status == LoanStatus.Funded, "Loan not funded");
        require(loan.borrower == msg.sender, "Not borrower");
        
        uint256 interest = (loan.amount * loan.interestRate * loan.duration) / (100 * 365 days);
        uint256 totalDue = loan.amount + interest;
        
        require(msg.value >= totalDue, "Insufficient repayment");
        
        payable(loan.lender).transfer(totalDue);
        
        if (msg.value > totalDue) {
            payable(msg.sender).transfer(msg.value - totalDue);
        }
        
        loan.status = LoanStatus.Repaid;
        
        emit LoanRepaid(loanId, totalDue);
    }
    
    function handleDefault(uint256 loanId) external {
        LoanRequest storage loan = loanRequests[loanId];
        
        require(loan.status == LoanStatus.Funded, "Loan not funded");
        
        uint256 dueDate = loan.fundedAt + loan.duration;
        require(block.timestamp > dueDate, "Not yet due");
        
        loan.status = LoanStatus.Defaulted;
        
        emit LoanDefaulted(loanId);
    }
    
    function getLoanDetails(uint256 loanId) external view returns (
        address borrower, uint256 amount, uint256 interestRate,
        LoanStatus status, address lender
    ) {
        LoanRequest storage loan = loanRequests[loanId];
        return (loan.borrower, loan.amount, loan.interestRate, loan.status, loan.lender);
    }
}
