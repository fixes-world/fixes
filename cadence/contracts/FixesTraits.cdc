// Thirdparty Imports
import "MetadataViews"

/// The `FixesTraits` contract
///
pub contract FixesTraits {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()

    /* --- Variable, Enums and Structs --- */

    /* --- Interfaces & Resources --- */

    init() {
        emit ContractInitialized()
    }
}
