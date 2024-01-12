#allowAccountLinking

import "MetadataViews"
import "FungibleToken"
import "FlowToken"
import "HybridCustody"
import "FRC20Indexer"
import "FRC20AccountsPool"

transaction(
    type: UInt8,
    initialFundingAmt: UFix64,
) {
    let acctsPool: &FRC20AccountsPool.Pool
    let accountType: FRC20AccountsPool.ChildAccountType
    let childAccountCap: Capability<&AuthAccount>

    prepare(acct: AuthAccount) {
        let pool = acct.borrow<&FRC20AccountsPool.Pool>(from: FRC20AccountsPool.AccountsPoolStoragePath)
            ?? panic("There is no FRC20AccountsPool on this account")

        self.acctsPool = pool

        let poolType = FRC20AccountsPool.ChildAccountType(rawValue: type)
            ?? panic("Invalid child account type")
        // borrow shared reference to check if child account already exists
        let child = pool.borrowChildAccount(type: poolType, tick: nil)
        assert(
            child == nil,
            message: "Child account already exists"
        )
        self.accountType = poolType

        // create a new Account, no keys needed
        let newAccount = AuthAccount(payer: acct)

        // deposit 1.0 FLOW to the newly created account
        if initialFundingAmt > 0.0 {
            // Get a reference to the signer's stored vault
            let vaultRef = acct.borrow<&FlowToken.Vault{FungibleToken.Provider}>(from: /storage/flowTokenVault)
                ?? panic("Could not borrow reference to the owner's Vault!")
            let flowToReserve <- vaultRef.withdraw(amount: initialFundingAmt)

            let receiverRef = newAccount.getCapability(/public/flowTokenReceiver)
                .borrow<&{FungibleToken.Receiver}>()
                ?? panic("Could not borrow receiver reference to the newly created account")
            receiverRef.deposit(from: <- flowToReserve)
        }

        /* --- Link the AuthAccount Capability --- */
        //
        self.childAccountCap = newAccount.linkAccount(HybridCustody.LinkedAccountPrivatePath)
            ?? panic("problem linking account Capability for new account")
    }

    execute {
        // add the newly created account to the pool
        self.acctsPool.setupNewSharedChildByType(type: self.accountType, self.childAccountCap)

        log("Done: Init Shared Pool")
    }
}
