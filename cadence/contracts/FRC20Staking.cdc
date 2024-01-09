import "Fixes"
import "FRC20Indexer"

access(all) contract FRC20Staking {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /* --- Variable, Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    init() {
        emit ContractInitialized()
    }
}
