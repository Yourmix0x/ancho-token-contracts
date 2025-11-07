// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import OpenZeppelin contracts
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract AnchoToken is ERC20, ERC20Pausable, Ownable {

    uint256 public constant MAX_SUPPLY = 777_777_777 * 10 ** 18;

    constructor(address initialOwner) ERC20("AnchoToken", "ANCHO") Ownable(initialOwner) {
        // mint the entire supply to the owner
        _mint(initialOwner, MAX_SUPPLY);
    }

    // required override for multiple inheritance 
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}