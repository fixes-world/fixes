// Third Party Imports
import "FungibleToken"
import "FlowToken"
// Fixes Imports
import "Fixes"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20Staking"

access(all) contract FRC20StakingManager {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /* --- Variable, Enums and Structs --- */
    access(all)
    let StakingAdminStoragePath: StoragePath

    /* --- Interfaces & Resources --- */

    /// Staking Admin Resource, represents a staking admin and store in admin's account
    ///
    access(all) resource StakingAdmin {

    }

    /** ---- public methods ---- */


    init() {
        let identifier = "FRC20Staking_".concat(self.account.address.toString())
        self.StakingAdminStoragePath = StoragePath(identifier: identifier.concat("_admin"))!

        emit ContractInitialized()
    }
}
