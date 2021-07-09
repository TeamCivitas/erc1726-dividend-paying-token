// SPDX-License-Identifier: ISC
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@teamcivitas/wrap-math/contracts/utils/math/WrapMath.sol";

import "./IDividendPayingToken.sol";
import "./IDividendPayingTokenOptional.sol";

abstract contract DividendPayingToken is ERC20, IDividendPayingToken, IDividendPayingTokenOptional {
    using WrapMath for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;

    uint256 constant internal magnitude = 2**128;

    uint256 internal magnifiedDividendPerShare;

    address dividendToken;

    mapping(address => int256) internal magnifiedDividendCorrections;
    mapping(address => uint256) internal withdrawnDividends;

    uint256 public totalDividendsDistributed;

/*     function() external payable {
      distributeDividends();
    } */

    receive() external payable {
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol)  {

    }

    function distributeDividends() public override payable {
      require(totalSupply() > 0);

      if (msg.value > 0) {
        magnifiedDividendPerShare += (((msg.value) * magnitude) / totalSupply());
        emit DividendsDistributed(msg.sender, msg.value);
      }
    }

    function setDividendTokenAddress(address newToken) internal {
      dividendToken = newToken;
    }

    function withdrawDividend() public override virtual {
      uint256 _withdrawableDividend = withdrawableDividendOf(msg.sender);
      if (_withdrawableDividend > 0) {
        withdrawnDividends[msg.sender] += _withdrawableDividend;
        emit DividendWithdrawn(msg.sender, _withdrawableDividend);
        (payable(msg.sender)).transfer(_withdrawableDividend);
      }
    }

    function dividendOf(address _owner) public override view returns(uint256) {
      return withdrawableDividendOf(_owner);
    }

    function withdrawableDividendOf(address _owner) public override view returns(uint256) {
      return accumulativeDividendOf(_owner) - (withdrawnDividends[_owner]);
    }

    function withdrawnDividendOf(address _owner) public view override returns(uint256) {
      return withdrawnDividends[_owner];
    }
    function accumulativeDividendOf(address _owner) public view override returns(uint256) {
      return uint256(int256(magnifiedDividendPerShare * (balanceOf(_owner))) + magnifiedDividendCorrections[_owner]) / magnitude;
    }

    function _transfer(address from, address to, uint256 value) internal override virtual {
      require(false);
      super._transfer(from, to, value);

      int256 _magCorrection = int256(magnifiedDividendPerShare * value);
      magnifiedDividendCorrections[from] += _magCorrection;
      magnifiedDividendCorrections[to] -= _magCorrection;
    }

    function _mint(address account, uint256 value) internal override {
      super._mint(account, value);

        magnifiedDividendCorrections[account] -= int256(magnifiedDividendPerShare * value);
    }

    function _burn(address account, uint256 value) internal override {
      super._burn(account, value);

      magnifiedDividendCorrections[account] += int256(magnifiedDividendPerShare * value);
   }
    function _setBalance(address account, uint256 newBalance) internal {
      uint256 currentBalance = balanceOf(account);

      if(newBalance > currentBalance) {
        uint256 mintAmount = newBalance.sub(currentBalance);
        _mint(account, mintAmount);
      } else if(newBalance < currentBalance) {
        uint256 burnAmount = currentBalance.sub(newBalance);
        _burn(account, burnAmount);
      }
    }
}
