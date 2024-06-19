// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./interfaces/IERC6551Account.sol";
import "./lib/MinimalReceiver.sol";
import "./lib/ERC6551AccountLib.sol";

contract ERC6551Account is IERC165, IERC1271, IERC6551Account {
    uint256 private _nonce;

    struct NFT {
        uint256 chainId;
        address tokenContract;
        uint256 tokenId;
    }

    NFT[] public nfts;

    constructor(NFT[] memory initialNFTs) {
        for (uint256 i = 0; i < initialNFTs.length; i++) {
            nfts.push(initialNFTs[i]);
        }
    }

    receive() external payable override {}

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable override returns (bytes memory result) {
        require(isOwner(msg.sender), "Not token owner");

        _nonce++;

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function token()
        external
        view
        override
        returns (
            uint256 chainId,
            address tokenContract,
            uint256 tokenId
        )
    {
        // デフォルトでは、最初のNFTを返す。必要に応じてカスタマイズ
        require(nfts.length > 0, "No NFTs associated");
        NFT memory nft = nfts[0];
        return (nft.chainId, nft.tokenContract, nft.tokenId);
    }

    function owner() external view override returns (address) {
        address[] memory ownersList = owners();
        for (uint256 i = 0; i < ownersList.length; i++) {
            if (ownersList[i] != address(0)) {
                return ownersList[i];
            }
        }
        return address(0);
    }

    function nonce() external view override returns (uint256) {
        return _nonce;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return (interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId);
    }

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        address[] memory ownersList = owners();
        for (uint256 i = 0; i < ownersList.length; i++) {
            if (SignatureChecker.isValidSignatureNow(ownersList[i], hash, signature)) {
                return IERC1271.isValidSignature.selector;
            }
        }

        return "";
    }

    function isOwner(address addr) internal view returns (bool) {
        address[] memory ownersList = owners();
        for (uint256 i = 0; i < ownersList.length; i++) {
            if (ownersList[i] == addr) {
                return true;
            }
        }
        return false;
    }

    function owners() public view returns (address[] memory) {
        address[] memory ownersList = new address[](nfts.length);
        for (uint256 i = 0; i < nfts.length; i++) {
            if (nfts[i].chainId != block.chainid) {
                ownersList[i] = address(0);
            } else {
                ownersList[i] = IERC721(nfts[i].tokenContract).ownerOf(nfts[i].tokenId);
            }
        }
        return ownersList;
    }
}
