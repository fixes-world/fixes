/**
> Author: FIXeS World <https://fixes.world/>

# Fixes Rug Royale Contract

This contract is a memecoin race named "Rug Royale".
There will only be one Rug Royale Game at the same time.
Only FixesFungibleToken can participate in the game.

Game Schedule:
- The game epoch will last for at least 3 days
- The game will start if more 32 coins are joined
- The game lasts for a maximum of 5 rounds:
    - Phase 1: N -> 32, at least 1 days
    - Phase 2: 32 -> 16, 0.5 day
    - Phase 3: 16 -> 8, 0.5 day
    - Phase 4: 8 -> 4, 0.5 day
    - Phase 5: 4 -> #1, #4 will be winner, 0.5 day
- All liquidity will gradually be aggregated towards the winners of each round, and losers will lose all liquidity in its' TradablePool.
- The same token can participate in multiple game epoches, but after elimination in one game, it can only participate again in the next game.
*/
import "FungibleToken"
// Fixes
import "Fixes"
import "FixesHeartbeat"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20AccountsPool"

/// Rug Royale Game Contract
///
access(all) contract FGameRugRoyale {

    // ------ Events -------
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a new game is started
    access(all) event GameStarted(epochId: UInt64, startAt: UFix64)

    /// -------- Resources and Interfaces --------

    /// Enum for the game phases
    access(all) enum GamePhases: UInt8 {
        access(all) case Phase1To32
        access(all) case Phase2To16
        access(all) case Phase3To8
        access(all) case Phase4To4
        access(all) case Phase5To1
    }

    /// The public interface for the liquidity holder
    ///
    access(all) resource interface LiquidityHolder {
        /// Get the liquidity market cap
        access(all)
        view fun getLiquidityMarketCap(): UFix64
        /// Get the liquidity pool value
        access(all)
        view fun getLiquidityValue(): UFix64
        /// Get the token holders
        access(all)
        view fun getHolders(): UInt64
        /// Get the trade count
        access(all)
        view fun getTrades(): UInt64
    }

    /// The public interface for the game
    ///
    access(all) resource interface BattleRoyalePublic {

    }

    /// The resource of rug royale game
    ///
    access(all) resource BattleRoyale: BattleRoyalePublic {
        /// Lottery epoch index
        access(all)
        let epochIndex: UInt64
        /// Lottery epoch start time
        access(all)
        let epochStartAt: UFix64
        access(all)
        var gameActivatedAt: UFix64?

        init(
            _ epochIndex: UInt64,
        ) {
            self.epochIndex = epochIndex
            self.epochStartAt = getCurrentBlock().timestamp
            self.gameActivatedAt = nil
        }

    }

    /// The public interface for the GameCenter
    ///
    access(all) resource interface GameCenterPublic {
        access(all)
        view fun getCurrentEpochIndex(): UInt64
        access(all)
        view fun borrowGame(_ epochIndex: UInt64): &BattleRoyale{BattleRoyalePublic}?
        access(all)
        view fun borrowCurrentGame(): &BattleRoyale{BattleRoyalePublic}?

        // --- read methods: default implement ---

        /// Check if the current lottery is finished
        access(all)
        view fun isCurrentLotteryFinished(): Bool {
            let currentGame = self.borrowCurrentGame()
            // TODO
            return false
        }

        // --- write methods ---

        // --- Internal methods ---
        access(contract)
        fun borrowSelf(): &GameCenter
    }

    /// The GameCenter Resource
    ///
    access(all) resource GameCenter: GameCenterPublic, FixesHeartbeat.IHeartbeatHook {
        access(self)
        let games: @{UInt64: BattleRoyale}
        access(self)
        var currentEpochIndex: UInt64

        init() {
            self.games <- {}
            self.currentEpochIndex = 0
        }

        // @deprecated in Cadence 1.0
        destroy() {
            destroy self.games
        }

        /** ---- Public Methods ---- */

        access(all)
        view fun getCurrentEpochIndex(): UInt64 {
            return self.currentEpochIndex
        }

        access(all)
        view fun borrowGame(_ epochIndex: UInt64): &BattleRoyale{BattleRoyalePublic}? {
            return self.borrowBattleRoyaleRef(epochIndex)
        }

        access(all)
        view fun borrowCurrentGame(): &BattleRoyale{BattleRoyalePublic}? {
            return self.borrowBattleRoyaleRef(self.currentEpochIndex)
        }

        /** ---- Admin Methods ----- */

        /// Start a new epoch
        ///
        access(all)
        fun startNewEpoch() {
            pre {
                self.isCurrentLotteryFinished(): "The current lottery is not finished"
            }

            // Create a new lottery
            let newEpochIndex = self.currentEpochIndex + 1
            let newLottery <- create BattleRoyale(newEpochIndex)

            let startedAt = newLottery.epochStartAt

            // Save the new lottery
            self.games[newEpochIndex] <-! newLottery
            self.currentEpochIndex = newEpochIndex

            // emit event
            emit GameStarted(
                epochId: newEpochIndex,
                startAt: startedAt
            )
        }

        // ----- Implement IHeartbeatHook -----

        /// The methods that is invoked when the heartbeat is executed
        /// Before try-catch is deployed, please ensure that there will be no panic inside the method.
        ///
        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            // TODO: Implement the heartbeat logic
        }

        // --- Internal Methods ---

        access(contract)
        fun borrowSelf(): &GameCenter {
            return &self as &GameCenter
        }

        access(self)
        fun borrowBattleRoyaleRef(_ epochIndex: UInt64): &BattleRoyale? {
            return &self.games[epochIndex] as &BattleRoyale?
        }
    }

    /// ------ Public Methods ------

    /// Get the duration of a game period
    ///
    access(all)
    view fun getGamePhaseDuration(_ phase: GamePhases): UFix64 {
        // Seconds in half a day
        let halfaday = 60.0 * 60.0 * 12.0
        if phase == GamePhases.Phase1To32 {
            return halfaday * 2.0
        } else {
            return halfaday
        }
    }

    /// Borrow the GameCenter
    ///
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
