// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ERC20 {
    event Transfer(address form, address to, uint256 value);
    event Approval(address owner, address spender, uint256 value);

    mapping(address account => uint256) public balanceOf;
    mapping(address account => mapping(address spender => uint256)) public allowance;

    uint256 public totalSupply;
    string public name;
    string public symbol;
    uint256 public decimals;

    constructor(string memory _name, string memory _symbol, uint256 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0) && to != address(0), "LP_ERC20 : Invaldi zero address");
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal {
        require(value > 0, "LP_ERC20 : Zero amount");
        if (from == address(0)) {
            totalSupply = totalSupply + value;
        } else {
            uint256 fromBalance = balanceOf[from];
            require(fromBalance >= value, "LP_ERC20 : Invalid amount");
            unchecked {
                balanceOf[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                totalSupply = totalSupply - value;
            }
        } else {
            unchecked {
                balanceOf[to] = balanceOf[to] + value;
            }
        }

        emit Transfer(from, to, value);
    }

    function mint(address account, uint256 value) external {
        require(account != address(0), "LP_ERC20 : Invalid zero address");
        _update(address(0), account, value);
    }

    function burn(address account, uint256 value) external {
        require(account != address(0), "LP_ERC20 : Invalid zero address");
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        require(owner != address(0) && spender != address(0), "LP_ERC20 : Invalid zero address");
        allowance[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "LP_ERC20 : Invalid amount");
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
