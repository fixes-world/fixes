#allowAccountLinking

import "MetadataViews"
import "FungibleToken"
import "FlowToken"
import "HybridCustody"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20StakingManager"

transaction(
    tick: String,
    initialFundingAmt: UFix64
) {
    prepare(acct: auth(Storage, Capabilities) &Account) {

        // initialize staking controller
        if acct.storage.borrow<&AnyResource>(from: FRC20StakingManager.StakingControllerStoragePath) == nil {
            acct.storage.save(<- FRC20StakingManager.createController(), to: FRC20StakingManager.StakingControllerStoragePath)
        }

        let controller = acct.storage
            .borrow<auth(FRC20StakingManager.Manage) &FRC20StakingManager.StakingController>(from: FRC20StakingManager.StakingControllerStoragePath)
            ?? panic("There is no FRC20StakingManager on this account")

        let pool = acct.storage
            .borrow<auth(FRC20AccountsPool.Admin) &FRC20AccountsPool.Pool>(from: FRC20AccountsPool.AccountsPoolStoragePath)
            ?? panic("There is no FRC20AccountsPool on this account")

        if pool.getFRC20StakingAddress(tick: tick) == nil {
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
            let cap = newAccount.capabilities.account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()

            // add the new account to the pool and enable staking
            controller.enableAndCreateFRC20Staking(tick: tick, newAccount: cap)
        } else {
            // just initialize the FRC20Staking account
            controller.ensureStakingResourcesAvailable(tick: tick)
        }
    }
}
