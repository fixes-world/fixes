import "EVM"

import "FlowEVMBridgeUtils"

/// Returns the balance of the flow Address's COA account of a given ERC20 fungible token defined
/// at the hex-encoded EVM contract address
///
/// @param flowAddress: The native Flow address of the owner
/// @param evmContractAddress: The hex-encoded EVM contract address of the ERC20 contract
///
/// @return The balance of the address, reverting if the given contract address does not implement the ERC20 method
///     "balanceOf(address)(uint256)"
///
access(all) fun main(flowAddress: Address, evmContractAddress: String): UInt256 {
    if let address: EVM.EVMAddress = getAuthAccount<auth(BorrowValue) &Account>(flowAddress)
        .storage.borrow<&EVM.CadenceOwnedAccount>(from: /storage/evm)?.address() {
        let bytes: [UInt8] = []
        for byte in address.bytes {
            bytes.append(byte)
        }
        let constBytes = bytes.toConstantSized<[UInt8; 20]>()
            ?? panic("Problem converting provided EVMAddress compatible byte array - check byte array contains 20 bytes")
        return FlowEVMBridgeUtils.balanceOf(
            owner: EVM.EVMAddress(bytes: constBytes),
            evmContractAddress: EVM.addressFromString(evmContractAddress)
        )
    }
    return 0
}
