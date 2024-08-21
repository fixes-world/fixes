import "FungibleToken"
import "FlowToken"
import "HybridCustody"
import "EVMAgent"

access(all)
fun main(
    addr: Address
): EntrustedAccountDetails? {
    if let status = EVMAgent.borrowEntrustStatus(addr) {
        let acct = getAuthAccount<auth(Storage, Capabilities) &Account>(addr)
        let owned = acct.storage
            .borrow<auth(HybridCustody.Owner) &HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        let flowRef = acct.capabilities.get<&{FungibleToken.Balance}>(/public/flowTokenBalance)
                .borrow()
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
