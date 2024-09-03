#allowAccountLinking

import "MetadataViews"
import "FungibleToken"
import "FlowToken"
import "HybridCustody"
import "FRC20Indexer"
import "FRC20AccountsPool"

transaction(
    type: UInt8,
    initialFundingAmt: UFix64
) {
    let acctsPool: auth(FRC20AccountsPool.Admin) &FRC20AccountsPool.Pool
    let accountType: FRC20AccountsPool.ChildAccountType
    let childAccountCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>

    prepare(acct: auth(Storage, Capabilities) &Account) {
        let pool = acct.storage
            .borrow<auth(FRC20AccountsPool.Admin) &FRC20AccountsPool.Pool>(from: FRC20AccountsPool.AccountsPoolStoragePath)
            ?? panic("There is no FRC20AccountsPool on this account")

        self.acctsPool = pool

        self.accountType = FRC20AccountsPool.ChildAccountType(rawValue: type)
            ?? panic("Invalid child account type")

        // create a new Account, no keys needed
        let newAccount = Account(payer: acct)

        // deposit 1.0 FLOW to the newly created account
        if initialFundingAmt > 0.0 {
            // Get a reference to the signer's stored vault
            let vaultRef = acct.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("Could not borrow reference to the owner's Vault!")
            let flowToReserve <- vaultRef.withdraw(amount: initialFundingAmt)

            let receiverRef = newAccount.capabilities
                .get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow()
                ?? panic("Could not borrow receiver reference to the newly created account")
            receiverRef.deposit(from: <- flowToReserve)
        }

        /* --- Link the AuthAccount Capability --- */
        //
        self.childAccountCap = newAccount.capabilities.account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
    }

    execute {
        // add the newly created account to the pool
        self.acctsPool.setupNewSharedChildByType(type: self.accountType, self.childAccountCap)
        log("Done: Init Pool")
    }
}
