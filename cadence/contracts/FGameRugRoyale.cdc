/**
> Author: FIXeS World <https://fixes.world/>

# Fixes Rug Royale Contract

This contract is a memecoin race named "Rug Royale".
There will only be one Rug Royale Game at the same time.
Only FixesFungibleToken can participate in the game.

Game Schedule:
- The game epoch will last for at least 7 days
- The game will start if more 32 coins are joined
- The game lasts for a maximum of 5 rounds:
    - Phase 1: N -> 32, at least 3 days
    - Phase 2: 32 -> 16
    - Phase 3: 16 -> 8
    - Phase 4: 8 -> 4
    - Phase 5: 4 -> #1, #4 will be winner
- All liquidity will gradually be aggregated towards the winners of each round, and losers will lose all liquidity in its' TradablePool.
- The same token can participate in multiple game epoches, but after elimination in one game, it can only participate again in the next game.
*/
import "FungibleToken"
import "FlowToken"
// Fixes
import "Fixes"
import "FixesHeartbeat"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"

/// Rug Royale Game Contract
///
access(all) contract FGameRugRoyale {

    // ------ Events -------
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a new game is started
    access(all) event GameStarted(epochId: UInt64, startAt: UFix64)

    /// Event emitted when a new participant joined the game
    access(all) event GameParticipantJoined(epochId: UInt64, participant: Address)

    /// -------- Resources and Interfaces --------

    /// Enum for the game phases
    access(all) enum GamePhase: UInt8 {
        access(all) case P0_Waiting
        access(all) case P1_Nto32
        access(all) case P2_32to16
        access(all) case P3_16to8
        access(all) case P4_8to4
        access(all) case P5_4to1
        access(all) case Ended
    }

    /// The public interface for the liquidity holder
    ///
    access(all) resource interface LiquidityHolder {
        // --- read methods ---

        /// Get the liquidity market cap
        access(all)
        view fun getLiquidityMarketCap(): UFix64

        /// Get the liquidity pool value
        access(all)
        view fun getLiquidityValue(): UFix64

        /// Get the flow balance in pool
        access(all)
        view fun getFlowBalanceInPool(): UFix64

        /// Get the token balance in pool
        access(all)
        view fun getTokenBalanceInPool(): UFix64

        /// Get the token price in flow
        access(all)
        view fun getTokenPriceInFlow(): UFix64

        /// Get the token price by current liquidity
        access(all)
        view fun getTokenPriceByInPoolLiquidity(): UFix64 {
            let currentFlowBalance = self.getFlowBalanceInPool()
            if currentFlowBalance == 0.0 {
                return 0.0
            }
            return self.getTokenBalanceInPool() / currentFlowBalance
        }

        /// Get the total token market cap
        access(all)
        view fun getTotalTokenMarketCap(): UFix64

        /// Get the total token supply value
        access(all)
        view fun getTotalTokenValue(): UFix64

        /// Get the token holders
        access(all)
        view fun getHolders(): UInt64
        /// Get the trade count
        access(all)
        view fun getTrades(): UInt64

        // --- write methods ---

        /// Pull liquidity from the pool
        access(account)
        fun pullLiquidity(): @FungibleToken.Vault {
            pre {
                self.getLiquidityValue() > 0.0: "No liquidity to pull"
            }
            post {
                result.balance == before(self.getLiquidityValue()): "Invalid result balance"
                result.isInstance(Type<@FlowToken.Vault>()): "Invalid result type"
            }
        }
        /// Push liquidity to the pool
        access(account)
        fun addLiquidity(_ vault: @FungibleToken.Vault) {
            pre {
                vault.balance > 0.0: "No liquidity to push"
                vault.isInstance(Type<@FlowToken.Vault>()): "Invalid result type"
            }
        }
        /// Transfer liquidity to swap pair
        access(account)
        fun transferLiquidity() {
            post {
                self.getLiquidityValue() == 0.0: "Liquidity not transferred"
            }
        }
    }

    /// Struct for the game phase record
    ///
    access(all) struct BattlePhaseResult {
        access(all) let phase: GamePhase
        access(all) let participents: [Address]
        access(all) let winners: [Address]

        init(
            _ phase: GamePhase,
            _ participents: [Address],
            _ winners: [Address]
        ) {
            self.phase = phase
            self.participents = participents
            self.winners = winners
        }
    }

    /// Struct for the game information
    ///
    access(all) struct BattleRoyaleInfo {
        access(all) let epochIndex: UInt64
        access(all) let epochStartAt: UFix64
        access(all) let activatedAt: UFix64?
        access(all) let phase: GamePhase
        access(all) let participantAmount: Int
        access(all) let phaseRecords: [BattlePhaseResult]

        init(
            _ epochIndex: UInt64,
            _ epochStartAt: UFix64,
            _ activatedAt: UFix64?,
            _ phase: GamePhase,
            _ participantAmount: Int,
            _ phaseRecords: [BattlePhaseResult]
        ) {
            self.epochIndex = epochIndex
            self.epochStartAt = epochStartAt
            self.activatedAt = activatedAt
            self.participantAmount = participantAmount
            self.phase = phase
            self.phaseRecords = phaseRecords
        }
    }

    /// The public interface for the game
    ///
    access(all) resource interface BattleRoyalePublic {
        // ------ read methods ------

        /// Game info - public view
        access(all)
        view fun getInfo(): BattleRoyaleInfo
        /// get current game phase
        access(all)
        view fun getCurrentPhase(): GamePhase
        /// get game start time
        access(all)
        view fun getGameStartTime(): UFix64?
        /// get game end time
        access(all)
        view fun getGameEndTime(): UFix64?
        /// Return the participant addresses
        access(all)
        view fun getParticipants(): [Address]
        /// Return the participant amount
        access(all)
        view fun getParticipantAmount(): Int
        /// Return the alive participant addresses
        access(all)
        view fun getAliveParticipants(): [Address]
        /// Return the phase records
        access(all)
        view fun getPhaseRecords(): [BattlePhaseResult]

        // ------ read methods: default implement ------

        /// Check if the game is joinable
        access(all)
        view fun isJoinable(): Bool {
            let phase = self.getCurrentPhase()
            return phase == GamePhase.P0_Waiting || phase == GamePhase.P1_Nto32
        }

        /// Check if the game is started
        access(all)
        view fun isStarted(): Bool {
            return self.getGameStartTime() != nil
        }

        // ------ write methods ------

        /// Join the game
        access(contract)
        fun joinGame(_ cap: Capability<&{LiquidityHolder}>)

        /// Go to the next phase
        access(contract)
        fun nextPhase()
    }

    /// The resource of rug royale game
    ///
    access(all) resource BattleRoyale: BattleRoyalePublic {
        /// Game epoch index
        access(all)
        let epochIndex: UInt64
        /// Game epoch start time
        access(all)
        let epochStartAt: UFix64
        /// Game activated time
        access(self)
        var activatedAt: UFix64?
        /// All memecoin participants: FT Address => Capability
        access(self)
        let participants: {Address: Capability<&{LiquidityHolder}>}
        /// Current alive participants: FT Address => Is Alive
        access(self)
        let participantsAlive: {Address: Bool}
        /// Game phase records
        access(self)
        let phaseRecords: [BattlePhaseResult]

        init(
            _ epochIndex: UInt64,
        ) {
            self.epochIndex = epochIndex
            self.epochStartAt = getCurrentBlock().timestamp
            self.activatedAt = nil
            self.participants = {}
            self.participantsAlive = {}
            self.phaseRecords = []
        }

        // ------- Implement BattleRoyalePublic -------

        /// Game info - public view
        ///
        access(all)
        view fun getInfo(): BattleRoyaleInfo {
            return BattleRoyaleInfo(
                self.epochIndex,
                self.epochStartAt,
                self.activatedAt,
                self.getCurrentPhase(),
                self.getParticipantAmount(),
                self.getPhaseRecords()
            )
        }

        /// get current game phase
        access(all)
        view fun getCurrentPhase(): GamePhase {
            if let startedAt = self.activatedAt {
                let gamePassed = getCurrentBlock().timestamp - startedAt
                var phase = GamePhase.P1_Nto32
                var currentDuration = FGameRugRoyale.getGamePhaseDuration(phase)
                while gamePassed > currentDuration {
                    phase = GamePhase(rawValue: phase.rawValue + 1)!
                    if phase == GamePhase.Ended {
                        break
                    }
                    currentDuration = currentDuration + FGameRugRoyale.getGamePhaseDuration(phase)
                }
                return phase
            }
            return GamePhase.P0_Waiting
        }

        /// get game start time
        access(all)
        view fun getGameStartTime(): UFix64? {
            return self.activatedAt
        }

        /// get game end time
        access(all)
        view fun getGameEndTime(): UFix64? {
            if let startedAt = self.activatedAt {
                return startedAt + FGameRugRoyale.getGameDurationUtil(GamePhase.Ended, from: GamePhase.P1_Nto32)
            }
            return nil
        }

        /// Return the participant addresses
        access(all)
        view fun getParticipants(): [Address] {
            return self.participants.keys
        }

        /// Return the participant amount
        access(all)
        view fun getParticipantAmount(): Int {
            return self.participants.length
        }

        /// Return the alive participant addresses
        access(all)
        view fun getAliveParticipants(): [Address] {
            var ret: [Address] = []
            let ref = &self.participantsAlive as &{Address: Bool}
            self.participants.forEachKey(fun (key: Address): Bool {
                if ref[key] == true {
                    ret = ret.concat([key])
                }
                return true
            })
            return ret
        }

        /// Return the phase records
        access(all)
        view fun getPhaseRecords(): [BattlePhaseResult] {
            return self.phaseRecords
        }

        // ------- Contract access methods -------

        /// Join the game
        access(contract)
        fun joinGame(_ cap: Capability<&{LiquidityHolder}>) {
            pre {
                self.isJoinable(): "The game is not joinable"
                cap.check() == true: "Invalid capability"
            }
            // Add the participant
            self.participants[cap.address] = cap
            self.participantsAlive[cap.address] = true

            // emit event
            emit GameParticipantJoined(
                epochId: self.epochIndex,
                participant: cap.address
            )
        }

        /// Go to the next phase
        ///
        access(contract)
        fun nextPhase() {
            // TODO
        }

        // ------- Internal methods -------

        /// Get the liquidity holder reference
        ///
        access(self)
        fun borrowLiquidHolderRef(_ address: Address): &{LiquidityHolder} {
            let cap = self.participants[address] ?? panic("LiquidityHolder not found")
            return cap.borrow() ?? panic("LiquidityHolder not found")
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

        /// Check if the current Game is finished
        access(all)
        view fun isCurrentGameFinished(): Bool {
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
                self.isCurrentGameFinished(): "The current Game is not finished"
            }

            // Create a new Game
            let newEpochIndex = self.currentEpochIndex + 1
            let newOne <- create BattleRoyale(newEpochIndex)

            let startedAt = newOne.epochStartAt

            // Save the new Game
            self.games[newEpochIndex] <-! newOne
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
    view fun getGamePhaseDuration(_ phase: GamePhase): UFix64 {
        // Seconds in half a day
        let oneday = 60.0 * 60.0 * 24.0
        switch phase {
        case GamePhase.P0_Waiting:
            return UFix64.max
        case GamePhase.Ended:
            return 0.0
        case GamePhase.P1_Nto32:
            return oneday * 3.0
        default:
            return oneday
        }
    }

    /// Get the duration of a game period
    ///
    access(all)
    view fun getGameDurationUtil(_ endPhase: GamePhase, from: GamePhase?): UFix64 {
        var currentPhase = from ?? GamePhase.P0_Waiting
        if currentPhase == GamePhase.Ended {
            return 0.0
        }
        if currentPhase == GamePhase.P0_Waiting {
            return UFix64.max
        }
        if endPhase.rawValue <= currentPhase.rawValue {
            return 0.0
        }
        var gameDuration = self.getGamePhaseDuration(currentPhase)
        // Calculate to the target phase, how long the game has passed
        while currentPhase.rawValue < endPhase.rawValue {
            currentPhase = GamePhase(rawValue: currentPhase.rawValue + 1)!
            if currentPhase.rawValue == GamePhase.Ended.rawValue {
                break
            }
            gameDuration = gameDuration + self.getGamePhaseDuration(currentPhase)
        }
        return gameDuration
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
