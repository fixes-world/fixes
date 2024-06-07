import "FTViewUtils"
import "ViewResolver"
import "FungibleTokenMetadataViews"
// Fixes Imports
import "Fixes"
import "FGameRugRoyale"

access(all)
fun main(
    includeAll: Bool
): [Address] {
    let center = FGameRugRoyale.borrowGameCenter()
    if let current = center.borrowCurrentGame() {
        return includeAll
            ? current.getParticipants()
            : current.getAliveParticipants()
    }
    return []
}
