/**
> Author: FIXeS World <https://fixes.world/>

# FGameLottery

This contract is a lottery game contract. It allows users to buy tickets and participate in the lottery.
The lottery is drawn every epoch. The winner is selected randomly from the participants.

*/
// Fixes Imports
import "Fixes"
import "FixesHeartbeat"
import "FRC20FTShared"
import "FRC20Indexer"
import "FGameLottery"
import "FRC20Staking"
import "FRC20AccountsPool"

access(all) contract FGameLotteryRegistry {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /* --- Variable, Enums and Structs --- */

    access(all) let registryStoragePath: StoragePath
    access(all) let registryPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    /// Resource inferface for the Lottery registry
    ///
    access(all) resource interface RegistryPublic {

    }

    /// Resource for the Lottery registry
    ///
    access(all) resource Registry: RegistryPublic {

    }

    /* --- Public methods  --- */

    /// Borrow Lottery Pool Registry
    ///
    access(all)
    fun borrowRegistry(): &Registry{RegistryPublic} {
        return getAccount(self.account.address)
            .getCapability<&Registry{RegistryPublic}>(self.registryPublicPath)
            .borrow()
            ?? panic("Registry not found")
    }

    init() {
        // Identifiers
        let identifier = "FGameLottery_".concat(self.account.address.toString())
        self.registryStoragePath = StoragePath(identifier: identifier.concat("_Registry"))!
        self.registryPublicPath = PublicPath(identifier: identifier.concat("_Registry"))!

        // save registry
        let registry <- create Registry()
        self.account.save(<- registry, to: self.registryStoragePath)

        // @deprecated in Cadence 1.0
        self.account.link<&Registry{RegistryPublic}>(self.registryPublicPath, target: self.registryStoragePath)

        // Emit the ContractInitialized event
        emit ContractInitialized()
    }
}
