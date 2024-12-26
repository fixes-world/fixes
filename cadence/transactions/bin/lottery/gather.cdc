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

transaction() {
    let controller: auth(FGameLotteryRegistry.Manage) &FGameLotteryRegistry.RegistryController

    prepare(acct: auth(Storage, Capabilities) &Account) {
        // ----- Setup the lottery controller -----

        // Create the lottery controller if it doesn't exist
        if acct.storage.borrow<&FGameLotteryRegistry.RegistryController>(from: FGameLotteryRegistry.registryControllerStoragePath) == nil {
            acct.storage.save(<- FGameLotteryRegistry.createController(), to: FGameLotteryRegistry.registryControllerStoragePath)
        }
        self.controller = acct.storage
            .borrow<auth(FGameLotteryRegistry.Manage) &FGameLotteryRegistry.RegistryController>(
            from: FGameLotteryRegistry.registryControllerStoragePath
        ) ?? panic("Could not borrow the registry controller")
    }

    execute {
        self.controller.gatherJackpots()
    }
}
