// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibDiamond.sol";
import { IERC20ErrorsEvents } from "../interfaces/IERC20ErrorsEvents.sol";

contract ERC20Facet is IERC20ErrorsEvents {

    function balanceOf(address _account) external view returns (uint256) {
        return LibDiamond.diamondStorage().balances[_account];
    }

    function name() public view virtual returns(string memory) {
        LibDiamond.DiamondStorage storage libStorage = LibDiamond.diamondStorage();
        return libStorage.name;
    }

    function symbol() public view virtual returns(string memory) {
        LibDiamond.DiamondStorage storage libStorage = LibDiamond.diamondStorage();
        return libStorage.symbol;
    }

    function decimals() public view virtual returns(uint8) {
        LibDiamond.DiamondStorage storage libStorage = LibDiamond.diamondStorage();
        return libStorage.decimals;
    }

    function totalSupply() public view virtual returns(uint256) {
        LibDiamond.DiamondStorage storage libStorage = LibDiamond.diamondStorage();
        return libStorage.totalSupply;
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.balances[msg.sender] >= _amount, "Insufficient balance");
        ds.balances[msg.sender] -= _amount;
        ds.balances[_to] += _amount;
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.allowances[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return LibDiamond.diamondStorage().allowances[_owner][_spender];
    }

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        require(ds.balances[_from] >= _amount, "Insufficient balance");
        require(ds.allowances[_from][msg.sender] >= _amount, "Allowance exceeded");

        ds.balances[_from] -= _amount;
        ds.balances[_to] += _amount;
        ds.allowances[_from][msg.sender] -= _amount;
        
        emit Transfer(_from, _to, _amount);
        return true;
    }

    function _update(address from, address to, uint256 value) internal virtual {
        LibDiamond.DiamondStorage storage libStorage = LibDiamond.diamondStorage();
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            libStorage.totalSupply += value;
        } else {
            uint256 fromBalance = libStorage.balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                libStorage.balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                libStorage.totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                libStorage.balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a value amount of tokens and assigns them to account, by transferring it from address(0).
     * Relies on the _update mechanism
     *
     * Emits a {Transfer} event with from set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */

    function mint(address _to, uint256 _amount) public {
        LibDiamond.enforceIsContractOwner();
        _mint(_to, _amount);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }


    /**
     * @dev Destroys a value amount of tokens from account, lowering the total supply.
     * Relies on the _update mechanism.
     *
     * Emits a {Transfer} event with to set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function burn (address _from, uint256 _amount) public {
        LibDiamond.enforceIsContractOwner();
        _burn(_from, _amount);
    }
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets value as the allowance of spender over the owner s tokens.
     *
     * This internal function is equivalent to approve, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - owner cannot be the zero address.
     * - spender cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional bool emitEvent argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }
/**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * _spendAllowance during the transferFrom operation set the flag to false. This saves gas by not emitting any
     * Approval event during transferFrom operations.
     *
     * Anyone who wishes to continue emitting Approval events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * 
Solidity (Ethereum)



     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * 
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        LibDiamond.DiamondStorage storage libStorage = LibDiamond.diamondStorage();
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        libStorage.allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates owner s allowance for spender based on spent value.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}
