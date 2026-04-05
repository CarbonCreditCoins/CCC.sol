// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CarbonCreditCoin is ERC20, Ownable {

    uint256 public constant MAX_SUPPLY = 20_000_000_000 * 10**18;

    // 🔹 Referência informativa (não automática)
    uint256 public constant USD_REFERENCE_6 = 1_000_000; // 1.00 USD (6 casas)

    string public constant DESCRIPTION =
        "Carbon Credit Coin (CCC) is a digital asset with declared reference value of 1 USD per token.";

    constructor(address master) ERC20("Carbon Credit Coin", "CCC") Ownable(master) {
        require(master != address(0), "Invalid address");

        // 🔹 MINT TOTAL PARA SUA CARTEIRA
        _mint(master, MAX_SUPPLY);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    // 🔹 Função auxiliar (opcional)
    function cccToUsd(uint256 amount) external pure returns (uint256) {
        return (amount * USD_REFERENCE_6) / 1e18;
    }
}
