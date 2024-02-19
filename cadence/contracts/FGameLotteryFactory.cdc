/**
> Author: FIXeS World <https://fixes.world/>

# FGameLotteryFactory

This contract contains the factory for creating new Lottery Pool.

*/
import "FlowToken"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FRC20Indexer"
import "FGameLottery"
import "FGameLotteryRegistry"

access(all) contract FGameLotteryFactory {

    /* --- Public Methods - Controller --- */

    access(all) view
    fun getFIXESLotteryPoolName(): String {
        return "FIXES_BASIS_LOTTERY_POOL"
    }

    access(all) view
    fun getFIXESMintingLotteryPoolName(): String {
        return "FIXES_MINTING_LOTTERY_POOL"
    }

    /// Initialize the $FIXES Lottery Pool
    /// This pool is for directly paying $FIXES to purchase lottery tickets.
    ///
    access(all)
    fun initializeFIXESLotteryPool(
        _ controller: &FGameLotteryRegistry.RegistryController,
        newAccount: Capability<&AuthAccount>,
    ) {
        // initialize with 3 days
        let epochInterval: UFix64 = UFix64(3 * 24 * 60 * 60) // 3 days
        self._initializeLotteryPool(
            controller,
            name: self.getFIXESLotteryPoolName(),
            rewardTick: "fixes",
            ticketPrice: FixesInscriptionFactory.estimateLotteryFIXESTicketsCost(1, nil),
            epochInterval: epochInterval,
            newAccount: newAccount
        )
    }

    /// Initialize the $FIXES Minting Lottery Pool
    /// This pool pays 1 $FLOW each time, while minting $FIXES x 4. The excess FLOW is used to purchase lottery tickets.
    ///
    access(all)
    fun initializeFIXESMintingLotteryPool(
        _ controller: &FGameLotteryRegistry.RegistryController,
        newAccount: Capability<&AuthAccount>,
    ) {
        // initialize with 3 days
        let epochInterval: UFix64 = UFix64(3 * 24 * 60 * 60) // 3 days
        let rewardTick: String = "" // empty string means $FLOW
        let fixesMintingStr = FixesInscriptionFactory.buildMintFRC20(tick: "fixes", amt: 1000.0)
        let mintingCost = FixesInscriptionFactory.estimateFrc20InsribeCost(fixesMintingStr)
        assert(
            mintingCost < 0.25,
            message: "Minting cost is too high"
        )
        var ticketPrice: UFix64 = 1.0 - 4.0 * mintingCost // ticket price = 1.0 - 4 x $FIXES minting price

        self._initializeLotteryPool(
            controller,
            name: self.getFIXESMintingLotteryPoolName(),
            rewardTick: rewardTick,
            ticketPrice: ticketPrice,
            epochInterval: epochInterval,
            newAccount: newAccount
        )
    }

    /// Genereal initialize the Lottery Pool
    ///
    access(contract)
    fun _initializeLotteryPool(
        _ controller: &FGameLotteryRegistry.RegistryController,
        name: String,
        rewardTick: String,
        ticketPrice: UFix64,
        epochInterval: UFix64,
        newAccount: Capability<&AuthAccount>,
    ) {
        let registry = FGameLotteryRegistry.borrowRegistry()
        assert(
            registry.getLotteryPoolAddress(name) == nil,
            message: "Lottery pool name is not available"
        )
        // Create the Lottery Pool
        controller.createLotteryPool(
            name: name,
            rewardTick: rewardTick,
            ticketPrice: ticketPrice,
            epochInterval: epochInterval,
            newAccount: newAccount
        )
    }

    /* --- Public methods - User --- */

    /// Use $FLOW to buy FIXES Minting Lottery Tickets
    /// Return the inscriptions of FIXES minting
    ///
    access(all)
    fun buyFIXESMintingLottery(
        flowVault: @FlowToken.Vault,
        ticketAmount: UInt64,
        recipient: Capability<&FGameLottery.TicketCollection{FGameLottery.TicketCollectionPublic}>,
        inscriptionStore: &Fixes.InscriptionsStore,
    ) {
        // TODO
    }

    /// Use $FIXES to buy FIXES Lottery Tickets
    ///
    access(all)
    fun buyFIXESLottery(
        ticketAmount: UInt64,
        recipient: Capability<&FGameLottery.TicketCollection{FGameLottery.TicketCollectionPublic}>,
        inscriptionStore: &Fixes.InscriptionsStore,
    ) {
        // TODO
    }
}
