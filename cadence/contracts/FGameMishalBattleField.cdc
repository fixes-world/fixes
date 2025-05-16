/**
> Author: Fixes Lab <https://github.com/fixes-world/>

# FGameMishalBattleField

This contract is a battlefield game contract. It allows users to buy tickets to setup characters and battle with each other.

*/
import "Burner"
// Fixes Imports
import "Fixes"
import "FixesHeartbeat"

access(all) contract FGameMishalBattleField {

    access(all) entitlement CommanderControl
    access(all) entitlement SessionManage
    access(all) entitlement Creator

    // The Pawn resource is refered to as the character in the game.
    access(all) resource Pawn {

    }

    // The Commander resource is refered to as the player in the game.
    access(all) resource Commander {
    }

    // The Session resource is refered to as the battle in the game.
    access(all) resource Session {
    }

    // The World resource is refered to as the world in the game.
    access(all) resource World {
    }
}