/**
> Author: FIXeS World <https://fixes.world/>

# FGameLottery

This contract is a lottery game contract. It allows users to buy tickets and participate in the lottery.
The lottery is drawn every epoch. The winner is selected randomly from the participants.

*/
// Fixes Imports
import "Fixes"
import "FRC20Indexer"

access(all) contract FGameLottery {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /* --- Variable, Enums and Structs --- */


    /* --- Interfaces & Resources --- */

    /* --- Public methods  --- */

    init() {
        // Emit the ContractInitialized event
        emit ContractInitialized()
    }
}
