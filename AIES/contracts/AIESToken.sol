// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIESToken
 * @dev AI Economic Society - 平台代币合约
 * 
 * 代币经济学：
 * - 总供应量：1,000,000,000 AIES
 * - 用于平台内交易、奖励、治理投票
 */
contract AIESToken is ERC20, ERC20Burnable, Ownable {
    
    // 铸币权限
    mapping(address => bool) public minters;
    
    // 最大供应量
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;
    
    // 事件
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event TokensMinted(address indexed to, uint256 amount);
    
    constructor() ERC20("AIES Token", "AIES") Ownable() {
        // 初始铸币给部署者
        _mint(msg.sender, 100_000_000 * 10**18);
    }
    
    /**
     * @dev 添加铸币权限
     */
    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }
    
    /**
     * @dev 移除铸币权限
     */
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }
    
    /**
     * @dev 铸币（需要权限）
     */
    function mint(address to, uint256 amount) external {
        require(minters[msg.sender], "Not a minter");
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
    
    /**
     * @dev 批量转账
     */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Length mismatch");
        require(recipients.length > 0, "Empty array");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }
}
