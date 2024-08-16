#allowAccountLinking
// Thirdparty imports
import "FungibleToken"
import "FlowToken"
import "HybridCustody"
// Fixes Imports
import "FRC20AccountsPool"
import "FGameLottery"
import "FGameLotteryFactory"
import "FGameLotteryRegistry"

transaction(
    initialFundingAmt: UFix64,
) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        // ----- Setup the lottery controller -----

        // Create the lottery controller if it doesn't exist
        if acct.storage.borrow<&FGameLotteryRegistry.RegistryController>(from: FGameLotteryRegistry.registryControllerStoragePath) == nil {
            acct.storage.save(<- FGameLotteryRegistry.createController(), to: FGameLotteryRegistry.registryControllerStoragePath)
        }
        let controller = acct.storage
            .borrow<auth(FGameLotteryRegistry.Manage) &FGameLotteryRegistry.RegistryController>(
            from: FGameLotteryRegistry.registryControllerStoragePath
        ) ?? panic("Could not borrow the registry controller")

        // ----------- Prepare the pool -----------

        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // Create a new account for the lottery
        let newAccount1 = Account(payer: acct)
        let newAccount2 = Account(payer: acct)

        // deposit 1.0 FLOW to the newly created account
        if initialFundingAmt > 0.0 {
            // Get a reference to the signer's stored vault
            let vaultRef = acct.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("Could not borrow reference to the owner's Vault!")

            let receiverRef1 = newAccount1.capabilities
                .get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow()
                ?? panic("Could not borrow receiver reference to the newly created account")
            receiverRef1.deposit(from: <- vaultRef.withdraw(amount: initialFundingAmt))

            let receiverRef2 = newAccount2.capabilities
                .get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow()
                ?? panic("Could not borrow receiver reference to the newly created account")
            receiverRef2.deposit(from: <- vaultRef.withdraw(amount: initialFundingAmt))
        }

        let cap1 = newAccount1.capabilities
            .account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
        FGameLotteryFactory.initializeFIXESMintingLotteryPool(controller, newAccount: cap1)

        let cap2 = newAccount2.capabilities
            .account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
        FGameLotteryFactory.initializeFIXESLotteryPool(controller, newAccount: cap2)
    }
}
