/**
> Author: FIXeS World <https://fixes.world/>

# Fixes Rug Royale Contract

This contract is a memecoin race named "Rug Royale".
There will only be one Rug Royale Game at the same time.
Only FixesFungibleToken can participate in the game.

Game Schedule:
- The game epoch will last for at least 7 days
- The game will start if more 24 coins are joined
- The game lasts for a maximum of 5 rounds:
    - Phase 1: N -> 24, at least 3 days
    - Phase 2: 24 -> 16
    - Phase 3: 16 -> 8
    - Phase 4: 8 -> 4
    - Phase 5: 4 -> #1: The winner of the game, get 50% liquidity, the rest will be shared other top 2~4 winners by #2 10%, #3 10%, #4 30%.
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

    /// Event emitted when the game phase changed
    access(all) event GameActivated(epochId: UInt64, at: UFix64)

    /// Event emitted when the game phase changed
    access(all) event GamePhaseChanged(epochId: UInt64, prev: UInt8, current: UInt8, winners: [Address])

    /// Event emitted when a new participant joined the game
    access(all) event GameParticipantJoined(epochId: UInt64, participant: Address)

    /// Event emitted when a participant escaped from the game
    access(all) event GameParticipantEscaped(epochId: UInt64, participant: Address, phase: UInt8)

    /// Event emitted when a participant is eliminated from the game
    access(all) event GameParticipantEliminated(epochId: UInt64, participant: Address, phase: UInt8, liquidity: UFix64, holders: UInt64, Trades: UInt64)

    /// Event emitted when a participant's liquidity is rugged
    access(all) event GameParticipantLiquidityRugged(epochId: UInt64, participant: Address, phase: UInt8, liquidity: UFix64)

    /// Event emitted when a participant's liquidity is transferred
    access(all) event GameParticipantLiquidityTransferred(epochId: UInt64, participant: Address, phase: UInt8, liquidity: UFix64)

    /// -------- Resources and Interfaces --------

    /// Enum for the game phases
    access(all) enum GamePhase: UInt8 {
        access(all) case P0_Waiting
        access(all) case P1_Nto24
        access(all) case P2_24to16
        access(all) case P3_16to8
        access(all) case P4_8to4
        access(all) case P5_4toWinners
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
            let tokenBalance = self.getTokenBalanceInPool()
            if tokenBalance == 0.0 {
                return 0.0
            }
            let currentFlowBalance = self.getFlowBalanceInPool()
            return currentFlowBalance / tokenBalance
        }

        /// Get the token price with extra liquidity
        access(all)
        view fun getTokenPriceWithExtraLiquidity(_ extraLiquidity: UFix64): UFix64 {
            let tokenBalance = self.getTokenBalanceInPool()
            if tokenBalance == 0.0 {
                return 0.0
            }
            let currentFlowBalance = self.getFlowBalanceInPool() + extraLiquidity
            return currentFlowBalance / tokenBalance
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

    /// Struct for the winner status
    ///
    access(all) struct WinnerStatus {
        access(all) let address: Address
        access(all) let liquidity: UFix64
        access(all) let holders: UInt64
        access(all) let trades: UInt64

        init(
            _ address: Address,
            _ liquidity: UFix64,
            _ holders: UInt64,
            _ trades: UInt64
        ) {
            self.address = address
            self.liquidity = liquidity
            self.holders = holders
            self.trades = trades
        }
    }

    /// Struct for the game phase record
    ///
    access(all) struct BattlePhaseResult {
        access(all) let phase: GamePhase
        access(all) let participents: [Address]
        access(all) let winners: [WinnerStatus]
        access(all) let at: UFix64

        init(
            _ phase: GamePhase,
            _ participents: [Address],
            _ winners: [WinnerStatus]
        ) {
            self.phase = phase
            self.participents = participents
            self.winners = winners
            self.at = getCurrentBlock().timestamp
        }
    }

    /// Struct for the winner result
    ///
    access(all) struct WinnerResult {
        access(all) let address: Address
        access(all) let holders: UInt64
        access(all) let trades: UInt64
        access(all) let liquidity: UFix64
        access(all) let rewardLiquidity: UFix64

        init(
            address: Address,
            holders: UInt64,
            trades: UInt64,
            liquidity: UFix64,
            rewardLiquidity: UFix64
        ) {
            self.address = address
            self.holders = holders
            self.trades = trades
            self.liquidity = liquidity
            self.rewardLiquidity = rewardLiquidity
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
        access(all) let finalWinners: [WinnerResult]?

        init(
            _ epochIndex: UInt64,
            _ epochStartAt: UFix64,
            _ activatedAt: UFix64?,
            _ phase: GamePhase,
            _ participantAmount: Int,
            _ phaseRecords: [BattlePhaseResult],
            _ finalWinners: [WinnerResult]?
        ) {
            self.epochIndex = epochIndex
            self.epochStartAt = epochStartAt
            self.activatedAt = activatedAt
            self.participantAmount = participantAmount
            self.phase = phase
            self.phaseRecords = phaseRecords
            self.finalWinners = finalWinners
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
        /// get current estimated phase
        access(all)
        view fun getCurrentEstimatedPhase(): GamePhase
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
        /// Return the final winners
        access(all)
        view fun getFinalWinners(): [WinnerResult]?
        /// Get the liquidity balance in the game
        access(all)
        view fun getInGameLiquidityBalance(): UFix64
        /// Check if the address is rugged in the game
        access(all)
        view fun isRuggedInGame(_ address: Address): Bool
        /// Check if the address is escaped in the game
        access(all)
        view fun isEscapedInGame(_ address: Address): Bool
        /// Check if the address is alive in the game
        access(all)
        view fun isAliveInGame(_ address: Address): Bool

        // ------ read methods: default implement ------

        /// Check if the game is joinable
        access(all)
        view fun isJoinable(): Bool {
            let phase = self.getCurrentPhase()
            return phase == GamePhase.P0_Waiting || phase == GamePhase.P1_Nto24
        }

        /// Check if the game is started
        access(all)
        view fun isStarted(): Bool {
            return self.getGameStartTime() != nil
        }

        // ------ write methods ------

        /// Calculate the phase winners
        /// (Readonly) - This method will not change the state
        access(all)
        fun calculateCurrentPhaseWinners(): [WinnerStatus]

        /// Go to the next phase
        access(contract)
        fun tryUpdateByPhase()

        /// Join the game
        access(contract)
        fun joinGame(_ cap: Capability<&{LiquidityHolder}>)
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
        /// In-game liquidity vault
        access(self)
        let inGameLiquidity: @FungibleToken.Vault
        /// All memecoin participants: FT Address => Capability
        access(self)
        let participants: {Address: Capability<&{LiquidityHolder}>}
        /// Current alive participants: FT Address => Is Alive
        access(self)
        let participantsAlive: {Address: Bool}
        /// For the participants rug during the game
        access(self)
        let ruggedParticipants: [Address]
        /// For the participants escaped during the game
        access(self)
        let escapedParticipants: [Address]
        /// Game phase records, only P1 -> P5 has records
        access(self)
        let phaseRecords: [BattlePhaseResult]
        /// Final winners
        access(self)
        var finalWinners: [WinnerResult]?
        /// Game activated time
        access(self)
        var activatedAt: UFix64?

        init(
            _ epochIndex: UInt64,
        ) {
            self.epochIndex = epochIndex
            self.epochStartAt = getCurrentBlock().timestamp
            self.activatedAt = nil
            self.inGameLiquidity <- FlowToken.createEmptyVault()
            self.participants = {}
            self.participantsAlive = {}
            self.escapedParticipants = []
            self.ruggedParticipants = []
            self.phaseRecords = []
            self.finalWinners = nil
        }

        // @deprecated in Cadence 1.0
        destroy() {
            destroy self.inGameLiquidity
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
                self.phaseRecords,
                self.finalWinners
            )
        }

        /// get current game phase
        access(all)
        view fun getCurrentPhase(): GamePhase {
            if self.phaseRecords.length > 0 {
                let lastPhase = self.phaseRecords[0].phase
                return GamePhase(rawValue: lastPhase.rawValue + 1) ?? GamePhase.Ended
            }
            return GamePhase.P0_Waiting
        }

        /// get current estimated phase
        access(all)
        view fun getCurrentEstimatedPhase(): GamePhase {
            if let startedAt = self.activatedAt {
                let gamePassed = getCurrentBlock().timestamp - startedAt
                var phase = GamePhase.P1_Nto24
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
                return startedAt + FGameRugRoyale.getGameDurationUtil(GamePhase.Ended, from: GamePhase.P1_Nto24)
            }
            return nil
        }

        /// Get the liquidity balance in the game
        ///
        access(all)
        view fun getInGameLiquidityBalance(): UFix64 {
            return self.inGameLiquidity.balance
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
            self.participantsAlive.forEachKey(fun (key: Address): Bool {
                if ref[key] == true {
                    ret = ret.concat([key])
                }
                return true
            })
            return ret
        }

        /// Check if the address is rugged in the game
        access(all)
        view fun isRuggedInGame(_ address: Address): Bool {
            return self.ruggedParticipants.contains(address)
        }

        /// Check if the address is escaped in the game
        access(all)
        view fun isEscapedInGame(_ address: Address): Bool {
            return self.escapedParticipants.contains(address)
        }

        /// Check if the address is alive in the game
        access(all)
        view fun isAliveInGame(_ address: Address): Bool {
            return self.participantsAlive[address] == true
        }

        /// Return the phase records
        access(all)
        view fun getPhaseRecords(): [BattlePhaseResult] {
            return self.phaseRecords
        }

        /// Return the final winners
        access(all)
        view fun getFinalWinners(): [WinnerResult]? {
            return self.finalWinners
        }

        /// Calculate the phase winners
        access(all)
        fun calculateCurrentPhaseWinners(): [WinnerStatus] {
            let currentPhase = self.getCurrentPhase()
            if currentPhase == GamePhase.P0_Waiting {
                return []
            } else if currentPhase == GamePhase.Ended {
                return self.phaseRecords[0].winners
            }
            // Calculate the winners

            // Now we need to update the game data to the next phase
            let currentPhaseWinnerAmount = FGameRugRoyale.getGamePhaseWinners(currentPhase)

            // Record all liquidity value for all participants
            let activeParticipants = self.getAliveParticipants()
            let winners: [WinnerStatus] = []
            // find the winners
            for address in activeParticipants {
                if let liquidityHolder = self.borrowLiquidHolderRef(address) {
                    let liquidity = liquidityHolder.getLiquidityValue()
                    let holders = liquidityHolder.getHolders()
                    let trades = liquidityHolder.getTrades()
                    // if the liquidity is 0, that means no liquidity in the pool or transferred to the swap pair
                    if liquidity > 0.0 {
                        // if liquidity > 0.0, we need to check if the participant is a winner
                        let lastIndex = winners.length - 1
                        // check the winners first
                        var minLiquidity = 0.0
                        if winners.length > 0 {
                            minLiquidity = winners[lastIndex].liquidity
                        }
                        if winners.length >= Int(currentPhaseWinnerAmount) && liquidity <= minLiquidity {
                            continue
                        }

                        // find the position
                        var highBalanceIdx = 0
                        var lowBalanceIdx = lastIndex
                        // use binary search to find the position
                        while lowBalanceIdx >= highBalanceIdx {
                            let mid = (lowBalanceIdx + highBalanceIdx) / 2
                            let minRecord = &winners[mid] as &WinnerStatus
                            let midBalance = minRecord.liquidity
                            // find the position
                            if liquidity > midBalance {
                                lowBalanceIdx = mid - 1
                            } else if liquidity < midBalance {
                                highBalanceIdx = mid + 1
                            } else {
                                break
                            }
                        }
                        // insert the address
                        winners.insert(at: highBalanceIdx, WinnerStatus(
                            address,
                            liquidity,
                            holders,
                            trades
                        ))

                        // remove the last one if the winners are more than the limit
                        if winners.length > Int(currentPhaseWinnerAmount) {
                            winners.removeLast()
                        }
                    } // end if liquidity > 0.0
                } // end if liquidityHolder exists
            } // end for
            return winners
        }

        // ------- Contract access methods -------

        /// Go to the next phase
        ///
        access(contract)
        fun tryUpdateByPhase() {
            let currentPhase = self.getCurrentPhase()
            switch currentPhase {
            case GamePhase.P0_Waiting:
                // Check how many participants are in the game, only start the game if more than 24 participants
                let participantAmount = UInt64(self.getParticipantAmount())
                let activateAmount = FGameRugRoyale.getGamePhaseWinners(GamePhase.P1_Nto24)
                if participantAmount >= activateAmount {
                    // Start the game
                    self.activatedAt = getCurrentBlock().timestamp
                    // init current participants in the game
                    self.phaseRecords.append(BattlePhaseResult(
                        GamePhase.P0_Waiting,
                        self.participants.keys,
                        []
                    ))
                    // emit event
                    emit GameActivated(
                        epochId: self.epochIndex,
                        at: self.activatedAt!
                    )
                }
                break
            default:
                let estimatedPhase = self.getCurrentEstimatedPhase()
                // This indicates that it is currently in this state or the game has ended
                if currentPhase.rawValue + 1 == estimatedPhase.rawValue || currentPhase.rawValue == GamePhase.Ended.rawValue {
                    // DO nothing
                    return
                }
                // Now we need to update the game data to the next phase
                let currentPhaseWinnerAmount = FGameRugRoyale.getGamePhaseWinners(currentPhase)

                // Record all liquidity value for all participants
                let activeParticipants = self.getAliveParticipants()
                let winners: [WinnerStatus] = []
                let eliminatedInThisRound: [Address] = []
                // find the winners
                for address in activeParticipants {
                    if let liquidityHolder = self.borrowLiquidHolderRef(address) {
                        let liquidity = liquidityHolder.getLiquidityValue()
                        let holders = liquidityHolder.getHolders()
                        let trades = liquidityHolder.getTrades()
                        // if the liquidity is 0, that means no liquidity in the pool or transferred to the swap pair
                        if liquidity == 0.0 {
                            // That means the participant is escaped, they are not eliminated by not alive anymore
                            // we need to record it
                            if liquidityHolder.getTokenPriceInFlow() > 0.0 {
                                self.participantsAlive[address] = false

                                // setup the participant as escaped
                                self.escapedParticipants.append(address)

                                // emit event
                                emit GameParticipantEscaped(
                                    epochId: self.epochIndex,
                                    participant: address,
                                    phase: currentPhase.rawValue
                                )
                            } else {
                                // set the participant as not alive
                                self.setParticipantEliminated(address, currentPhase.rawValue)
                                eliminatedInThisRound.append(address)
                            }
                        } else {
                            // if liquidity > 0.0, we need to check if the participant is a winner
                            let lastIndex = winners.length - 1
                            // check the winners first
                            var minLiquidity = 0.0
                            if winners.length > 0 {
                                minLiquidity = winners[lastIndex].liquidity
                            }
                            if winners.length >= Int(currentPhaseWinnerAmount) && liquidity <= minLiquidity {
                                // set the participant as not alive
                                self.setParticipantEliminated(address, currentPhase.rawValue)
                                eliminatedInThisRound.append(address)
                            } else {
                                // find the position
                                var highBalanceIdx = 0
                                var lowBalanceIdx = lastIndex
                                // use binary search to find the position
                                while lowBalanceIdx >= highBalanceIdx {
                                    let mid = (lowBalanceIdx + highBalanceIdx) / 2
                                    let minRecord = &winners[mid] as &WinnerStatus
                                    let midBalance = minRecord.liquidity
                                    // find the position
                                    if liquidity > midBalance {
                                        lowBalanceIdx = mid - 1
                                    } else if liquidity < midBalance {
                                        highBalanceIdx = mid + 1
                                    } else {
                                        break
                                    }
                                }
                                // insert the address
                                winners.insert(at: highBalanceIdx, WinnerStatus(
                                    address,
                                    liquidity,
                                    holders,
                                    trades
                                ))

                                // remove the last one if the winners are more than the limit
                                if winners.length > Int(currentPhaseWinnerAmount) {
                                    let removed = winners.removeLast()
                                    // set the participant as not alive
                                    self.setParticipantEliminated(removed.address, currentPhase.rawValue)
                                    eliminatedInThisRound.append(removed.address)
                                }
                            } // end if liquidity > minLiquidity
                        } // end if liquidity > 0.0
                    } // end if liquidityHolder exists
                } // end for

                // winners should be sorted by liquidity
                // insert the phase record to the first position
                self.phaseRecords.insert(at: 0, BattlePhaseResult(
                    currentPhase,
                    activeParticipants,
                    winners
                ))

                // all liquidity will be aggregated towards the winners of each round(except the first round)
                let isCurrentPhase1 = currentPhase == GamePhase.P1_Nto24
                let isCurrentLastPhase = currentPhase == GamePhase.P5_4toWinners

                // The first and last phase will not rug the losers
                if !isCurrentPhase1 && !isCurrentLastPhase && eliminatedInThisRound.length > 0 {
                    // rug the losers' liquidity
                    for loser in eliminatedInThisRound {
                        if let liquidityHolder = self.borrowLiquidHolderRef(loser) {
                            // set the participant as rugged
                            if !self.ruggedParticipants.contains(loser) {
                                self.ruggedParticipants.append(loser)
                            }
                            // pull the liquidity
                            let vault <- liquidityHolder.pullLiquidity()
                            if vault.balance > 0.0 {
                                let amount = vault.balance
                                self.inGameLiquidity.deposit(from: <- vault)

                                emit GameParticipantLiquidityRugged(
                                    epochId: self.epochIndex,
                                    participant: loser,
                                    phase: currentPhase.rawValue,
                                    liquidity: amount
                                )
                            } else {
                                destroy vault
                            }
                        }
                    }
                }

                // for the last phase, the winners will get the liquidity
                if isCurrentLastPhase && winners.length > 0 {
                    let totalLiquidity = self.inGameLiquidity.balance
                    let shares: [UFix64;4] = [
                        totalLiquidity * 0.5, // #1 winner get 50% liquidity
                        totalLiquidity * 0.1, // #2 winner get 10% liquidity
                        totalLiquidity * 0.1, // #3 winner get 10% liquidity
                        totalLiquidity * 0.3 // #4 winner get 30% liquidity
                    ]

                    // setup the final winners
                    let finalWinners: [WinnerResult] = []

                    // winners will get the liquidity
                    for i, winner in winners {
                        if let liquidityHolder = self.borrowLiquidHolderRef(winner.address) {
                            let winnerShare = i != winners.length - 1 ? shares[i] : self.inGameLiquidity.balance
                            let vault <- self.inGameLiquidity.withdraw(amount: winnerShare)

                            // add final winner record
                            finalWinners.append(WinnerResult(
                                address: winner.address,
                                holders: liquidityHolder.getHolders(),
                                trades: liquidityHolder.getTrades(),
                                liquidity: liquidityHolder.getLiquidityValue(),
                                rewardLiquidity: winnerShare
                            ))

                            // add liquidity to the winner
                            liquidityHolder.addLiquidity(<- vault)

                            emit GameParticipantLiquidityTransferred(
                                epochId: self.epochIndex,
                                participant: winner.address,
                                phase: currentPhase.rawValue,
                                liquidity: winnerShare
                            )

                            // transfer the liquidity to the swap pair
                            liquidityHolder.transferLiquidity()
                        }
                    }

                    // set the final winners
                    if finalWinners.length > 0 {
                        self.finalWinners = finalWinners
                    }
                }

                // the next phase
                let nextPhase = GamePhase(rawValue: currentPhase.rawValue + 1) ?? GamePhase.Ended

                // emit event
                emit GamePhaseChanged(
                    epochId: self.epochIndex,
                    prev: currentPhase.rawValue,
                    current: nextPhase.rawValue,
                    winners: winners.map(fun (winner: WinnerStatus): Address {
                        return winner.address
                    })
                )
                break
            }
        }

        /// Join the game
        access(contract)
        fun joinGame(_ cap: Capability<&{LiquidityHolder}>) {
            pre {
                self.isJoinable(): "The game is not joinable"
                cap.check() == true: "Invalid capability"
                self.participants[cap.address] == nil: "The participant already joined"
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

        // ------- Internal methods -------

        /// Set the participant as eliminated
        ///
        access(self)
        fun setParticipantEliminated(_ address: Address, _ phase: UInt8) {
            if let liquidityHolder = self.borrowLiquidHolderRef(address) {
                // not alive anymore
                self.participantsAlive[address] = false

                // emit event
                emit GameParticipantEliminated(
                    epochId: self.epochIndex,
                    participant: address,
                    phase: phase,
                    liquidity: liquidityHolder.getLiquidityValue(),
                    holders: liquidityHolder.getHolders(),
                    Trades: liquidityHolder.getTrades()
                )
            }
        }

        /// Get the liquidity holder reference
        ///
        access(self)
        fun borrowLiquidHolderRef(_ address: Address): &{LiquidityHolder}? {
            if let cap = self.participants[address] {
                return cap.borrow()
            }
            return nil
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
        view fun isCurrentGameActivated(): Bool {
            if let currentGame = self.borrowCurrentGame() {
                let currentPhase = currentGame.getCurrentPhase()
                return currentPhase.rawValue >= GamePhase.P1_Nto24.rawValue
                    && currentPhase.rawValue < GamePhase.Ended.rawValue
            }
            // If the game is not started, it is also considered as finished
            return false
        }

        /// Check if the current Game is finished
        access(all)
        view fun isCurrentGameFinished(): Bool {
            if let currentGame = self.borrowCurrentGame() {
                let currentPhase = currentGame.getCurrentPhase()
                return currentPhase.rawValue == GamePhase.Ended.rawValue
            }
            // If the game is not started, it is also considered as finished
            return true
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

        // ----- Implement IHeartbeatHook -----

        /// The methods that is invoked when the heartbeat is executed
        /// Before try-catch is deployed, please ensure that there will be no panic inside the method.
        ///
        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            // Step 0. Handle the current game
            self.ensureGameExisting()
        }

        // --- Internal Methods ---

        /// Start a new epoch
        ///
        access(self)
        fun ensureGameExisting() {
            if self.isCurrentGameActivated() {
                // DO NOTHING
                return
            }

            let currentGame = self.borrowBattleRoyaleRef(self.currentEpochIndex)
            let newEpochIndex = currentGame == nil ? self.currentEpochIndex : self.currentEpochIndex + 1

            // Create a new Game
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
        case GamePhase.P1_Nto24:
            return oneday * 3.0
        default:
            return oneday
        }
    }

    /// Get the number of players in a game phase
    ///
    access(all)
    view fun getGamePhaseWinners(_ phase: GamePhase): UInt64 {
        switch phase {
        case GamePhase.P0_Waiting:
            return UInt64.max
        case GamePhase.P1_Nto24:
            return 24
        case GamePhase.P2_24to16:
            return 16
        case GamePhase.P3_16to8:
            return 8
        case GamePhase.P4_8to4:
            return 4
        case GamePhase.P5_4toWinners:
            return 4
        default:
            return 0
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
        let publicPath = self.getGameCenterPublicPath()
        // @deprecated in Cadence 1.0
        self.account.link<&GameCenter{GameCenterPublic, FixesHeartbeat.IHeartbeatHook}>(
            publicPath,
            target: storagePath
        )

        //   - Add Heartbeat Hook

        // Register to FixesHeartbeat
        let heartbeatScope = "FGameRugRoyale"
        let contractAddr = self.account.address
        if !FixesHeartbeat.hasHook(scope: heartbeatScope, hookAddr: contractAddr) {
            FixesHeartbeat.addHook(
                scope: heartbeatScope,
                hookAddr: contractAddr,
                hookPath: publicPath
            )
        }

        emit ContractInitialized()
    }
}
