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
access(all) fun main(flowAddress: Address, identifier: String): UInt256 {
    if let address: EVM.EVMAddress = getAuthAccount<auth(BorrowValue) &Account>(flowAddress)
        .storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)?.address() {
        let bytes: [UInt8] = []
        for byte in address.bytes {
            bytes.append(byte)
        }
        let constBytes = bytes.toConstantSized<[UInt8; 20]>()
            ?? panic("Problem converting provided EVMAddress compatible byte array - check byte array contains 20 bytes")

        if let type = CompositeType(identifier) {
            if let address = FlowEVMBridgeConfig.getEVMAddressAssociated(with: type) {
                return FlowEVMBridgeUtils.balanceOf(
                    owner: EVM.EVMAddress(bytes: constBytes),
                    evmContractAddress: address
                )
            }
        }
    }
    return 0
}
