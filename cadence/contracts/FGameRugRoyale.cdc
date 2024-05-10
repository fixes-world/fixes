/**
> Author: FIXeS World <https://fixes.world/>

# Fixes Rug Royale Contract

This contract is a memecoin race named "Rug Royale".
There will only be one Rug Royale Game at the same time.
Only FixesFungibleToken can participate in the game.

Game Schedule:
- The game epoch will last for at least 7 days
- The game will start if more 32 coins are joined
- The game lasts for a maximum of 5 rounds, with the first round lasting for 3 days, and each subsequent round lasting for 1 day.
    - Phase 1: N -> 32, at least 3 days
    - Phase 2: 32 -> 16, last 1 day
    - Phase 3: 16 -> 8, last 1 day
    - Phase 4: 8 -> 4, last 1 day
    - Phase 5: 4 -> #1, #4 will be winner, last 1 day
- All liquidity will gradually be aggregated towards the winners of each round, and losers will lose all liquidity in its' TradablePool.
- The same token can participate in multiple game epoches, but after elimination in one game, it can only participate again in the next game.
*/
import "FungibleToken"
// Fixes
import "Fixes"
import "FixesHeartbeat"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FixesTradablePool"
import "FRC20FTShared"
import "FRC20AccountsPool"

/// Rug Royale Game Contract
///
access(all) contract FGameRugRoyale {

    // ------ Events -------
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()


    /// -------- Resources and Interfaces --------

    /// The public interface for the Game
    ///
    access(all) resource interface GameCenterPublic {

    }

    /// The Game Resource
    ///
    access(all) resource GameCenter: GameCenterPublic, FixesHeartbeat.IHeartbeatHook {

        // ----- Implement IHeartbeatHook -----

        /// The methods that is invoked when the heartbeat is executed
        /// Before try-catch is deployed, please ensure that there will be no panic inside the method.
        ///
        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            // TODO: Implement the heartbeat logic
        }
    }

    /// ------ Public Methods ------

    access(all)
    view fun borrowGameCenter(): &GameCenter{GameCenterPublic, FixesHeartbeat.IHeartbeatHook} {
        return getAccount(self.account.address)
            .getCapability<&GameCenter{GameCenterPublic, FixesHeartbeat.IHeartbeatHook}>(self.getGameCenterPublicPath())
            .borrow()
            ?? panic("GameCenter not found")
    }

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FixesRugRoyale_".concat(self.account.address.toString()).concat("_")
    }

    /// Get the storage path for the Liquidity Pool
    ///
    access(all)
    view fun getGameCenterStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("Default"))!
    }

    /// Get the public path for the Liquidity Pool
    ///
    access(all)
    view fun getGameCenterPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Default"))!
    }

    init() {
        // Create the GameCenter
        let storagePath = self.getGameCenterStoragePath()
        self.account.save(<- create GameCenter(), to: storagePath)
        // Link the GameCenter to the public path
        // @deprecated in Cadence 1.0
        self.account.link<&GameCenter{GameCenterPublic, FixesHeartbeat.IHeartbeatHook}>(
            self.getGameCenterPublicPath(),
            target: storagePath
        )

        emit ContractInitialized()
    }
}
