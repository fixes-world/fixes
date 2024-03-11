import "FungibleToken"
import "FlowToken"
import "HybridCustody"
import "EVMAgent"

access(all)
fun main(
    addr: Address
): EntrustedAccountDetails? {
    if let status = EVMAgent.borrowEntrustStatus(addr) {
        let acct = getAuthAccount(addr)
        let owned = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        let flowRef = acct.getCapability(/public/flowTokenBalance)
                .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
        let agencyRef = status.borrowAgency()
        return EntrustedAccountDetails(
            address: addr,
            entrustedBy: status.key,
            agency: agencyRef.getOwnerAddress(),
            flowBalance: flowRef?.balance ?? 0.0,
            feeSpent: status.getFeeSpent(),
            parents: owned.getParentAddresses()
        )
    }
    return nil
}

access(all) struct EntrustedAccountDetails {
    access(all) let address: Address
    access(all) let entrustedBy: String
    access(all) let agency: Address
    access(all) let flowBalance: UFix64
    access(all) let feeSpent: UFix64
    access(all) let parents: [Address]

    init(
        address: Address,
        entrustedBy: String,
        agency: Address,
        flowBalance: UFix64,
        feeSpent: UFix64,
        parents: [Address]
    ) {
        self.address = address
        self.entrustedBy = entrustedBy
        self.agency = agency
        self.flowBalance = flowBalance
        self.feeSpent = feeSpent
        self.parents = parents
    }
}
