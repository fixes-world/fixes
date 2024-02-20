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
    prepare(acct: AuthAccount) {
        // ----- Setup the lottery controller -----

        // Create the lottery controller if it doesn't exist
        if acct.borrow<&FGameLotteryRegistry.RegistryController>(from: FGameLotteryRegistry.registryControllerStoragePath) == nil {
            acct.save(<- FGameLotteryRegistry.createController(), to: FGameLotteryRegistry.registryControllerStoragePath)
        }
        let controller = acct.borrow<&FGameLotteryRegistry.RegistryController>(
            from: FGameLotteryRegistry.registryControllerStoragePath
        ) ?? panic("Could not borrow the registry controller")

        // ----------- Prepare the pool -----------

        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // Create a new account for the lottery
        let newAccount1 = AuthAccount(payer: acct)
        let newAccount2 = AuthAccount(payer: acct)

        // deposit 1.0 FLOW to the newly created account
        if initialFundingAmt > 0.0 {
            // Get a reference to the signer's stored vault
            let vaultRef = acct.borrow<&FlowToken.Vault{FungibleToken.Provider}>(from: /storage/flowTokenVault)
                ?? panic("Could not borrow reference to the owner's Vault!")

            let receiverRef1 = newAccount1.getCapability(/public/flowTokenReceiver)
                .borrow<&{FungibleToken.Receiver}>()
                ?? panic("Could not borrow receiver reference to the newly created account")
            receiverRef1.deposit(from: <- vaultRef.withdraw(amount: initialFundingAmt))

            let receiverRef2 = newAccount2.getCapability(/public/flowTokenReceiver)
                .borrow<&{FungibleToken.Receiver}>()
                ?? panic("Could not borrow receiver reference to the newly created account")
            receiverRef2.deposit(from: <- vaultRef.withdraw(amount: initialFundingAmt))
        }

        let cap1 = newAccount1.linkAccount(HybridCustody.LinkedAccountPrivatePath)
            ?? panic("problem linking account Capability for new account")
        FGameLotteryFactory.initializeFIXESMintingLotteryPool(controller, newAccount: cap1)

        let cap2 = newAccount2.linkAccount(HybridCustody.LinkedAccountPrivatePath)
            ?? panic("problem linking account Capability for new account")
        FGameLotteryFactory.initializeFIXESLotteryPool(controller, newAccount: cap2)
    }
}
