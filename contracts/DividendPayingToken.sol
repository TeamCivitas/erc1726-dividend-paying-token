// SPDX-License-Identifier: ISC
pragma solidity ^0.8.4;

//import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IDividendPayingToken.sol";
import "./IDividendPayingTokenOptional.sol";

library wrapMath {
  function add(uint256 a, uint256 b) {
    return a+b;
  }
  function mul(uint256 a, uint256 b) {
    return a*b;
  }
}

contract DividendPayingToken is ERC20, IDividendPayingToken, IDividendPayingTokenOptional {
    using wrapMath for uint256;
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

    function distributeDividends() public payable {
      require(totalSupply() > 0);

      if (msg.value > 0) {
        magnifiedDividendPerShare = magnifiedDividendPerShare.add(
          (msg.value).mul(magnitude) / totalSupply()
        );
        emit DividendsDistributed(msg.sender, msg.value);
      }
    }

    function setDividendTokenAddress(address newToken) internal {
      dividendToken = newToken;
    }

    function withdrawDividend() public {
      uint256 _withdrawableDividend = withdrawableDividendOf(msg.sender);
      if (_withdrawableDividend > 0) {
        withdrawnDividends[msg.sender] = withdrawnDividends[msg.sender].add(_withdrawableDividend);
        emit DividendWithdrawn(msg.sender, _withdrawableDividend);
        (msg.sender).transfer(_withdrawableDividend);
      }
    }

    function dividendOf(address _owner) public view returns(uint256) {
      return withdrawableDividendOf(_owner);
    }

    function withdrawableDividendOf(address _owner) public view returns(uint256) {
      return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
    }

    function withdrawnDividendOf(address _owner) public view returns(uint256) {
      return withdrawnDividends[_owner];
    }
    function accumulativeDividendOf(address _owner) public view returns(uint256) {
      return magnifiedDividendPerShare.mul(balanceOf(_owner)).toInt256Safe()
        .add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;
    }

    function _transfer(address from, address to, uint256 value) internal {
      require(false);
      super._transfer(from, to, value);

      int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
      magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
      magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
    }

    function _mint(address account, uint256 value) internal {
      super._mint(account, value);

      magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
        .sub( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
    }

    function _burn(address account, uint256 value) internal {
      super._burn(account, value);

      magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
        .add( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
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
