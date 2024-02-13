/**
> Author: FIXeS World <https://fixes.world/>

# FGameLottery

This contract is a lottery game contract. It allows users to buy tickets and participate in the lottery.
The lottery is drawn every epoch. The winner is selected randomly from the participants.

*/
// Fixes Imports
import "Fixes"
import "FixesHeartbeat"
import "FRC20Indexer"
import "FRC20Staking"

access(all) contract FGameLottery {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /* --- Variable, Enums and Structs --- */

    access(all)
    let userCollectionStoragePath: StoragePath
    access(all)
    let userCollectionPublicPath: PublicPath
    access(all)
    let registryStoragePath: StoragePath
    access(all)
    let registryPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    access(all) resource TicketEntry {

    }

    access(all) resource TicketCollection {

    }

    /// Lottery pool resource
    ///
    access(all) resource LotteryPool {

    }

    /// Resource inferface for the Lottery registry
    ///
    access(all) resource interface RegistryPublic {

    }

    /// Resource for the Lottery registry
    ///
    access(all) resource Registry: RegistryPublic {

    }

    /* --- Public methods  --- */

    init() {
        let identifier = "FGameLottery_".concat(self.account.address.toString())
        self.userCollectionStoragePath = StoragePath(identifier: identifier.concat("_UserCollection"))!
        self.userCollectionPublicPath = PublicPath(identifier: identifier.concat("_UserCollection"))!

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
