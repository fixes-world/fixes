import "EVM"

import "FlowEVMBridgeUtils"
import "FlowEVMBridgeConfig"

/// Returns the balance of the flow Address's COA account of a given ERC20 fungible token defined
/// at the hex-encoded EVM contract address
///
/// @param flowAddress: The native Flow address of the owner
/// @param identifier: The Cadence type identifier String
///
/// @return The balance of the associated EVM FT of the identifier, reverting if the given FT does not implement the ERC20 method
///     "balanceOf(address)(uint256)"
///
access(all) fun main(flowAddress: Address, identifier: String): BalanceResult? {
    if let coaAddress: EVM.EVMAddress = getAuthAccount<auth(BorrowValue) &Account>(flowAddress)
        .storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)?.address() {
        if let type = CompositeType(identifier) {
            if let ftAddress = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) {
                return BalanceResult(
                    address: coaAddress.toString(),
                    balance: FlowEVMBridgeUtils.balanceOf(
                        owner: coaAddress,
                        evmContractAddress: ftAddress
                    ),
                    decimals: FlowEVMBridgeUtils.getTokenDecimals(evmContractAddress: ftAddress)
                )
            }
        }
        return BalanceResult(
            address: coaAddress.toString(),
            balance: 0,
            decimals: 18
        )
    }
    return nil
}

access(all) struct BalanceResult {
    access(all) let address: String
    access(all) let balance: UInt256
    access(all) let decimals: UInt8

    init(
        address: String,
        balance: UInt256,
        decimals: UInt8
    ) {
        self.address = address
        self.balance = balance
        self.decimals = decimals
    }
}
