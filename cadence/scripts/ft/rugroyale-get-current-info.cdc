import "FungibleTokenMetadataViews"
// Fixes Imports
import "Fixes"
import "FGameRugRoyale"

access(all)
fun main(): FGameRugRoyale.BattleRoyaleInfo? {
    let center = FGameRugRoyale.borrowGameCenter()
    if let current = center.borrowCurrentGame() {
        return current.getInfo()
    }
    return nil
}
