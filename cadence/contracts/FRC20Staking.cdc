import "Fixes"
import "FRC20Indexer"

pub contract FRC20Staking {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()

    /* --- Variable, Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    init() {
        emit ContractInitialized()
    }
}
