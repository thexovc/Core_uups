// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";

interface NFT {
    function safeMint(address to, string memory uri, address coreAddress) external payable;
    function incrementNftCounter() external;
    function decreaseNftCounter() external;
}

error Essential_NoToken();
error NotApprovedFor_Core();

contract Core is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    event Response(bool success, bytes data);
    
    uint256 public timeWeightedAveragePrice;
    IERC20 token;
       
    struct Profile {
        string name;
        address addr;
        address inhr;
        string location;
        uint256 nft;
        uint256 currGold;
    }

    event AssetTransfer (
        address owner,
        address benifactor,
        uint256 assests
    );

    mapping(address => Profile) public profiles;
    mapping(address => bool) private admins;

    modifier isAdmin () {
        require(admins[msg.sender] == true, "you are not an admin");
        _;
    }

    /// upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function makeAdmin (address _addr) public onlyOwner {
        admins[_addr] = true;
    }

    function removeAdmin (address _addr) public onlyOwner {
        admins[_addr] = false;
    }

    function initialize(address _tokenAddress, uint256 _timeWeightedAveragePrice) initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();

        token = IERC20(_tokenAddress);
        timeWeightedAveragePrice = _timeWeightedAveragePrice;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
    

    // find a way to get the token uri for them before coming here like get it in the frontend
   function claimNFT(address nftAddress, string memory tokenURI) public payable {
        uint256 tokenBalance = token.balanceOf(msg.sender);
        require(tokenBalance > 0, "You must hold some tokens to mint an NFT");

        uint256 Twap = (tokenBalance + timeWeightedAveragePrice) / 2;

        if(Twap <= 0){
            revert Essential_NoToken();
        }

        NFT nftContract = NFT(nftAddress);

        nftContract.safeMint(msg.sender, tokenURI, address(this));    
       
    }

    function updateProfile(string memory _name, address _addr, address _inhr, string memory _location) public {
        Profile storage myProfile = profiles[_addr];
        myProfile.name = _name;
        myProfile.addr = _addr;
        myProfile.inhr = _inhr;
        myProfile.location = _location;
    }

    // only Admins can call the handle inheritance function
    function handleInheritance(address _user, address nftAddress, uint256 _totalToken) public isAdmin {
        IERC721Upgradeable nft = IERC721Upgradeable(nftAddress);

        for (uint256 i = 0; i < _totalToken; i++){
            if (nft.getApproved(i) != address(this)) {
                revert NotApprovedFor_Core();
            }
            nft.safeTransferFrom(_user, profiles[_user].inhr, i);
        }

        emit AssetTransfer(_user, profiles[_user].inhr, _totalToken);

    }

    function incrementUserNft(address addr) public {
        profiles[addr].nft += 1;
    }

    function decreaseUserNft(address addr) public {
        profiles[addr].nft -= 1;
    }  

}
