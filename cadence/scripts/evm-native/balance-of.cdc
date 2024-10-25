import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the balance of the owner (hex-encoded EVM address) of a given ERC20 fungible token defined
/// at the hex-encoded EVM contract address
///
/// @param owner: The hex-encoded EVM address of the owner
/// @param evmContractAddress: The hex-encoded EVM contract address of the ERC20 contract
///
/// @return The balance of the address, reverting if the given contract address does not implement the ERC20 method
///     "balanceOf(address)(uint256)"
///
access(all) fun main(owner: String, evmContractAddress: String): BalanceResult {
    let evmContract = EVM.addressFromString(evmContractAddress)
    return BalanceResult(
        balance: FlowEVMBridgeUtils.balanceOf(
            owner: EVM.addressFromString(owner),
            evmContractAddress: evmContract
        ),
        decimals: FlowEVMBridgeUtils.getTokenDecimals(evmContractAddress: evmContract)
    )
}

access(all) struct BalanceResult {
    access(all) let balance: UInt256
    access(all) let decimals: UInt8

    init(balance: UInt256, decimals: UInt8) {
        self.balance = balance
        self.decimals = decimals
    }
}
