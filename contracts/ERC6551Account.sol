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
    uint256 public nonce;

    // 複数のNFT情報を格納する変数
    address[] public tokenContracts;
    uint256[] public tokenIds;
    uint256[] public chainIds;

    // コンストラクタを追加
    constructor(address[] memory _tokenContracts, uint256[] memory _tokenIds, uint256[] memory _chainIds) {
        require(_tokenContracts.length == _tokenIds.length && _tokenIds.length == _chainIds.length, "Input arrays must have the same length");
        tokenContracts = _tokenContracts;
        tokenIds = _tokenIds;
        chainIds = _chainIds;
    }

    receive() external payable {}

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result) {
        require(isOwner(msg.sender), "Not token owner");

        ++nonce;

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function tokens()
        external
        view
        returns (
            uint256[] memory,
            address[] memory,
            uint256[] memory
        )
    {
        return (chainIds, tokenContracts, tokenIds);
    }

    function owners() public view returns (address[] memory) {
        address[] memory ownersList = new address[](tokenContracts.length);
        for (uint256 i = 0; i < tokenContracts.length; i++) {
            if (chainIds[i] != block.chainid) {
                ownersList[i] = address(0);
            } else {
                ownersList[i] = IERC721(tokenContracts[i]).ownerOf(tokenIds[i]);
            }
        }
        return ownersList;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId);
    }

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
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
}
