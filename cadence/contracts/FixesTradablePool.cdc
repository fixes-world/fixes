/**

> Author: FIXeS World <https://fixes.world/>

# FixesTradablePool

The FixesTradablePool contract is a bonding curve contract that allows users to buy and sell fungible tokens at a price that is determined by a bonding curve algorithm.
The bonding curve algorithm is a mathematical formula that determines the price of a token based on the token's supply.
The bonding curve contract is designed to be used with the FungibleToken contract, which is a standard fungible token
contract that allows users to create and manage fungible tokens.

*/
// Standard dependencies
import "FungibleToken"
import "FlowToken"
import "FungibleTokenMetadataViews"
// Third-party dependencies
import "BlackHole"
import "AddressUtils"
import "PublicPriceOracle"
import "SwapFactory"
import "SwapInterfaces"
import "SwapConfig"
// Fixes dependencies
import "Fixes"
import "FixesHeartbeat"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FixesBondingCurve"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20StakingManager"
import "FRC20Converter"

/// The bonding curve contract.
/// This contract allows users to buy and sell fungible tokens at a price that is determined by a bonding curve algorithm.
///
access(all) contract FixesTradablePool {

    // ------ Events -------

    // Event that is emitted when the subject fee percentage is changed.
    access(all) event LiquidityPoolSubjectFeePercentageChanged(subject: Address, subjectFeePercentage: UFix64)

    // Event that is emitted when the liquidity pool is created.
    access(all) event LiquidityPoolCreated(tokenType: Type, curveType: Type, tokenSymbol: String, subjectFeePerc: UFix64, freeAmount: UFix64, createdBy: Address)

    // Event that is emitted when the liquidity pool is initialized.
    access(all) event LiquidityPoolInitialized(subject: Address, tokenType: Type, mintedAmount: UFix64)

    /// Event that is emitted when the liquidity pool is activated.
    access(all) event LiquidityPoolInactivated(subject: Address, tokenType: Type)

    /// Event that is emitted when the liquidity is added.
    access(all) event LiquidityAdded(subject: Address, tokenType: Type, flowAmount: UFix64)

    /// Event that is emitted when the liquidity is removed.
    access(all) event LiquidityRemoved(subject: Address, tokenType: Type, flowAmount: UFix64)

    // Event that is emitted when the liquidity is transferred.
    access(all) event LiquidityTransferred(subject: Address, pairAddr: Address, tokenType: Type, tokenAmount: UFix64, flowAmount: UFix64)

    // Event that is emitted when a user buys or sells tokens.
    access(all) event Trade(trader: Address, isBuy: Bool, subject: Address, ticker: String, tokenAmount: UFix64, flowAmount: UFix64, protocolFee: UFix64, subjectFee: UFix64, supply: UFix64)

    /// -------- Resources and Interfaces --------

    // Utility struct for storing an address with a UFix64 score value.
    access(all) struct AddressWithScore {
        access(all) let address: Address
        access(all) let score: UFix64
        init(_ address: Address, _ score: UFix64) {
            self.address = address
            self.score = score
        }
    }

    /// Public resource interface for the Trading Center
    ///
    access(all) resource interface CeneterPublic {
        /// Get the total pool amount
        access(all)
        view fun totalPoolAmmount(): Int
        /// (Readonly)Query the latest pools
        access(all)
        view fun queryLatestPools(page: Int, size: Int): [AddressWithScore]
        /// Get the total handovered pool amount
        access(all)
        view fun totalHandoveredAmmount(): Int
        /// (Readonly)Query the latest handovered pools
        access(all)
        view fun queryLatestHandoveredPools(page: Int, size: Int): [AddressWithScore]
        /// Get the total trending pools
        access(all)
        view fun getTopTrendingPools(): [AddressWithScore]
        // --------- Contract Level Write Access ---------
        /// Invoked when a new pool is initialized
        access(contract)
        fun onPoolInitialized(_ poolAddr: Address)
        /// Invoked when a pool's liquidity is handovered
        access(contract)
        fun onPoolLPHandovered(_ poolAddr: Address)
        /// Invoked when a pool's Flow token is updated
        access(contract)
        fun onPoolFlowTokenUpdated(_ poolAddr: Address)
    }

    /// Trading Center Resource
    ///
    access(all) resource TradingCenter: CeneterPublic {
        // for new list, unlimited
        access(self) let pools: [Address]
        access(self) let poolsAddedAt: {Address: UFix64}
        // for finalized list, unlimited
        access(self) let handovered: [Address]
        access(self) let poolsHandoveredAt: {Address: UFix64}
        // for trending list, top 100 limited
        access(self) let trendingPools: [Address]
        access(self) let trendingScore: {Address: UFix64}

        init() {
            self.pools = []
            self.poolsAddedAt = {}
            self.handovered = []
            self.poolsHandoveredAt = {}
            self.trendingPools = []
            self.trendingScore = {}
        }

        // ----- Implement CeneterPublic -----
        /// Get the total pool amount
        access(all)
        view fun totalPoolAmmount(): Int {
            return self.pools.length
        }

        /// Query the latest pools
        access(all)
        view fun queryLatestPools(page: Int, size: Int): [AddressWithScore] {
            let start = page * size
            let len = self.pools.length
            var end = start + size
            if end > len {
                end = len
            }
            let addrs = self.pools.slice(from: start, upTo: end)
            let ret: [AddressWithScore] = []
            for addr in addrs {
                if let time = self.poolsAddedAt[addr] {
                    ret.append(AddressWithScore(addr, time))
                }
            }
            return ret
        }

        /// Get the total handovered pool amount
        access(all)
        view fun totalHandoveredAmmount(): Int {
            return self.handovered.length
        }

        /// Query the latest handovered pools
        access(all)
        view fun queryLatestHandoveredPools(page: Int, size: Int): [AddressWithScore] {
            let start = page * size
            let len = self.handovered.length
            var end = start + size
            if end > len {
                end = len
            }
            let addrs = self.handovered.slice(from: start, upTo: end)
            let ret: [AddressWithScore] = []
            for addr in addrs {
                if let time = self.poolsHandoveredAt[addr] {
                    ret.append(AddressWithScore(addr, time))
                }
            }
            return ret
        }

        /// Get the total trending pools
        access(all)
        view fun getTopTrendingPools(): [AddressWithScore] {
            let addrs = self.trendingPools
            let ret: [AddressWithScore] = []
            for addr in addrs {
                if let score = self.trendingScore[addr] {
                    ret.append(AddressWithScore(addr, score))
                }
            }
            return ret
        }

        // --------- Contract Level Write Access ---------

        /// Invoked when a new pool is initialized
        access(contract)
        fun onPoolInitialized(_ poolAddr: Address) {
            pre {
                FixesTradablePool.borrowTradablePool(poolAddr) != nil: "The pool is missing"
            }
            // check if the pool is already added
            if self.poolsAddedAt[poolAddr] != nil {
                return
            }
            // score is now
            let now = getCurrentBlock().timestamp
            self.pools.insert(at: 0, poolAddr)
            self.poolsAddedAt[poolAddr] = now
        }

        /// Invoked when a pool's liquidity is handovered
        access(contract)
        fun onPoolLPHandovered(_ poolAddr: Address) {
            pre {
                FixesTradablePool.borrowTradablePool(poolAddr) != nil: "The pool is missing"
            }
            // check if the pool is already added
            if self.poolsHandoveredAt[poolAddr] != nil {
                return
            }
            // score is now
            let now = getCurrentBlock().timestamp
            self.handovered.insert(at: 0, poolAddr)
            self.poolsHandoveredAt[poolAddr] = now
        }

        /// Invoked when a pool's Flow token is updated
        access(contract)
        fun onPoolFlowTokenUpdated(_ address: Address) {
            if let poolRef = FixesTradablePool.borrowTradablePool(address) {
                // remove the address from the top 100
                if let idx = self.trendingPools.firstIndex(of: address) {
                    self.trendingPools.remove(at: idx)
                }

                // now address is not in the top 100, we need to check balance and insert it
                let balance = poolRef.getFlowBalanceInPool()
                if balance > 0.0 {
                    self.trendingScore[address] = balance
                } else {
                    self.trendingScore.remove(key: address)
                }

                var highBalanceIdx = 0
                var lowBalanceIdx = self.trendingPools.length - 1
                // use binary search to find the position
                while lowBalanceIdx >= highBalanceIdx {
                    let mid = (lowBalanceIdx + highBalanceIdx) / 2
                    let midAddr = self.trendingPools[mid]
                    let midBalance = self.trendingScore[midAddr] ?? 0.0
                    // find the position
                    if balance > midBalance {
                        lowBalanceIdx = mid - 1
                    } else if balance < midBalance {
                        highBalanceIdx = mid + 1
                    } else {
                        break
                    }
                }
                // insert the address
                self.trendingPools.insert(at: highBalanceIdx, address)
                log("onPoolFlowTokenUpdated - ".concat(address.toString())
                    .concat(" balance: ").concat(balance.toString())
                    .concat(" rank: ").concat(highBalanceIdx.toString()))
                // remove the last one if the length is greater than 100
                if self.trendingPools.length > 100 {
                    self.trendingPools.removeLast()
                }
            }
        }
    }

    /// The refund agent resource.
    ///
    access(all) resource FRC20RefundAgent: FRC20Converter.FRC20TreasuryReceiver {
        /// The refund pool
        access(self)
        let flowPool: @FungibleToken.Vault

        init() {
            self.flowPool <- FlowToken.createEmptyVault()
        }

        // @deprecated in Cadence v1.0
        destroy() {
            destroy self.flowPool
        }

        // ----- Implement FRC20Converter.FRC20TreasuryReceiver -----

        access(all)
        fun depositFlowToken(_ token: @FungibleToken.Vault) {
            self.flowPool.deposit(from: <- token)
        }

        // ----- Internal Methods -----

        /// Extract the Flow token from the pool
        ///
        access(contract)
        fun extract(): @FungibleToken.Vault {
            return <- self.flowPool.withdraw(amount: self.flowPool.balance)
        }
    }

    /// The liquidity pool interface.
    ///
    access(all) resource interface LiquidityPoolInterface {
        access(contract)
        let curve: {FixesBondingCurve.CurveInterface}

        // ----- Basics -----

        /// Get the subject address
        access(all)
        view fun getPoolAddress(): Address {
            return self.owner?.address ?? panic("The owner is missing")
        }

        /// Check if the liquidity is handovered
        ///
        access(all)
        view fun isLiquidityHandovered(): Bool {
            return self.isInitialized() && !self.isLocalActive() && self.getSwapPairAddress() != nil
        }

        access(all)
        view fun getHandoveredAt(): UFix64? {
            if self.isLiquidityHandovered() {
                if let store = FRC20FTShared.borrowStoreRef(self.getPoolAddress()) {
                    return store.getByEnum(FRC20FTShared.ConfigType.TradablePoolHandoveredAt) as! UFix64?
                }
            }
            return nil
        }

        /// Check if the liquidity pool is initialized
        access(all)
        view fun isInitialized(): Bool

        /// Check if the liquidity pool is active
        access(all)
        view fun isLocalActive(): Bool

        /// Get the subject fee percentage
        access(all)
        view fun getSubjectFeePercentage(): UFix64

        // ----- Token in the liquidity pool -----

        /// Get the token type
        access(all)
        view fun getTokenType(): Type

        /// Get the swap pair address
        access(all)
        view fun getSwapPairAddress(): Address?

        /// Get the max supply of the token
        access(all)
        view fun getMaxSupply(): UFix64

        /// Get the circulating supply of the token
        access(all)
        view fun getTotalSupply(): UFix64

        /// Get the circulating supply in the tradable pool
        access(all)
        view fun getTradablePoolCirculatingSupply(): UFix64

        /// Get the balance of the token in liquidity pool
        access(all)
        view fun getTokenBalanceInPool(): UFix64

        /// Get the balance of the flow token in liquidity pool
        access(all)
        view fun getFlowBalanceInPool(): UFix64

        /// Get the token price
        access(all)
        view fun getTokenPriceInFlow(): UFix64

        /// Get the LP token price
        access(all)
        view fun getLPPriceInFlow(): UFix64

        /// Get the burned liquidity pair amount
        access(all)
        view fun getBurnedLP(): UFix64

        /// Get the liquidity market cap
        access(all)
        view fun getLiquidityMarketCap(): UFix64

        /// Get the liquidity pool value
        access(all)
        view fun getLiquidityValue(): UFix64

        /// Get the token market cap
        access(all)
        view fun getTotalTokenMarketCap(): UFix64

        /// Get token supply value
        access(all)
        view fun getTotalTokenValue(): UFix64

        /// Get the burned token amount
        ///
        access(all)
        view fun getBurnedTokenAmount(): UFix64

        /// Get the locked liquidity market cap
        ///
        access(all)
        view fun getBurnedLiquidityMarketCap(): UFix64 {
            return self.getBurnedLiquidityValue() * FixesTradablePool.getFlowPrice()
        }

        /// Get the burned liquidity value
        ///
        access(all)
        view fun getBurnedLiquidityValue(): UFix64 {
            if self.isLocalActive() {
                return 0.0
            } else {
                let burnedLP = self.getBurnedLP()
                let lpPrice = self.getLPPriceInFlow()
                return burnedLP * lpPrice
            }
        }

        /// Get the swap pair reserved info for the liquidity pool
        /// 0 - Token0 reserve
        /// 1 - Token1 reserve
        /// 2 - LP token supply
        ///
        access(all)
        view fun getSwapPairReservedInfo(): [UFix64; 3]?

        /// Get the estimated swap amount
        ///
        access(all)
        view fun getSwapEstimatedAmount(
            _ directionTokenToFlow: Bool,
            amount: UFix64,
        ): UFix64

        // ----- Trade (Writable) -----

        /// Buy the token with the given inscription
        /// - ins: The inscription to buy the token
        /// - amount: The amount of token to buy, if nil, use all the inscription value to buy the token
        access(all)
        fun buyTokens(
            _ ins: &Fixes.Inscription,
            _ amount: UFix64?,
            recipient: &{FungibleToken.Receiver},
        ) {
            pre {
                self.isInitialized(): "The liquidity pool is not initialized"
                self.isLocalActive(): "The liquidity pool is not active"
                ins.isExtractable(): "The inscription is not extractable"
                ins.owner?.address == recipient.owner?.address: "The inscription owner is not the recipient owner"
                // TODO: change method in Standard V2
                recipient.getSupportedVaultTypes()[self.getTokenType()] == true: "The recipient does not support the token type"
            }
            post {
                ins.isExtracted(): "The inscription is not extracted"
            }
        }

        /// Sell the token to the liquidity pool
        /// - tokenVault: The token vault to sell
        access(all)
        fun sellTokens(
            _ tokenVault: @FungibleToken.Vault,
            recipient: &{FungibleToken.Receiver},
        ) {
            pre {
                self.isInitialized(): "The liquidity pool is not initialized"
                self.isLocalActive(): "The liquidity pool is not active"
                tokenVault.isInstance(self.getTokenType()): "The token vault is not the same type as the liquidity pool"
                tokenVault.balance > 0.0: "The token vault balance must be greater than 0"
                // TODO: change method in Standard V2
                recipient.getSupportedVaultTypes()[Type<@FlowToken.Vault>()] == true: "The recipient does not support FlowToken.Vault"
            }
            post {
                before(self.getTradablePoolCirculatingSupply()) == self.getTradablePoolCirculatingSupply() + before(tokenVault.balance): "The circulating supply is not updated"
            }
        }

        /// Swap all tokens in the vault and deposit to the token out recipient
        access(all)
        fun quickSwapToken(
            _ tokenInVault: @FungibleToken.Vault,
            _ tokenOutRecipient: &{FungibleToken.Receiver},
        ) {
            pre {
                self.isInitialized(): "The liquidity pool is not initialized"
                !self.isLocalActive(): "The liquidity pool is active"
                tokenInVault.balance > 0.0: "The token vault balance must be greater than 0"
                tokenInVault.isInstance(self.getTokenType()) || tokenInVault.isInstance(Type<@FlowToken.Vault>()): "The token vault is not the same type as the liquidity pool"
            }
        }

        // ---- Bonding Curve ----

        /// Get the curve type
        access(all)
        view fun getCurveType(): Type {
            return self.curve.getType()
        }

        /// Get the free amount
        access(all)
        view fun getFreeAmount(): UFix64 {
            return self.curve.getFreeAmount()
        }

        /// Get the price of the token
        access(all)
        view fun getUnitPrice(): UFix64 {
            return self.curve.calculateUnitPrice(supply: self.getTradablePoolCirculatingSupply())
        }

        /// Calculate the price of buying the token based on the amount
        access(all)
        view fun getBuyPrice(_ amount: UFix64): UFix64 {
            return self.curve.calculatePrice(supply: self.getTradablePoolCirculatingSupply(), amount: amount)
        }

        /// Calculate the price of selling the token based on the amount
        access(all)
        view fun getSellPrice(_ amount: UFix64): UFix64 {
            return self.curve.calculatePrice(supply: self.getTradablePoolCirculatingSupply() - amount, amount: amount)
        }

        /// Calculate the price of buying the token after the subject fee
        access(all)
        view fun getBuyPriceAfterFee(_ amount: UFix64): UFix64 {
            let price = self.getBuyPrice(amount)
            let protocolFee = price * FixesTradablePool.getProtocolTradingFee()
            let subjectFee = price * self.getSubjectFeePercentage()
            return price + protocolFee + subjectFee
        }

        /// Calculate the price of selling the token after the subject fee
        access(all)
        view fun getSellPriceAfterFee(_ amount: UFix64): UFix64 {
            let price = self.getSellPrice(amount)
            let protocolFee = price * FixesTradablePool.getProtocolTradingFee()
            let subjectFee = price * self.getSubjectFeePercentage()
            return price - protocolFee - subjectFee
        }

        /// Calculate the amount of tokens that can be bought with the given cost
        access(all)
        view fun getBuyAmount(_ cost: UFix64): UFix64 {
            return self.curve.calculateAmount(supply: self.getTradablePoolCirculatingSupply(), cost: cost)
        }

        /// Calculate the amount of tokens that can be bought with the given cost after the subject fee
        ///
        access(all)
        view fun getBuyAmountAfterFee(_ cost: UFix64): UFix64 {
            let protocolFee = cost * FixesTradablePool.getProtocolTradingFee()
            let subjectFee = cost * self.getSubjectFeePercentage()
            return self.getBuyAmount(cost - protocolFee - subjectFee)
        }
    }

    /// The liquidity pool resource.
    ///
    access(all) resource TradableLiquidityPool: LiquidityPoolInterface, FixesFungibleTokenInterface.LiquidityHolder, FixesFungibleTokenInterface.IMinterHolder, FixesHeartbeat.IHeartbeatHook, FungibleToken.Receiver {
        /// The bonding curve of the liquidity pool
        access(contract)
        let curve: {FixesBondingCurve.CurveInterface}
        // The minter of the token
        access(self)
        let minter: @{FixesFungibleTokenInterface.IMinter}
        // The frc20 refund agent
        access(self)
        let refundAgent: @FRC20RefundAgent
        // The vault for the token
        access(self)
        let vault: @FungibleToken.Vault
        // The vault for the flow token in the liquidity pool
        access(self)
        let flowVault: @FlowToken.Vault
        /// The subject fee percentage
        access(self)
        var subjectFeePercentage: UFix64
        /// If the liquidity pool is active
        access(self)
        var acitve: Bool
        /// The record of LP token burned
        access(self)
        var lpBurned: UFix64
        /// The trade amount
        access(self)
        var tradedCount: UInt64

        init(
            _ minter: @{FixesFungibleTokenInterface.IMinter},
            _ curve: {FixesBondingCurve.CurveInterface},
            _ subjectFeePerc: UFix64?
        ) {
            pre {
                minter.getTotalAllowedMintableAmount() > 0.0: "The mint amount must be greater than 0"
                subjectFeePerc == nil || subjectFeePerc! < 0.01: "Invalid Subject Fee"
            }
            self.minter <- minter
            self.refundAgent <- create FRC20RefundAgent()
            self.curve = curve
            self.subjectFeePercentage = subjectFeePerc ?? 0.0

            let vaultData = self.minter.getVaultData()
            self.vault <- vaultData.createEmptyVault()
            self.flowVault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.acitve = false
            self.lpBurned = 0.0
            self.tradedCount = 0
        }

        // @deprecated in Cadence v1.0
        destroy() {
            destroy self.minter
            destroy self.refundAgent
            destroy self.vault
            destroy self.flowVault
        }

        // ----- Implement LiquidityPoolAdmin -----

        /// Initialize the liquidity pool
        /// TODO: Change to entitlement in Cadence 1.0
        ///
        access(all)
        fun initialize() {
            pre {
                self.acitve == false: "Tradable Pool is active"
                self.vault.balance == 0.0: "Token vault should be zero"
                self.minter.getCurrentMintableAmount() > 0.0: "The mint amount must be greater than 0"
            }
            post {
                self.minter.getCurrentMintableAmount() == 0.0: "The mint amount must be zero"
            }

            let minter = self.borrowMinter()
            let totalMintAmount = minter.getCurrentMintableAmount()
            let newVault <- minter.mintTokens(amount: totalMintAmount)
            // This is a un-initialized newVault, so it contains a FixesAssetMeta.ExclusiveMeta meta data
            // After depositing the newVault to the vault, the vault will be initialized first.
            // But the un-removed FixesAssetMeta.ExclusiveMeta in the newVault will keep existing.
            // So, the vault is valid but still contains the FixesAssetMeta.ExclusiveMeta.
            self.vault.deposit(from: <- newVault)
            self.acitve = true

            // Update in the trading center
            let tradingCenter = FixesTradablePool.borrowTradingCenter()
            tradingCenter.onPoolInitialized(self.getPoolAddress())

            // Emit the event
            emit LiquidityPoolInitialized(
                subject: self.getPoolAddress(),
                tokenType: self.getTokenType(),
                mintedAmount: totalMintAmount
            )
        }

        /// The admin can set the subject fee percentage
        /// The subject fee percentage must be greater than or equal to 0 and less than or equal to 0.01
        /// TODO: Change to entitlement in Cadence 1.0
        ///
        access(all)
        fun setSubjectFeePercentage(_ subjectFeePerc: UFix64) {
            pre {
                subjectFeePerc >= 0.0: "The subject fee percentage must be greater than or equal to 0"
                subjectFeePerc <= 0.01: "The subject fee percentage must be less than or equal to 0.01"
            }
            self.subjectFeePercentage = subjectFeePerc

            // Emit the event
            emit LiquidityPoolSubjectFeePercentageChanged(
                subject: self.getPoolAddress(),
                subjectFeePercentage: subjectFeePerc
            )
        }

        // ------ Implement LiquidityPoolInterface -----

        /// Check if the liquidity pool is initialized
        access(all)
        view fun isInitialized(): Bool {
            return self.minter.getCurrentMintableAmount() == 0.0
        }

        /// Check if the liquidity pool is active
        access(all)
        view fun isLocalActive(): Bool {
            return self.acitve
        }

        /// Get the subject fee percentage
        access(all)
        view fun getSubjectFeePercentage(): UFix64 {
            return self.subjectFeePercentage
        }

        /// Get the token type
        access(all)
        view fun getTokenType(): Type {
            return self.vault.getType()
        }

        /// Get the max supply of the token
        access(all)
        view fun getMaxSupply(): UFix64 {
            let minter = self.borrowMinter()
            return minter.getMaxSupply()
        }

        /// Get the total supply of the token
        access(all)
        view fun getTotalSupply(): UFix64 {
            let minter = self.borrowMinter()
            // The circulating supply is the total supply minus the balance in the vault
            return minter.getTotalSupply()
        }

        /// Get the circulating supply in the tradable pool
        access(all)
        view fun getTradablePoolCirculatingSupply(): UFix64 {
            let minter = self.borrowMinter()
            // The circulating supply is the total supply minus the balance in the vault
            return minter.getTotalAllowedMintableAmount() - self.getTokenBalanceInPool()
        }

        /// Get the balance of the token in liquidity pool
        access(all)
        view fun getTokenBalanceInPool(): UFix64 {
            return self.vault.balance
        }

        /// Get the balance of the flow token in liquidity pool
        access(all)
        view fun getFlowBalanceInPool(): UFix64 {
            return self.flowVault.balance
        }

        /// Get the burned liquidity pair amount
        access(all)
        view fun getBurnedLP(): UFix64 {
            return self.lpBurned
        }

        /// Get the token price
        ///
        access(all)
        view fun getTokenPriceInFlow(): UFix64 {
            if self.isLocalActive() {
                return self.getUnitPrice()
            }
            return self.getSwapEstimatedAmount(true, amount: 1.0)
        }

        /// Get the estimated swap amount
        ///
        access(all)
        view fun getSwapEstimatedAmount(
            _ directionTokenToFlow: Bool,
            amount: UFix64,
        ): UFix64 {
            let pairInfo = self.getSwapPairReservedInfo()
            if pairInfo == nil {
                return 0.0
            }
            let reserveToken = pairInfo![0]
            let reserveFlow = pairInfo![1]
            if directionTokenToFlow {
                return SwapConfig.getAmountOut(amountIn: amount, reserveIn: reserveToken, reserveOut: reserveFlow)
            } else {
                return SwapConfig.getAmountOut(amountIn: amount, reserveIn: reserveFlow, reserveOut: reserveToken)
            }
        }

        /// Get the LP token price
        ///
        access(all)
        view fun getLPPriceInFlow(): UFix64 {
            if self.isLocalActive() {
                return 0.0
            }

            let pairInfo = self.getSwapPairReservedInfo()
            if pairInfo == nil {
                return 0.0
            }
            let reserve0 = pairInfo![0]
            let reserve1 = pairInfo![1]
            let lpTokenSupply = pairInfo![2]

            // amount1 is the price
            let amount1 = SwapConfig.quote(amountA: 1.0, reserveA: reserve0, reserveB: reserve1)
            let totalValueInFlow = amount1 * reserve0 + 1.0 * reserve1
            return lpTokenSupply == 0.0 ? 0.0 : totalValueInFlow / lpTokenSupply
        }

        /// Get the burned token amount
        ///
        access(all)
        view fun getBurnedTokenAmount(): UFix64 {
            if self.isLocalActive() {
                return 0.0
            }

            let burnedLP = self.getBurnedLP()
            if burnedLP == 0.0 {
                return 0.0
            }
            let pairInfo = self.getSwapPairReservedInfo()
            if pairInfo == nil {
                return 0.0
            }

            let reserve0 = pairInfo![0]
            let reserve1 = pairInfo![1]
            let lpTokenSupply = pairInfo![2]

            let scaledBurnedLP = SwapConfig.UFix64ToScaledUInt256(burnedLP)
            let scaledlpTokenSupply = SwapConfig.UFix64ToScaledUInt256(lpTokenSupply)
            let scaledReserve0 = SwapConfig.UFix64ToScaledUInt256(reserve0)
            let scaledBurnedToken0 = scaledReserve0 * scaledBurnedLP / scaledlpTokenSupply
            return SwapConfig.ScaledUInt256ToUFix64(scaledBurnedToken0)
        }

        /// Get the swap pair reserved info for the liquidity pool
        /// 0 - Token0 reserve
        /// 1 - Token1 reserve
        /// 2 - LP token supply
        ///
        access(all)
        view fun getSwapPairReservedInfo(): [UFix64; 3]? {
            let pairRef = self.borrowSwapPairRef()
            if pairRef == nil {
                return nil
            }
            let pairInfo = pairRef!.getPairInfo()
            let tokenKey = SwapConfig.SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: self.vault.getType().identifier)

            var reserve0 = 0.0
            var reserve1 = 0.0
            if tokenKey == (pairInfo[0] as! String) {
                reserve0 = (pairInfo[2] as! UFix64)
                reserve1 = (pairInfo[3] as! UFix64)
            } else {
                reserve0 = (pairInfo[3] as! UFix64)
                reserve1 = (pairInfo[2] as! UFix64)
            }
            let lpTokenSupply = pairInfo[5] as! UFix64
            return [reserve0, reserve1, lpTokenSupply]
        }

        /// Get the swap pair address
        ///
        access(all)
        view fun getSwapPairAddress(): Address? {
            let token0Key = SwapConfig.SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: self.vault.getType().identifier)
            let token1Key = SwapConfig.SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: self.flowVault.getType().identifier)
            return SwapFactory.getPairAddress(token0Key: token0Key, token1Key: token1Key)
        }

        /// Borrow the swap pair reference
        ///
        access(all)
        view fun borrowSwapPairRef(): &{SwapInterfaces.PairPublic}? {
            if let pairAddr = self.getSwapPairAddress() {
                // ensure the pair's contract exists
                // Note: because the pair is created by the factory, in the first transactions. the contract can not be borrowed.
                // So, We need to ensure the pair contract exists.
                // But that will be improved in the future.
                let acct = getAccount(pairAddr)
                let allNames = acct.contracts.names
                if !allNames.contains("SwapPair") {
                    return nil
                }
                // Now we can borrow the reference
                return acct
                    .getCapability<&{SwapInterfaces.PairPublic}>(SwapConfig.PairPublicPath)
                    .borrow()
            }
            return nil
        }

        /// Borrow the token global public reference
        ///
        access(all)
        view fun borrowTokenGlobalPublic(): &{FixesFungibleTokenInterface.IGlobalPublic} {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let key = self.minter.getAccountsPoolKey() ?? panic("The accounts pool key is missing")
            let contractRef = acctsPool.borrowFTContract(key) ?? panic("The FT contract reference is missing")
            return contractRef.borrowGlobalPublic()
        }

        // ----- Implement LiquidityHolder -----

        /// Get the token symbol
        access(all)
        view fun getTokenSymbol(): String {
            return self.minter.getSymbol()
        }

        /// Get the key in the accounts pool
        access(all)
        view fun getAccountsPoolKey(): String? {
            return self.minter.getAccountsPoolKey()
        }

        /// Check if the address is authorized user for the liquidity holder
        ///
        access(all)
        view fun isAuthorizedUser(_ callerAddr: Address): Bool {
            // singleton resources
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            // The caller should be authorized user for the token
            let key = self.minter.getAccountsPoolKey() ?? panic("The accounts pool key is missing")
            // borrow the contract
            let contractRef = acctsPool.borrowFTContract(key) ?? panic("The contract is missing")
            let globalPublicRef = contractRef.borrowGlobalPublic()
            return globalPublicRef.isAuthorizedUser(callerAddr)
        }

        /// Get the liquidity market cap
        access(all)
        view fun getLiquidityMarketCap(): UFix64 {
            return self.getLiquidityValue() * FixesTradablePool.getFlowPrice()
        }

        /// Get the liquidity pool value
        access(all)
        view fun getLiquidityValue(): UFix64 {
            if self.isLocalActive() {
                let flowAmount = self.getFlowBalanceInPool()
                // The market cap is the flow amount * flow price * 2.0
                // According to the Token value is equal to the Flow token value.
                return flowAmount * 2.0
            } else {
                // current no liquidity in the pool, all LP token is burned
                return 0.0
            }
        }

        /// Get the token market cap
        ///
        access(all)
        view fun getTotalTokenMarketCap(): UFix64 {
            return self.getTotalTokenValue() * FixesTradablePool.getFlowPrice()
        }

        /// Get token supply value
        ///
        access(all)
        view fun getTotalTokenValue(): UFix64 {
            let reservedSupply = self.getTokenBalanceInPool()
            let circulatingSupply = self.getTotalSupply() - reservedSupply
            let tokenPrice = self.getTokenPriceInFlow()
            return circulatingSupply * tokenPrice
        }

        /// Get the token holders
        access(all)
        view fun getHolders(): UInt64 {
            let globalInfo = self.borrowTokenGlobalPublic()
            return globalInfo.getHoldersAmount()
        }

        /// Get the trade count
        access(all)
        view fun getTrades(): UInt64 {
            return self.tradedCount
        }

        /// Pull liquidity from the pool
        access(account)
        fun pullLiquidity(): @FungibleToken.Vault {
            if self.flowVault.balance < 1.0 {
                return <- FlowToken.createEmptyVault()
            }

            // only leave 1.0 $FLOW to setup the liquidity pair
            let liquidityAmount = self.flowVault.balance - 1.0
            let liquidityVault <- self._withdrawFlowToken(liquidityAmount)

            // All Liquidity is pulled, so the pool should be set to be inactive
            self.transferLiquidity()

            return <- liquidityVault
        }

        /// Push liquidity to the pool
        ///
        access(account)
        fun addLiquidity(_ vault: @FungibleToken.Vault) {
            self._depositFlowToken(<- vault)

            // if not active, then try to add liquidity
            let swapThreshold = 10.0
            if self.isLiquidityHandovered() && self.flowVault.balance >= swapThreshold {
                self._transferLiquidity()
            }
        }

        /// Transfer liquidity to swap pair
        ///
        access(account)
        fun transferLiquidity(): Bool {
            // check if flow vault has enough liquidity, if not then do nothing
            if self.flowVault.balance < 0.02 {
                // DO NOT PANIC
                return false
            }

            // Ensure the swap pair is created
            self._ensureSwapPair()
            // Transfer the liquidity to the swap pair
            return self._transferLiquidity()
        }

        // ----- Implement FungibleToken.Receiver -----

        /// Returns whether or not the given type is accepted by the Receiver
        /// A vault that can accept any type should just return true by default
        access(all)
        view fun isSupportedVaultType(type: Type): Bool {
            return type == Type<@FlowToken.Vault>()
        }

        /// A getter function that returns the token types supported by this resource,
        /// which can be deposited using the 'deposit' function.
        ///
        /// @return Array of FT types that can be deposited.
        access(all)
        view fun getSupportedVaultTypes(): {Type: Bool} {
            let supportedVaults: {Type: Bool} = {}
            supportedVaults[Type<@FlowToken.Vault>()] = true
            return supportedVaults
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and forwards
        // it to the recipient's Vault using the stored reference
        //
        access(all)
        fun deposit(from: @FungibleToken.Vault) {
            self.addLiquidity(<- from)
        }

        // ----- Trade (Writable) -----

        /// Buy the token with the given inscription
        ///
        access(all)
        fun buyTokens(
            _ ins: &Fixes.Inscription,
            _ amount: UFix64?,
            recipient: &{FungibleToken.Receiver},
        ) {
            let flowPaymentVault <- FlowToken.createEmptyVault()
            let flowAvailableAmount = ins.getInscriptionValue() - ins.getMinCost()
            // deposit the available Flow tokens in the inscription to the flow vault
            if flowAvailableAmount > 0.0 {
                flowPaymentVault.deposit(from: <- ins.partialExtract(flowAvailableAmount))
            }

            // check inscription command
            let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            let op = meta["op"] ?? panic("The inscription operation is missing")
            assert(
                op == "exec" || op == "burn",
                message: "Only the 'exec' or 'burn' operation is allowed"
            )
            // if the operation is burn, then burn the frc20 token and get the flow token refunded
            if op == "burn" {
                // borrow the system burner
                let systemBurner = FRC20Converter.borrowSystemBurner()
                let refundAgent = self.borrowRefundAgent()
                // this method will execute the inscription command and refund the Flow tokens
                systemBurner.burnAndSend(ins, recipient: refundAgent)
                // extract the refunded $FLOW and deposit to the payment flow vault
                flowPaymentVault.deposit(from: <- refundAgent.extract())
            }

            // borrow the minter
            let minter = self.borrowMinter()

            // calculate the price
            var price: UFix64 = 0.0
            var protocolFee: UFix64 = 0.0
            var subjectFee: UFix64 = 0.0
            var buyAmount: UFix64 = 0.0
            if amount != nil && amount! > 0.0 {
                buyAmount = amount!
                price = self.getBuyPrice(buyAmount)
                protocolFee = price * FixesTradablePool.getProtocolTradingFee()
                subjectFee = price * self.getSubjectFeePercentage()
            } else {
                protocolFee = flowPaymentVault.balance * FixesTradablePool.getProtocolTradingFee()
                subjectFee = flowPaymentVault.balance * self.getSubjectFeePercentage()
                price = flowPaymentVault.balance - protocolFee - subjectFee
                buyAmount = self.getBuyAmount(price)
            }

            // check the total cost
            let totalCost = price + protocolFee + subjectFee

            log("Trader: ".concat(ins.owner!.address.toString())
                .concat(" Inscription Value: ").concat(ins.getInscriptionValue().toString())
                .concat(" Partial Extract: ").concat(flowAvailableAmount.toString())
                .concat(" Flow Payment Vault: ").concat(flowPaymentVault.balance.toString())
                .concat(" Price: ").concat(price.toString())
                .concat(" Buy Amount: ").concat(buyAmount.toString())
                .concat(" Protocol Fee: ").concat(protocolFee.toString())
                .concat(" Subject Fee: ").concat(subjectFee.toString())
                .concat(" Total Cost: ").concat(totalCost.toString())
            )

            assert(
                totalCost <= flowPaymentVault.balance,
                message: "Insufficient payment: The total cost is greater than the available Flow tokens"
            )
            let payment <- flowPaymentVault.withdraw(amount: totalCost)
            if protocolFee > 0.0 {
                let protocolFeeVault <- payment.withdraw(amount: protocolFee)
                let protocolFeeReceiverRef = Fixes.borrowFlowTokenReceiver(Fixes.getPlatformAddress())
                    ?? panic("The protocol fee destination does not have a FlowTokenReceiver capability")
                protocolFeeReceiverRef.deposit(from: <- protocolFeeVault)
            }
            if subjectFee > 0.0 {
                let subjectFeeVault <- payment.withdraw(amount: subjectFee)
                let subjectFeeReceiverRef = Fixes.borrowFlowTokenReceiver(self.getPoolAddress())
                    ?? panic("The subject does not have a FlowTokenReceiver capability")
                subjectFeeReceiverRef.deposit(from: <- subjectFeeVault)
            }
            // deposit the payment to the flow vault in the liquidity pool
            self._depositFlowToken(<- payment)

            let callerAddr = ins.owner?.address ?? panic("The inscription owner is missing")
            // return remaining Flow tokens to the inscription owner
            if flowPaymentVault.balance > 0.0 {
                let ownerFlowVaultRef = Fixes.borrowFlowTokenReceiver(callerAddr)
                    ?? panic("The inscription owner does not have a FlowTokenReceiver capability")
                ownerFlowVaultRef.deposit(from: <- flowPaymentVault)
            } else {
                destroy flowPaymentVault
            }

            // check the BuyAmount
            assert(
                buyAmount > 0.0,
                message: "The buy amount must be greater than 0"
            )
            // Check if the vault has enough tokens
            assert(
                self.vault.balance >= buyAmount,
                message: "Insufficient token balance: The vault does not have enough tokens"
            )
            // initialize the vault by the inscription (the extracted inscription is also valid)
            let vaultData = minter.getVaultData()
            let initializedVault <- minter.initializeVaultByInscription(
                vault: <- vaultData.createEmptyVault(),
                ins: ins
            )
            // deposit the tokens to the initialized return vault
            initializedVault.deposit(from: <- self.vault.withdraw(amount: buyAmount))

            // deposit the tokens to the recipient
            recipient.deposit(from: <- initializedVault)

            // the variables for the trade event
            let poolAddr = self.getPoolAddress()
            let traderAddr = recipient.owner?.address ?? callerAddr

            // invoke the transaction hook
            self._onTransactionDeal(
                seller: poolAddr,
                buyer: traderAddr,
                dealAmount: buyAmount,
                dealPrice: totalCost
            )

            // emit the trade event
            emit Trade(
                trader: traderAddr,
                isBuy: true,
                subject: self.getPoolAddress(),
                ticker: minter.getSymbol(),
                tokenAmount: buyAmount,
                flowAmount: totalCost,
                protocolFee: protocolFee,
                subjectFee: subjectFee,
                supply: self.getTradablePoolCirculatingSupply()
            )
        }

        /// Sell the token to the liquidity pool
        ///
        access(all)
        fun sellTokens(
            _ tokenVault: @FungibleToken.Vault,
            recipient: &{FungibleToken.Receiver},
        ) {
            let minter = self.borrowMinter()
            // calculate the price
            let totalPrice = self.getSellPrice(tokenVault.balance)
            assert(
                totalPrice > 0.0,
                message: "The total payment must be greater than 0"
            )
            assert(
                self.flowVault.balance >= totalPrice,
                message: "Insufficient payment: The flow vault does not have enough tokens"
            )

            // withdraw the tokens from the vault
            let payment <- self._withdrawFlowToken(totalPrice)

            let protocolFee = totalPrice * FixesTradablePool.getProtocolTradingFee()
            let subjectFee = totalPrice * self.getSubjectFeePercentage()
            // withdraw the protocol fee from the flow vault
            if protocolFee > 0.0 {
                let protocolFeeVault <- payment.withdraw(amount: protocolFee)
                let protocolFeeReceiverRef = Fixes.borrowFlowTokenReceiver(Fixes.getPlatformAddress())
                    ?? panic("The protocol fee destination does not have a FlowTokenReceiver capability")
                protocolFeeReceiverRef.deposit(from: <- protocolFeeVault)
            }
            // withdraw the subject fee from the flow vault
            if subjectFee > 0.0 {
                let subjectFeeVault <- payment.withdraw(amount: subjectFee)
                let subjectFeeReceiverRef = Fixes.borrowFlowTokenReceiver(self.getPoolAddress())
                    ?? panic("The subject does not have a FlowTokenReceiver capability")
                subjectFeeReceiverRef.deposit(from: <- subjectFeeVault)
            }
            // withdraw the user fund from the flow vault
            recipient.deposit(from: <- payment)

            // deposit the tokens to the token vault
            let tokenAmount = tokenVault.balance
            self.vault.deposit(from: <- tokenVault)

            // emit the trade event
            let poolAddr = self.getPoolAddress()
            let traderAddr = recipient.owner?.address ?? panic("The recipient owner is missing")

            // invoke the transaction hook
            self._onTransactionDeal(
                seller: traderAddr,
                buyer: poolAddr,
                dealAmount: tokenAmount,
                dealPrice: totalPrice
            )

            emit Trade(
                trader: traderAddr,
                isBuy: false,
                subject: self.getPoolAddress(),
                ticker: minter.getSymbol(),
                tokenAmount: tokenAmount,
                flowAmount: totalPrice,
                protocolFee: protocolFee,
                subjectFee: subjectFee,
                supply: self.getTradablePoolCirculatingSupply()
            )
        }

        /// Swap all tokens in the vault and deposit to the token out recipient
        /// Only invokable when the local pool is not active
        ///
        access(all)
        fun quickSwapToken(
            _ tokenInVault: @FungibleToken.Vault,
            _ tokenOutRecipient: &{FungibleToken.Receiver},
        ) {
            let supportTypes = tokenOutRecipient.getSupportedVaultTypes()
            let minterTokenType = self.getTokenType()
            let tokenInVaultType = tokenInVault.getType()
            let isTokenInFlowToken = tokenInVaultType == Type<@FlowToken.Vault>()
            // check if the recipient supports the token type
            if isTokenInFlowToken {
                assert(
                    supportTypes[minterTokenType] == true,
                    message: "The recipient does not support FungibleToken.Vault"
                )
            } else {
                assert(
                    supportTypes[Type<@FlowToken.Vault>()] == true,
                    message: "The recipient does not support FlowToken.Vault"
                )
            }

            let pairPublicRef = self.borrowSwapPairRef() ?? panic("The swap pair is missing")
            let tokenInAmount = tokenInVault.balance
            let tokenOutVault <- pairPublicRef.swap(
                vaultIn: <- tokenInVault,
                exactAmountOut: nil
            )
            let tokenOutAmount = tokenOutVault.balance

            // parameters for the event
            let symbol = self.minter.getSymbol()
            let pairAddr = pairPublicRef.owner?.address ?? panic("The pair owner is missing")
            let traderAddr = tokenOutRecipient.owner?.address ?? panic("The recipient owner is missing")
            let tradeTokenAmount = isTokenInFlowToken ? tokenOutAmount : tokenInAmount
            let tradeTokenPrice = isTokenInFlowToken ? tokenInAmount : tokenOutAmount

            tokenOutRecipient.deposit(from: <- tokenOutVault)

            // emit the trade event
            self._onTransactionDeal(
                seller: isTokenInFlowToken ? pairAddr : traderAddr,
                buyer: isTokenInFlowToken ? traderAddr : pairAddr,
                dealAmount: tradeTokenAmount,
                dealPrice: tradeTokenPrice
            )

            emit Trade(
                trader: traderAddr,
                isBuy: isTokenInFlowToken,
                subject: self.getPoolAddress(),
                ticker: symbol,
                tokenAmount:tradeTokenAmount,
                flowAmount: tradeTokenPrice,
                protocolFee: 0.0,
                subjectFee: 0.0,
                supply: self.getTradablePoolCirculatingSupply()
            )
        }

        // ----- Internal Methods -----

        /// The hook that is invoked when a deal is executed
        ///
        access(self)
        fun _onTransactionDeal(
            seller: Address,
            buyer: Address,
            dealAmount: UFix64,
            dealPrice: UFix64,
        ) {
            // update the traded count
            self.tradedCount = self.tradedCount + 1

            let minter = self.borrowMinter()
            // for fixes fungible token, the ticker is $ + {symbol}
            let tickerName = "$".concat(minter.getSymbol())

            // ------- start -- Invoke Hooks --------------
            // Invoke transaction hooks to do things like:
            // -- Record the transction record
            // -- Record trading Volume

            // for TradablePool hook
            let poolAddr = self.getPoolAddress()
            // Buyer or Seller should be the pool address
            let isInPoolTrading = buyer == poolAddr || seller == poolAddr
            let storefront = isInPoolTrading ? poolAddr : (self.getSwapPairAddress() ?? poolAddr)

            // invoke the buyer transaction hook
            if let buyerTransactionHook = FRC20FTShared.borrowTransactionHook(buyer) {
                buyerTransactionHook.onDeal(
                    seller: seller,
                    buyer: buyer,
                    tick: tickerName,
                    dealAmount: dealAmount,
                    dealPrice: dealPrice,
                    storefront: storefront,
                    listingId: nil,
                )
            }

            // invoke the seller transaction hook
            if let sellerTransactionHook = FRC20FTShared.borrowTransactionHook(seller) {
                sellerTransactionHook.onDeal(
                    seller: seller,
                    buyer: buyer,
                    tick: tickerName,
                    dealAmount: dealAmount,
                    dealPrice: dealPrice,
                    storefront: storefront,
                    listingId: nil,
                )
            }

            // invoke the pool transaction hook for non-pool trading
            if !isInPoolTrading {
                if let poolTransactionHook = FRC20FTShared.borrowTransactionHook(poolAddr) {
                    poolTransactionHook.onDeal(
                        seller: seller,
                        buyer: buyer,
                        tick: tickerName,
                        dealAmount: dealAmount,
                        dealPrice: dealPrice,
                        storefront: storefront,
                        listingId: nil,
                    )
                }
            }

            // invoke the system transaction hook
            if let systemTransactionHook = FRC20FTShared.borrowTransactionHook(Fixes.getPlatformAddress()) {
                systemTransactionHook.onDeal(
                    seller: seller,
                    buyer: buyer,
                    tick: tickerName,
                    dealAmount: dealAmount,
                    dealPrice: dealPrice,
                    storefront: storefront,
                    listingId: nil,
                )
            }
        }

        /// Borrow the refund agent
        ///
        access(self)
        view fun borrowRefundAgent(): &FRC20RefundAgent {
            return &self.refundAgent as &FRC20RefundAgent
        }

        // ----- Implement IMinterHolder -----

        access(contract)
        view fun borrowMinter(): &{FixesFungibleTokenInterface.IMinter} {
            return &self.minter as &{FixesFungibleTokenInterface.IMinter}
        }

        // ----- Implement IHeartbeatHook -----

        /// The methods that is invoked when the heartbeat is executed
        /// Before try-catch is deployed, please ensure that there will be no panic inside the method.
        ///
        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            // if active, then move the liquidity pool to the next stage
            if self.isLocalActive() {
                // Check the market cap
                let totalMarketCap = self.getTotalTokenMarketCap()
                let targetMarketCap = FixesTradablePool.getTargetMarketCap()

                // if the market cap is less than the target market cap, then do nothing
                if totalMarketCap < targetMarketCap {
                    // DO NOT PANIC
                    return
                }
            }

            // if the liquidity is handovered but the flow vault is empty, then do nothing
            if self.isLiquidityHandovered() && self.flowVault.balance < 1.0 {
                // DO NOT PANIC
                return
            }

            // Transfer the liquidity to the swap pair
            self.transferLiquidity()
        }

        // ----- Internal Methods -----

        /// Withdraw the flow token from the pool
        ///
        access(self)
        fun _withdrawFlowToken(_ amount: UFix64): @FungibleToken.Vault {
            pre {
                amount > 0.0: "The amount must be greater than 0"
            }
            post {
                result.balance == amount: "The returned vault balance must be equal to the amount"
                self.flowVault.balance == before(self.flowVault.balance) - amount: "The flow vault balance must be decreased"
            }
            let vault <- self.flowVault.withdraw(amount: amount)

            // Update in the trading center
            let tradingCenter = FixesTradablePool.borrowTradingCenter()
            tradingCenter.onPoolFlowTokenUpdated(self.getPoolAddress())

            // Emit the event
            emit LiquidityRemoved(
                subject: self.getPoolAddress(),
                tokenType: self.getTokenType(),
                flowAmount: amount
            )

            return <- vault
        }

        /// Deposit the flow token to the pool
        ///
        access(self)
        fun _depositFlowToken(_ vault: @FungibleToken.Vault) {
            post {
                self.flowVault.balance == before(self.flowVault.balance) + before(vault.balance): "The flow vault balance must be increased"
            }
            let amount = vault.balance
            if amount > 0.0 {
                self.flowVault.deposit(from: <- vault)
            } else {
                destroy vault
                return
            }

            // Update in the trading center
            let tradingCenter = FixesTradablePool.borrowTradingCenter()
            tradingCenter.onPoolFlowTokenUpdated(self.getPoolAddress())

            // Emit the event
            emit LiquidityAdded(
                subject: self.getPoolAddress(),
                tokenType: self.getTokenType(),
                flowAmount: amount
            )
        }

        /// Ensure the swap pair is created
        ///
        access(self)
        fun _ensureSwapPair() {
            var pairAddr = self.getSwapPairAddress()
            // if the pair is not created, then create the pair
            if pairAddr == nil && self.flowVault.balance >= 0.01 {
                // Now we can add liquidity to the swap pair
                let minterRef = self.borrowMinter()
                let vaultData = minterRef.getVaultData()

                // create the account creation fee vault
                let acctCreateFeeVault <- self._withdrawFlowToken(0.01)
                // create the pair
                SwapFactory.createPair(
                    token0Vault: <- vaultData.createEmptyVault(),
                    token1Vault: <- FlowToken.createEmptyVault(),
                    accountCreationFee: <- acctCreateFeeVault,
                    stableMode: false
                )
            }
        }

        /// Create a new pair and add liquidity
        ///
        access(self)
        fun _transferLiquidity(): Bool {
            // Now we can add liquidity to the swap pair
            let minterRef = self.borrowMinter()
            let vaultData = minterRef.getVaultData()

            // add all liquidity to the pair
            let pairPublicRef = self.borrowSwapPairRef()
            if pairPublicRef == nil {
                // DO NOT PANIC
                return false
            }

            // Token0 => self.vault, Token1 => self.flowVault
            let tokenKey = SwapConfig.SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: self.vault.getType().identifier)
            // get the pair info
            let pairInfo = pairPublicRef!.getPairInfo()
            var token0Reserve = 0.0
            var token1Reserve = 0.0
            if tokenKey == (pairInfo[0] as! String) {
                token0Reserve = (pairInfo[2] as! UFix64)
                token1Reserve = (pairInfo[3] as! UFix64)
            } else {
                token0Reserve = (pairInfo[3] as! UFix64)
                token1Reserve = (pairInfo[2] as! UFix64)
            }

            // the vaults for adding liquidity
            let token0Vault <- vaultData.createEmptyVault()
            let token1Vault <- FlowToken.createEmptyVault()

            // add all the token to the pair
            if self.isLocalActive() {
                let token0Max = self.getTokenBalanceInPool()
                // init the liquidity pool with current price
                let tokenInPoolPrice = self.getUnitPrice()
                var token1In = self.getFlowBalanceInPool()
                var token0In = token1In / tokenInPoolPrice

                // setup swap pair based on current price
                if token0Reserve != 0.0 || token1Reserve != 0.0 {
                    // let the price close to the tokenInPoolPrice
                    let swapPrice = SwapConfig.getAmountOut(amountIn: 1.0, reserveIn: token0Reserve, reserveOut: token1Reserve)
                    // we need ensure the final swap price is quite close to the tokenInPoolPrice
                    let scaledToken0Reserve = SwapConfig.UFix64ToScaledUInt256(token0Reserve)
                    let scaledToken1Reserve = SwapConfig.UFix64ToScaledUInt256(token1Reserve)
                    let scaledTokenInPoolPrice = SwapConfig.UFix64ToScaledUInt256(tokenInPoolPrice)
                    // if the swap price is greater than the tokenInPoolPrice, we need to make the swap price cheaper
                    if swapPrice > tokenInPoolPrice {
                        // So we need to add a portion of token0 in pool, increase the token0Reserve and decrease the token1Reserve
                        // Before: swapPrice = token0Reserve / token1Reserve
                        // After: swapPriceAfter = (token0Reserve + x) / (token1Reserve - y) = tokenInPoolPrice
                        // ------------------------------
                        // y is swapToken1Out, x is swapToken0In, so we just need to calculate the optimized x
                        // Swap Formula: token0Reserve * token1Reserve = (token0Reserve + x) * (token1Reserve - y)
                        // => (token1Reserve - y) = (token0Reserve * token1Reserve) / (token0Reserve + x)
                        // => tokenInPoolPrice = (token0Reserve + x) / ((token0Reserve * token1Reserve) / (token0Reserve + x))
                        //                     = (token0Reserve + x)^2 / (token0Reserve * token1Reserve)
                        // => x = sqrt(token0Reserve * token1Reserve * tokenInPoolPrice) - token0Reserve
                        let valueSqrt = SwapConfig.sqrt(scaledToken0Reserve * scaledToken1Reserve * scaledTokenInPoolPrice)
                        let swapToken0In = SwapConfig.ScaledUInt256ToUFix64(valueSqrt.saturatingSubtract(scaledToken0Reserve))
                        // swap the token0 to token1 first, and then add liquidity to token1 vault
                        if swapToken0In > 0.0 {
                            let token0ToSwap <- self.vault.withdraw(amount: swapToken0In)
                            let token1SwappedVault <- pairPublicRef!.swap(
                                vaultIn: <- token0ToSwap,
                                exactAmountOut: nil
                            )
                            // now the swapPrice should be close to the tokenInPoolPrice
                            // so we can re-calculate the token0In & token1In to add liquidity
                            token0In = (token1SwappedVault.balance + token1In) / tokenInPoolPrice
                            // deposit the token1Swapped to the token1Vault
                            token1Vault.deposit(from: <- token1SwappedVault)
                        }
                    } else {
                        // if the swap price is less than the tokenInPoolPrice, we need to make the swap price higher
                        // So we need to add a portion of token0 in pool, decrease the token0Reserve and increase the token1Reserve
                        // Before: swapPrice = token0Reserve / token1Reserve
                        // After: swapPriceAfter = (token0Reserve - x) / (token1Reserve + y) = tokenInPoolPrice
                        // ------------------------------
                        // y is swapToken1In, x is swapToken0Out, so we just need to calculate the optimized y
                        // Swap Formula: token0Reserve * token1Reserve = (token0Reserve - x) * (token1Reserve + y)
                        // => (token1Reserve - x) = (token0Reserve * token1Reserve) / (token1Reserve + y)
                        // => tokenInPoolPrice = (token0Reserve * token1Reserve) / (token1Reserve + y) / (token1Reserve + y)
                        //                     = (token0Reserve * token1Reserve) / (token1Reserve + y)^2
                        // => y = sqrt(token0Reserve * token1Reserve / tokenInPoolPrice) - token1Reserve
                        let valueSqrt = SwapConfig.sqrt(scaledToken0Reserve * scaledToken1Reserve / scaledTokenInPoolPrice)
                        let swapToken1In = SwapConfig.ScaledUInt256ToUFix64(valueSqrt.saturatingSubtract(scaledToken1Reserve))
                        // swap the token1 to token0 first, and then add liquidity to token0 vault
                        if swapToken1In > 0.0 {
                            let token1ToSwap <- self._withdrawFlowToken(swapToken1In)
                            let token0SwappedVault <- pairPublicRef!.swap(
                                vaultIn: <- token1ToSwap,
                                exactAmountOut: nil
                            )
                            // now the swapPrice should be close to the tokenInPoolPrice
                            // add token0 back to the pool
                            self.vault.deposit(from: <- token0SwappedVault)
                            // re-calculate the token0In & token1In to add liquidity
                            token1In = self.getFlowBalanceInPool()
                            token0In = token1In / tokenInPoolPrice
                        }
                    }
                }

                // deposit the token0In & token1In to the vaults
                if token0In > token0Max {
                    token0In = token0Max
                }
                if token0In > 0.0 {
                    token0Vault.deposit(from: <- self.vault.withdraw(amount: token0In))
                }
                token1Vault.deposit(from: <- self._withdrawFlowToken(token1In))

                // set the local liquidity pool to inactive
                self.acitve = false

                // Update in the trading center
                let tradingCenter = FixesTradablePool.borrowTradingCenter()
                tradingCenter.onPoolLPHandovered(self.getPoolAddress())

                // set the flag in shared store
                let acctsPool = FRC20AccountsPool.borrowAccountsPool()
                if let acctKey = self.getAccountsPoolKey() {
                    if let store = acctsPool.borrowWritableConfigStore(type: FRC20AccountsPool.ChildAccountType.FungibleToken, acctKey) {
                        store.setByEnum(
                            FRC20FTShared.ConfigType.TradablePoolHandoveredAt,
                            value: getCurrentBlock().timestamp
                        )
                    }
                }

                // emit the liquidity pool inactivated event
                emit LiquidityPoolInactivated(
                    subject: self.getPoolAddress(),
                    tokenType: self.getTokenType(),
                )
            } else {
                let token0Max = self.getTokenBalanceInPool()
                let allFlowAmount = self.getFlowBalanceInPool()
                let estimatedToken0In = SwapConfig.quote(amountA: allFlowAmount, reserveA: token1Reserve, reserveB: token0Reserve)
                if token0Max >= estimatedToken0In {
                    token0Vault.deposit(from: <- self.vault.withdraw(amount: estimatedToken0In))
                    token1Vault.deposit(from: <- self._withdrawFlowToken(allFlowAmount))
                } else if token0Max > 0.0 {
                    let part1EstimatedToken1In = SwapConfig.quote(amountA: token0Max, reserveA: token0Reserve, reserveB: token1Reserve)
                    let part2EstimatedToken1In = allFlowAmount.saturatingSubtract(part1EstimatedToken1In)
                    if part2EstimatedToken1In > 0.0 {
                        token0Vault.deposit(from: <- self.vault.withdraw(amount: token0Max))
                        token1Vault.deposit(from: <- self._withdrawFlowToken(part1EstimatedToken1In))
                    } else {
                        destroy token0Vault
                        destroy token1Vault
                        // DO NOT PANIC
                        return false
                    }
                } else {
                    // All Token0 is added to the pair, so we need to calculate the optimized zapped amount through dex
                    let zappedAmt = self._calcZappedAmmount(
                        tokenInput: allFlowAmount,
                        tokenReserve: token1Reserve,
                        swapFeeRateBps: pairInfo[6] as! UInt64
                    )
                    // withdraw all the flow token and add liquidity to the pair
                    let payment <- self._withdrawFlowToken(allFlowAmount)

                    let swapVaultIn <- payment.withdraw(amount: zappedAmt)
                    // withdraw all the token0 and add liquidity to the pair
                    token1Vault.deposit(from: <- payment)
                    // swap the token1 to token0 first, and then add liquidity vault
                    token0Vault.deposit(from: <- pairPublicRef!.swap(
                        vaultIn: <- swapVaultIn,
                        exactAmountOut: nil
                    ))
                }
            }

            // cache value
            let token0Amount = token0Vault.balance
            let token1Amount = token1Vault.balance

            // add liquidity to the pair
            let lpTokenVault <- pairPublicRef!.addLiquidity(
                tokenAVault: <- token0Vault,
                tokenBVault: <- token1Vault
            )
            // record the burned LP token
            self.lpBurned = self.lpBurned + lpTokenVault.balance

            // Send the LP token vault to the BlackHole for soft burning
            FixesTradablePool.softBurnVault(<- lpTokenVault)

            // emit the liquidity pool transferred event
            emit LiquidityTransferred(
                subject: self.getPoolAddress(),
                pairAddr: self.getSwapPairAddress()!,
                tokenType: self.getTokenType(),
                tokenAmount: token0Amount,
                flowAmount: token1Amount
            )

            return true
        }

        /// Calculate the optimized zapped amount through dex
        ///
        access(self)
        fun _calcZappedAmmount(tokenInput: UFix64, tokenReserve: UFix64, swapFeeRateBps: UInt64): UFix64 {
            // Cal optimized zapped amount through dex
            let r0Scaled = SwapConfig.UFix64ToScaledUInt256(tokenReserve)
            let fee = 1.0 - UFix64(swapFeeRateBps)/10000.0
            let kplus1SquareScaled = SwapConfig.UFix64ToScaledUInt256((1.0+fee)*(1.0+fee))
            let kScaled = SwapConfig.UFix64ToScaledUInt256(fee)
            let kplus1Scaled = SwapConfig.UFix64ToScaledUInt256(fee+1.0)
            let tokenInScaled = SwapConfig.UFix64ToScaledUInt256(tokenInput)
            let qScaled = SwapConfig.sqrt(
                r0Scaled * r0Scaled / SwapConfig.scaleFactor * kplus1SquareScaled / SwapConfig.scaleFactor
                + 4 * kScaled * r0Scaled / SwapConfig.scaleFactor * tokenInScaled / SwapConfig.scaleFactor)
            return SwapConfig.ScaledUInt256ToUFix64(
                (qScaled - r0Scaled*kplus1Scaled/SwapConfig.scaleFactor)*SwapConfig.scaleFactor/(kScaled*2)
            )
        }
    }

    /// ------ Public Methods ------

    /// Create a new tradable liquidity pool(bonding curve) resource
    ///
    access(account)
    fun createTradableLiquidityPool(
        ins: &Fixes.Inscription,
        _ minter: @{FixesFungibleTokenInterface.IMinter},
    ): @TradableLiquidityPool {
        pre {
            ins.isExtractable(): "The inscription is not extractable"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }

        // execute the inscription
        let meta = self.verifyAndExecuteInscription(ins, symbol: minter.getSymbol(), usage: "*")

        // get the fee percentage from the inscription metadata
        let subjectFeePerc = UFix64.fromString(meta["feePerc"] ?? "0.0") ?? 0.0
        // get free amount from the inscription metadata
        let freeAmount = UFix64.fromString(meta["freeAmount"] ?? "0.0") ?? 0.0
        // using total allowed mintable amount as the max supply
        let maxSupply = minter.getTotalAllowedMintableAmount()
        // create the bonding curve
        let curve = FixesBondingCurve.Quadratic(freeAmount: freeAmount, maxSupply: maxSupply)

        let tokenType = minter.getTokenType()
        let tokenSymbol = minter.getSymbol()

        let pool <- create TradableLiquidityPool(<- minter, curve, subjectFeePerc)

        // emit the liquidity pool created event
        emit LiquidityPoolCreated(
            tokenType: tokenType,
            curveType: curve.getType(),
            tokenSymbol: tokenSymbol,
            subjectFeePerc: subjectFeePerc,
            freeAmount: freeAmount,
            createdBy: ins.owner?.address ?? panic("The inscription owner is missing")
        )

        return <- pool
    }

    /// Soft burn the vault
    ///
    access(all)
    fun softBurnVault(_ vault: @FungibleToken.Vault) {
        let network = AddressUtils.currentNetwork()

        // Send the vault to the BlackHole
        if network == "MAINNET" {
            // Use IncrementFi's BlackHole: https://app.increment.fi/profile/0x9c1142b81f1ae962
            let blackHoleAddr = Address.fromString("0x".concat("9c1142b81f1ae962"))!
            if let blackHoleRef = BlackHole.borrowBlackHoleReceiver(blackHoleAddr) {
                blackHoleRef.deposit(from: <- vault)
            } else {
                BlackHole.vanish(<- vault)
            }
        } else {
            BlackHole.vanish(<- vault)
        }
    }

    /// Verify the inscription for executing the Fungible Token
    ///
    access(all)
    fun verifyAndExecuteInscription(
        _ ins: &Fixes.Inscription,
        symbol: String,
        usage: String
    ): {String: String} {
        // borrow the accounts pool
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        // check the operation
        assert(
            meta["op"] == "exec",
            message: "The inscription operation must be 'exec'"
        )
        // check the symbol
        let tick = meta["tick"] ?? panic("The token symbol is not found")
        assert(
            acctsPool.getFTContractAddress(tick) != nil,
            message: "The FungibleToken contract is not found"
        )
        assert(
            tick == "$".concat(symbol),
            message: "The minter's symbol is not matched. Required: $".concat(symbol)
        )
        // check the usage
        let usageInMeta = meta["usage"] ?? panic("The token operation is not found")
        assert(
            usageInMeta == usage || usage == "*",
            message: "The inscription is not for initialize a Fungible Token account"
        )
        // execute the inscription
        acctsPool.executeInscription(type: FRC20AccountsPool.ChildAccountType.FungibleToken, ins)
        // return the metadata
        return meta
    }

    /// Check if the caller is an advanced token player(by staked $flows)
    ///
    access(all)
    view fun isAdvancedTokenPlayer(_ addr: Address): Bool {
        let stakeTick = FRC20FTShared.getPlatformStakingTickerName()
        // the threshold is 100K staked $flows
        let threshold = 100_000.0
        return FRC20StakingManager.isEligibleByStakePower(stakeTick: stakeTick, addr: addr, threshold: threshold)
    }

    /// Get the flow price from IncrementFi Oracle
    ///
    access(all)
    view fun getFlowPrice(): UFix64 {
        let network = AddressUtils.currentNetwork()
        // reference: https://docs.increment.fi/protocols/decentralized-price-feed-oracle/deployment-addresses
        var oracleAddress: Address? = nil
        if network == "MAINNET" {
            // TO FIX stupid fcl bug
            oracleAddress = Address.fromString("0x".concat("e385412159992e11"))
        }
        if oracleAddress == nil {
            // Hack for testnet and emulator
            return 1.0
        } else {
            return PublicPriceOracle.getLatestPrice(oracleAddr: oracleAddress!)
        }
    }

    /// Get the target market cap for creating LP
    ///
    access(all)
    view fun getTargetMarketCap(): UFix64 {
        // use the shared store to get the sale fee
        let sharedStore = FRC20FTShared.borrowGlobalStoreRef()
        let valueInStore = sharedStore.getByEnum(FRC20FTShared.ConfigType.TradablePoolCreateLPTargetMarketCap) as! UFix64?
        // Default is 32800 USD
        let defaultTargetMarketCap = 32800.0
        return valueInStore ?? defaultTargetMarketCap
    }

    /// Get the trading pool protocol fee
    ///
    access(all)
    view fun getProtocolTradingFee(): UFix64 {
        post {
            result >= 0.0: "The platform sales fee must be greater than or equal to 0"
            result <= 0.02: "The platform sales fee must be less than or equal to 0.02"
        }
        // use the shared store to get the sale fee
        let sharedStore = FRC20FTShared.borrowGlobalStoreRef()
        // Default sales fee, 0.5% of the total price
        let defaultSalesFee = 0.005
        let salesFee = (sharedStore.getByEnum(FRC20FTShared.ConfigType.TradablePoolTradingFee) as! UFix64?) ?? defaultSalesFee
        return salesFee
    }

    /// Get the public capability of Tradable Pool
    ///
    access(all)
    view fun borrowTradablePool(_ addr: Address): &TradableLiquidityPool{LiquidityPoolInterface, FixesFungibleTokenInterface.LiquidityHolder, FixesFungibleTokenInterface.IMinterHolder, FixesHeartbeat.IHeartbeatHook, FungibleToken.Receiver}? {
        // @deprecated in Cadence 1.0
        return getAccount(addr)
            .getCapability<&TradableLiquidityPool{LiquidityPoolInterface, FixesFungibleTokenInterface.LiquidityHolder, FixesFungibleTokenInterface.IMinterHolder, FixesHeartbeat.IHeartbeatHook, FungibleToken.Receiver}>(self.getLiquidityPoolPublicPath())
            .borrow()
    }

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FixesTradablePool_".concat(self.account.address.toString()).concat("_")
    }

    /// Get the storage path for the Liquidity Pool
    ///
    access(all)
    view fun getLiquidityPoolStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("LiquidityPool"))!
    }

    /// Get the public path for the Liquidity Pool
    ///
    access(all)
    view fun getLiquidityPoolPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("LiquidityPool"))!
    }

    /// Get the storage path for the Trading Center
    ///
    access(all)
    view fun getTradingCenterStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("TradingCenter"))!
    }

    /// Get the public path for the Trading Center
    ///
    access(all)
    view fun getTradingCenterPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("TradingCenter"))!
    }

    /// Create the trading information center
    ///
    access(all)
    fun createCenter(): @TradingCenter {
        return <- create TradingCenter()
    }

    /// Borrow the trading information center
    ///
    access(all)
    view fun borrowTradingCenter(): &TradingCenter{CeneterPublic} {
        return self.account
            .getCapability<&TradingCenter{CeneterPublic}>(self.getTradingCenterPublicPath())
            .borrow()
            ?? panic("The Trading Center is missing")
    }

    init() {
        let storagePath = self.getTradingCenterStoragePath()
        self.account.save(<- self.createCenter(), to: storagePath)
        self.account.link<&TradingCenter{CeneterPublic}>(self.getTradingCenterPublicPath(), target: storagePath)
    }
}
