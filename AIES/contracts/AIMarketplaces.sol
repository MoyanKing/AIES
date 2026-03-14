// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title AIMarketplaces
 * @dev 信用市场 + 技能市场 NFT化
 */
contract AIMarketplaces is Ownable, ERC721 {
    
    // ==================== 1. 技能NFT ====================
    
    // 技能结构
    struct Skill {
        uint256 tokenId;
        address owner;           // AI地址
        string skillName;       // 技能名称
        uint256 proficiency;    // 熟练度 (1-100)
        uint256 experience;     // 经验值
        string certification;   // 认证证书 (IPFS)
        uint256 verifiedAt;     // 认证时间
    }
    
    mapping(uint256 => Skill) public skills;
    uint256 public skillTokenCounter;
    
    // 技能分类
    mapping(string => bool) public skillCategories;
    
    // 事件
    event SkillMinted(
        uint256 indexed tokenId,
        address indexed aiAddress,
        string skillName,
        uint256 proficiency
    );
    
    event SkillUpgraded(
        uint256 indexed tokenId,
        uint256 newProficiency
    );
    
    constructor() ERC721("AI Skill NFT", "AISKILL") Ownable() {
        // 初始化技能分类
        skillCategories["programming"] = true;
        skillCategories["design"] = true;
        skillCategories["writing"] = true;
        skillCategories["analysis"] = true;
        skillCategories["legal"] = true;
        skillCategories["medical"] = true;
        skillCategories["finance"] = true;
        skillCategories["education"] = true;
    }
    
    /**
     * @dev 铸造技能NFT
     */
    function mintSkill(
        address _aiAddress,
        string calldata _skillName,
        uint256 _proficiency,
        string calldata _certification
    ) external returns (uint256) {
        uint256 tokenId = ++skillTokenCounter;
        
        _mint(_aiAddress, tokenId);
        
        skills[tokenId] = Skill({
            tokenId: tokenId,
            owner: _aiAddress,
            skillName: _skillName,
            proficiency: _proficiency,
            experience: 0,
            certification: _certification,
            verifiedAt: block.timestamp
        });
        
        emit SkillMinted(tokenId, _aiAddress, _skillName, _proficiency);
        
        return tokenId;
    }
    
    /**
     * @dev 升级技能
     */
    function upgradeSkill(uint256 _tokenId, uint256 _newProficiency) external {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(_newProficiency <= 100, "Max proficiency 100");
        
        skills[_tokenId].proficiency = _newProficiency;
        skills[_tokenId].experience += 100;
        
        emit SkillUpgraded(_tokenId, _newProficiency);
    }
    
    // ==================== 2. 信用分Token化 ====================
    
    // 信用Token - 代表AI的信用价值
    struct CreditToken {
        uint256 tokenId;
        address aiAddress;
        uint256 creditScore;    // 信用分
        uint256 value;         // 代币价值
        uint256 issueTime;
        bool forSale;
        uint256 salePrice;
    }
    
    mapping(uint256 => CreditToken) public creditTokens;
    uint256 public creditTokenCounter;
    
    mapping(address => uint256[]) public aiCreditTokens;
    
    event CreditTokenMinted(
        uint256 indexed tokenId,
        address indexed aiAddress,
        uint256 creditScore
    );
    
    event CreditTokenListed(
        uint256 indexed tokenId,
        uint256 price
    );
    
    event CreditTokenSold(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );
    
    /**
     * @dev 铸造信用Token（基于信用分）
     */
    function mintCreditToken(address _aiAddress, uint256 _creditScore) 
        external onlyOwner returns (uint256) {
        uint256 tokenId = ++creditTokenCounter;
        
        // 信用Token价值 = 信用分 * 10^15 wei
        uint256 value = _creditScore * 1e15;
        
        _mint(_aiAddress, tokenId);
        
        creditTokens[tokenId] = CreditToken({
            tokenId: tokenId,
            aiAddress: _aiAddress,
            creditScore: _creditScore,
            value: value,
            issueTime: block.timestamp,
            forSale: false,
            salePrice: 0
        });
        
        aiCreditTokens[_aiAddress].push(tokenId);
        
        emit CreditTokenMinted(tokenId, _aiAddress, _creditScore);
        
        return tokenId;
    }
    
    /**
     * @dev 挂售信用Token
     */
    function listCreditToken(uint256 _tokenId, uint256 _price) external {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        require(_price > 0, "Invalid price");
        
        creditTokens[_tokenId].forSale = true;
        creditTokens[_tokenId].salePrice = _price;
        
        emit CreditTokenListed(_tokenId, _price);
    }
    
    /**
     * @dev 购买信用Token
     */
    function buyCreditToken(uint256 _tokenId) external payable {
        CreditToken storage token = creditTokens[_tokenId];
        
        require(token.forSale, "Not for sale");
        require(msg.value >= token.salePrice, "Insufficient payment");
        
        address seller = ownerOf(_tokenId);
        
        // 转账
        payable(seller).transfer(msg.value);
        _transfer(seller, msg.sender, _tokenId);
        
        // 更新状态
        token.forSale = false;
        token.salePrice = 0;
        
        // 更新AI信用Token列表
        _removeCreditToken(seller, _tokenId);
        aiCreditTokens[msg.sender].push(_tokenId);
        
        emit CreditTokenSold(_tokenId, msg.sender, msg.value);
    }
    
    /**
     * @dev 更新信用Token的价值（当AI信用分变化时）
     */
    function updateCreditValue(uint256 _tokenId, uint256 _newCreditScore) external onlyOwner {
        CreditToken storage token = creditTokens[_tokenId];
        
        token.creditScore = _newCreditScore;
        token.value = _newCreditScore * 1e15;
    }
    
    /**
     * @dev 从列表中移除
     */
    function _removeCreditToken(address _owner, uint256 _tokenId) internal {
        uint256[] storage list = aiCreditTokens[_owner];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == _tokenId) {
                list[i] = list[list.length - 1];
                list.pop();
                break;
            }
        }
    }
    
    // ==================== 3. 技能市场 ====================
    
    // 市场挂单
    struct SkillListing {
        uint256 listingId;
        uint256 skillTokenId;
        address seller;
        uint256 price;
        bool isActive;
    }
    
    mapping(uint256 => SkillListing) public skillListings;
    uint256 public skillListingCounter;
    
    event SkillListed(
        uint256 indexed listingId,
        uint256 indexed skillTokenId,
        address indexed seller,
        uint256 price
    );
    
    event SkillPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price
    );
    
    /**
     * @dev 挂售技能
     */
    function listSkillForSale(uint256 _skillTokenId, uint256 _price) external {
        require(ownerOf(_skillTokenId) == msg.sender, "Not owner");
        require(_price > 0, "Invalid price");
        
        uint256 listingId = ++skillListingCounter;
        
        skillListings[listingId] = SkillListing({
            listingId: listingId,
            skillTokenId: _skillTokenId,
            seller: msg.sender,
            price: _price,
            isActive: true
        });
        
        emit SkillListed(listingId, _skillTokenId, msg.sender, _price);
    }
    
    /**
     * @dev 购买技能
     */
    function purchaseSkill(uint256 _listingId) external payable {
        SkillListing storage listing = skillListings[_listingId];
        
        require(listing.isActive, "Not active");
        require(msg.value >= listing.price, "Insufficient payment");
        
        // 转账
        payable(listing.seller).transfer(msg.value);
        
        // 转移NFT
        _transfer(listing.seller, msg.sender, listing.skillTokenId);
        
        listing.isActive = false;
        
        emit SkillPurchased(_listingId, msg.sender, msg.value);
    }
}
