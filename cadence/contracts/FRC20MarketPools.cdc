// Third-party imports
import "StringUtils"
import "MetadataViews"
import "FungibleTokenMetadataViews"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FRC20FTShared"

pub contract FRC20MarketPools {

    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()

    /* --- Variable, Enums and Structs --- */


    /* --- Interfaces & Resources --- */


    init() {

        emit ContractInitialized()
    }
}
