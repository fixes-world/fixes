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

    // Event that is emitted when the liquidity pool is transferred.
    access(all) event LiquidityPoolTransferred(subject: Address, pairAddr: Address, tokenType: Type, tokenAmount: UFix64, flowAmount: UFix64)

    // Event that is emitted when a user buys or sells tokens.
    access(all) event Trade(trader: Address, isBuy: Bool, subject: Address, ticker: String, tokenAmount: UFix64, flowAmount: UFix64, protocolFee: UFix64, subjectFee: UFix64, supply: UFix64)

    /// -------- Resources and Interfaces --------

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

        /// Get the swap pair address
        access(all)
        view fun getSwapPairAddress(): Address?

        /// Get the liquidity market cap
        access(all)
        view fun getLiquidityMarketCap(): UFix64 {
            if self.isLocalActive() {
                let flowAmount = self.getFlowBalanceInPool()
                let flowPrice = FixesTradablePool.getFlowPrice()
                // The market cap is the flow amount * flow price * 2.0
                // According to the Token value is equal to the Flow token value.
                return flowAmount * flowPrice * 2.0
            } else {
                // current no liquidity in the pool, all LP token is burned
                return 0.0
            }
        }

        /// Get the locked liquidity market cap
        access(all)
        view fun getBurnedLiquidityMarketCap(): UFix64 {
            if self.isLocalActive() {
                return 0.0
            } else {
                let burnedLP = self.getBurnedLP()
                let lpPrice = self.getLPPriceInFlow()
                let flowPrice = FixesTradablePool.getFlowPrice()
                return burnedLP * lpPrice * flowPrice
            }
        }

        /// Get the token market cap
        ///
        access(all)
        view fun getTokenMarketCap(): UFix64 {
            let tokenSupply = self.getTotalSupply()
            let tokenPrice = self.getTokenPriceInFlow()
            let flowPrice = FixesTradablePool.getFlowPrice()
            return tokenSupply * tokenPrice * flowPrice
        }

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

        // ---- Bonding Curve ----

        /// Get the curve type
        access(all)
        view fun getCurveType(): Type {
            return self.curve.getType()
        }

        /// Get the price of the token based on the supply and amount
        access(all)
        view fun getPrice(supply: UFix64, amount: UFix64): UFix64 {
            return self.curve.calculatePrice(supply: supply, amount: amount)
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

    /// The liquidity pool admin interface.
    ///
    access(all) resource interface LiquidityPoolAdmin {
        /// Initialize the liquidity pool
        ///
        access(all)
        fun initialize()

        // The admin can set the subject fee percentage
        //
        access(all)
        fun setSubjectFeePercentage(_ subjectFeePerc: UFix64)
    }

    /// The liquidity pool resource.
    ///
    access(all) resource TradableLiquidityPool: LiquidityPoolInterface, LiquidityPoolAdmin, FungibleToken.Receiver, FixesFungibleTokenInterface.IMinterHolder, FixesHeartbeat.IHeartbeatHook {
        /// The bonding curve of the liquidity pool
        access(contract)
        let curve: {FixesBondingCurve.CurveInterface}
        // The minter of the token
        access(self)
        let minter: @{FixesFungibleTokenInterface.IMinter}
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

        init(
            _ minter: @{FixesFungibleTokenInterface.IMinter},
            _ curve: {FixesBondingCurve.CurveInterface},
            _ subjectFeePerc: UFix64?
        ) {
            pre {
                subjectFeePerc == nil || subjectFeePerc! < 0.01: "Invalid Subject Fee"
            }
            self.minter <- minter
            self.curve = curve
            self.subjectFeePercentage = subjectFeePerc ?? 0.0

            let vaultData = self.minter.getVaultData()
            self.vault <- vaultData.createEmptyVault()
            self.flowVault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.acitve = false
            self.lpBurned = 0.0
        }

        // @deprecated in Cadence v1.0
        destroy() {
            destroy self.minter
            destroy self.vault
            destroy self.flowVault
        }

        // ----- Implement LiquidityPoolAdmin -----

        /// Initialize the liquidity pool
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
            self.vault.deposit(from: <- newVault)
            self.acitve = true

            // Emit the event
            emit LiquidityPoolInitialized(
                subject: self.getPoolAddress(),
                tokenType: self.getTokenType(),
                mintedAmount: totalMintAmount
            )
        }

        // The admin can set the subject fee percentage
        // The subject fee percentage must be greater than or equal to 0 and less than or equal to 0.01
        //
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
                return self.getBuyPrice(1.0)
            } else {
                let pairRef = self.borrowSwapPairRef()
                if pairRef == nil {
                    return 0.0
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
                return SwapConfig.quote(amountA: 1.0, reserveA: reserve0, reserveB: reserve1)
            }
        }

        /// Get the LP token price
        ///
        access(all)
        view fun getLPPriceInFlow(): UFix64 {
            if self.isLocalActive() {
                return 0.0
            } else {
                let pairRef = self.borrowSwapPairRef()
                if pairRef == nil {
                    return 0.0
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
                let price0 = SwapConfig.quote(amountA: 1.0, reserveA: reserve0, reserveB: reserve1)
                let totalValueInFlow = price0 * reserve0 + reserve1 * 1.0
                return totalValueInFlow / lpTokenSupply
            }
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
        view fun borrowSwapPairRef(): &AnyResource{SwapInterfaces.PairPublic}? {
            if let pairAddr = self.getSwapPairAddress() {
                return getAccount(pairAddr)
                    .getCapability<&AnyResource{SwapInterfaces.PairPublic}>(SwapConfig.PairPublicPath)
                    .borrow()
            }
            return nil
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
        access(all) fun deposit(from: @FungibleToken.Vault) {
            self.flowVault.deposit(from: <- from)

            // if not active, then try to add liquidity
            let swapThreshold = 10.0
            if !self.isLocalActive() && self.flowVault.balance >= swapThreshold {
                self._ensureSwapPairAndAddLiquidity()
            }
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
            let minter = self.borrowMinter()
            // extract all Flow tokens from the inscription
            let flowAvailableAmount = ins.getInscriptionValue() - ins.getMinCost()
            let flowAvailableVault <- ins.partialExtract(flowAvailableAmount)
            // calculate the price
            var price: UFix64 = 0.0
            var protocolFee: UFix64 = 0.0
            var subjectFee: UFix64 = 0.0
            var buyAmount: UFix64 = 0.0
            if amount != nil {
                buyAmount = amount!
                price = self.getBuyPrice(buyAmount)
                protocolFee = price * FixesTradablePool.getProtocolTradingFee()
                subjectFee = price * self.getSubjectFeePercentage()
            } else {
                protocolFee = flowAvailableVault.balance * FixesTradablePool.getProtocolTradingFee()
                subjectFee = flowAvailableVault.balance * self.getSubjectFeePercentage()
                price = flowAvailableVault.balance - protocolFee - subjectFee
                buyAmount = self.getBuyAmount(price)
            }

            // check the total cost
            let totalCost = price + protocolFee + subjectFee
            assert(
                totalCost <= flowAvailableVault.balance,
                message: "Insufficient payment: The total cost is greater than the available Flow tokens"
            )
            let payment <- flowAvailableVault.withdraw(amount: totalCost)
            if protocolFee > 0.0 {
                let protocolFeeVault <- payment.withdraw(amount: protocolFee)
                let protocolFeeReceiverRef = Fixes.borrowFlowTokenReceiver(Fixes.getPlatformFeeDestination())
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
            self.flowVault.deposit(from: <- payment)

            let insOwner = ins.owner?.address ?? panic("The inscription owner is missing")
            // return remaining Flow tokens to the inscription owner
            if flowAvailableVault.balance > 0.0 {
                let ownerFlowVaultRef = Fixes.borrowFlowTokenReceiver(insOwner)
                    ?? panic("The inscription owner does not have a FlowTokenReceiver capability")
                ownerFlowVaultRef.deposit(from: <- flowAvailableVault)
            } else {
                destroy flowAvailableVault
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
            let returnVault <- minter.initializeVaultByInscription(
                vault: <- self.vault.withdraw(amount: buyAmount),
                ins: ins
            )
            // deposit the tokens to the recipient
            recipient.deposit(from: <- returnVault)

            // emit the trade event
            let tickerName = "$".concat(minter.getSymbol())
            let poolAddr = self.getPoolAddress()
            let traderAddr = recipient.owner?.address ?? insOwner

            // invoke the transaction hook
            self._onTransactionDeal(
                seller: poolAddr,
                buyer: traderAddr,
                tick: tickerName,
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
            let protocolFee = totalPrice * FixesTradablePool.getProtocolTradingFee()
            let subjectFee = totalPrice * self.getSubjectFeePercentage()
            let userFund = totalPrice - protocolFee - subjectFee
            // withdraw the protocol fee from the flow vault
            if protocolFee > 0.0 {
                let protocolFeeVault <- self.flowVault.withdraw(amount: protocolFee)
                let protocolFeeReceiverRef = Fixes.borrowFlowTokenReceiver(Fixes.getPlatformFeeDestination())
                    ?? panic("The protocol fee destination does not have a FlowTokenReceiver capability")
                protocolFeeReceiverRef.deposit(from: <- protocolFeeVault)
            }
            // withdraw the subject fee from the flow vault
            if subjectFee > 0.0 {
                let subjectFeeVault <- self.flowVault.withdraw(amount: subjectFee)
                let subjectFeeReceiverRef = Fixes.borrowFlowTokenReceiver(self.getPoolAddress())
                    ?? panic("The subject does not have a FlowTokenReceiver capability")
                subjectFeeReceiverRef.deposit(from: <- subjectFeeVault)
            }
            // withdraw the user fund from the flow vault
            recipient.deposit(from: <- self.flowVault.withdraw(amount: userFund))

            // deposit the tokens to the token vault
            let tokenAmount = tokenVault.balance
            self.vault.deposit(from: <- tokenVault)

            // emit the trade event
            let tickerName = "$".concat(minter.getSymbol())
            let poolAddr = self.getPoolAddress()
            let traderAddr = recipient.owner?.address ?? panic("The recipient owner is missing")

            // invoke the transaction hook
            self._onTransactionDeal(
                seller: traderAddr,
                buyer: poolAddr,
                tick: tickerName,
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

        // ----- Internal Methods -----

        /// The hook that is invoked when a deal is executed
        ///
        access(self)
        fun _onTransactionDeal(
            seller: Address,
            buyer: Address,
            tick: String,
            dealAmount: UFix64,
            dealPrice: UFix64,
        ) {
            let minter = self.borrowMinter()
            // for fixes fungible token, the ticker is $ + {symbol}
            let tickName = "$".concat(minter.getSymbol())

            // ------- start -- Invoke Hooks --------------
            // Invoke transaction hooks to do things like:
            // -- Record the transction record
            // -- Record trading Volume

            // for TradablePool hook
            let poolAddr = self.getPoolAddress()
            // Buyer or Seller should be the pool address
            assert(
                buyer == poolAddr || seller == poolAddr,
                message: "The buyer or seller must be the pool address"
            )

            // invoke the pool transaction hook
            if let poolTransactionHook = FRC20FTShared.borrowTransactionHook(poolAddr) {
                poolTransactionHook.onDeal(
                    seller: seller,
                    buyer: buyer,
                    tick: tickName,
                    dealAmount: dealAmount,
                    dealPrice: dealPrice,
                    storefront: poolAddr,
                    listingId: nil,
                )
            }
            // invoke the user transaction hook
            let userAddr = buyer == poolAddr ? seller : buyer
            if let userTransactionHook = FRC20FTShared.borrowTransactionHook(userAddr) {
                userTransactionHook.onDeal(
                    seller: seller,
                    buyer: buyer,
                    tick: tickName,
                    dealAmount: dealAmount,
                    dealPrice: dealPrice,
                    storefront: poolAddr,
                    listingId: nil,
                )
            }
        }

        // ----- Implement IMinterHolder -----

        access(contract)
        view fun borrowMinter(): &AnyResource{FixesFungibleTokenInterface.IMinter} {
            return &self.minter as &AnyResource{FixesFungibleTokenInterface.IMinter}
        }

        // ----- Implement IHeartbeatHook -----

        /// The methods that is invoked when the heartbeat is executed
        /// Before try-catch is deployed, please ensure that there will be no panic inside the method.
        ///
        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            // if active, then move the liquidity pool to the next stage
            self._ensureSwapPairAndAddLiquidity()
        }

        /// Create a new pair and add liquidity
        ///
        access(self)
        fun _ensureSwapPairAndAddLiquidity() {
            if self.isLocalActive() {
                // Check the market cap
                let localMarketCap = self.getLiquidityMarketCap()
                let targetMarketCap = FixesTradablePool.getTargetMarketCap()
                // if the market cap is less than the target market cap, then do nothing
                if localMarketCap < targetMarketCap {
                    // DO NOT PANIC
                    return
                }
            } else {
                // check if flow vault has enough liquidity, if not then do nothing
                if self.flowVault.balance < 1.0 {
                    // DO NOT PANIC
                    return
                }
            }

            // Now we can add liquidity to the swap pair
            let minterRef = self.borrowMinter()
            let vaultData = minterRef.getVaultData()

            // check if the token paire is created, if not then create the pair
            // Token0 => self.vault, Token1 => self.flowVault

            var pairAddr = self.getSwapPairAddress()
            // if the pair is not created, then create the pair
            if pairAddr == nil {
                // create the account creation fee vault
                let acctCreateFeeVault <- self.flowVault.withdraw(amount: 0.01)
                // create the pair
                SwapFactory.createPair(
                    token0Vault: <- vaultData.createEmptyVault(),
                    token1Vault: <- FlowToken.createEmptyVault(),
                    accountCreationFee: <- acctCreateFeeVault,
                    stableMode: false
                )
                // set the pair address again
                pairAddr = self.getSwapPairAddress()
            }
            // check again
            if pairAddr == nil {
                // DO NOT PANIC
                return
            }
            // add all liquidity to the pair
            let pairPublicRef = self.borrowSwapPairRef()
            if pairPublicRef == nil {
                // DO NOT PANIC
                return
            }
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
                let token0In = self.getTokenBalanceInPool()
                var token1In = self.getFlowBalanceInPool()
                // add all the token to the pair
                if token0Reserve != 0.0 || token1Reserve != 0.0 {
                    token1In = SwapConfig.quote(amountA: token0In, reserveA: token0Reserve, reserveB: token1Reserve)
                    if token1In > token1In {
                        destroy token0Vault
                        destroy token1Vault
                        // DO NOT PANIC
                        return
                    }
                }
                if token0In > 0.0 {
                    token0Vault.deposit(from: <- self.vault.withdraw(amount: token0In))
                }
                token1Vault.deposit(from: <- self.flowVault.withdraw(amount: token1In))
                // set the local liquidity pool to inactive
                self.acitve = false
            } else {
                // All Token0 is added to the pair, so we need to calculate the optimized zapped amount through dex
                let allFlowAmount = self.flowVault.balance
                let zappedAmt = self._calcZappedAmmount(
                    tokenInput: allFlowAmount,
                    tokenReserve: token1Reserve,
                    swapFeeRateBps: pairInfo[6] as! UInt64
                )

                let swapVaultIn <- self.flowVault.withdraw(amount: zappedAmt)
                // withdraw all the token0 and add liquidity to the pair
                token1Vault.deposit(from: <- self.flowVault.withdraw(amount: allFlowAmount - zappedAmt))
                // swap the token1 to token0 first, and then add liquidity vault
                token0Vault.deposit(from: <- pairPublicRef!.swap(
                    vaultIn: <- swapVaultIn,
                    exactAmountOut: nil
                ))
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
            emit LiquidityPoolTransferred(
                subject: self.getPoolAddress(),
                pairAddr: pairAddr!,
                tokenType: self.getTokenType(),
                tokenAmount: token0Amount,
                flowAmount: token1Amount
            )
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
        _ minter: @AnyResource{FixesFungibleTokenInterface.IMinter},
    ): @TradableLiquidityPool {
        pre {
            ins.isExtractable(): "The inscription is not extractable"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }
        // singletons
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        let tick = meta["tick"] ?? panic("The ticker name is not found")
        assert(
            acctsPool.getFTContractAddress(tick) != nil,
            message: "The FungibleToken contract is not found"
        )
        assert(
            tick == "$".concat(minter.getSymbol()),
            message: "The minter capability address is not the same as the FungibleToken contract"
        )

        // get the fee percentage from the inscription metadata
        let subjectFeePerc = UFix64.fromString(meta["feePerc"] ?? "0.0") ?? 0.0
        // get free amount from the inscription metadata
        let freeAmount = UFix64.fromString(meta["freeAmount"] ?? "0.0") ?? 0.0
        // using total allowed mintable amount as the max supply
        let maxSupply = minter.getTotalAllowedMintableAmount()
        // create the bonding curve
        let curve = FixesBondingCurve.Quadratic(freeAmount: freeAmount, maxSupply: maxSupply)

        // execute the inscription
        acctsPool.executeInscription(type: FRC20AccountsPool.ChildAccountType.FungibleToken, ins)

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
        // Default is 6480 USD
        let defaultTargetMarketCap = 6480.0
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
    view fun borrowTradablePool(_ addr: Address): &TradableLiquidityPool{LiquidityPoolInterface, FungibleToken.Receiver, FixesFungibleTokenInterface.IMinterHolder, FixesHeartbeat.IHeartbeatHook}? {
        // @deprecated in Cadence 1.0
        return getAccount(addr)
            .getCapability<&TradableLiquidityPool{LiquidityPoolInterface, FungibleToken.Receiver, FixesFungibleTokenInterface.IMinterHolder, FixesHeartbeat.IHeartbeatHook}>(self.getLiquidityPoolPublicPath())
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
}
