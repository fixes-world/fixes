/**
> Author: FIXeS World <https://fixes.world/>

# FRC20StakingForwarder

The FRC20StakingForwarder contract is a forwarder contract that forwards the Fungible Token to the FRC20Staking Pool.

*/
import "FungibleToken"
import "FlowToken"
import "Fixes"
import "FRC20FTShared"
import "FRC20Staking"

access(all) contract FRC20StakingForwarder {
    /* --- Events --- */

    // Event that is emitted when tokens are deposited to the target receiver
    access(all) event ForwardedDeposit(amount: UFix64, from: Address?)

    /* --- Variable, Enums and Structs --- */
    access(all)
    let StakingForwarderStoragePath: StoragePath
    access(all)
    let StakingForwarderPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    access(all) resource interface ForwarderPublic {
        /// Helper function to check whether set `recipient` capability
        /// is not latent or the capability tied to a type is valid.
        access(all)
        view fun check(): Bool

        /// Gets the fallback receiver assigned to the account
        access(all)
        view fun fallbackBorrow(): &{FungibleToken.Receiver}?
    }

    access(all) resource Forwarder: FungibleToken.Receiver, ForwarderPublic {
        /// The capability of staking pool
        access(self) let pool: Capability<&FRC20Staking.Pool>

        init(_ poolAddr: Address) {
            post {
                self.pool.check(): "Pool Capability is not valid"
            }
            self.pool = FRC20Staking.getPoolCap(poolAddr)
        }

        /// Helper function to check whether set `pool` capability
        /// is not latent or the capability tied to a type is valid.
        access(all)
        view fun check(): Bool {
            return self.pool.check()
        }

        /// Gets the fallback receiver assigned to the account
        ///
         view access(all) fun fallbackBorrow(): &{FungibleToken.Receiver}? {
            let ownerAddress = self.owner?.address ?? panic("No owner set")
            let cap = getAccount(ownerAddress)
                .capabilities.get<&{FungibleToken.Receiver}>(Fixes.getFallbackFlowTokenPublicPath())
            return cap.check() ? cap.borrow() : nil
        }

        /// A getter function that returns the token types supported by this resource,
        /// which can be deposited using the 'deposit' function.
        ///
        /// @return Array of FT types that can be deposited.
        access(all)
        view fun getSupportedVaultTypes(): {Type: Bool} {
            pre {
                self.check(): "Forwarder capability is not valid"
            }
            let supportedVaults: {Type: Bool} = {}

            let poolRef = self.pool.borrow()
                ?? panic("Could not borrow pool reference")
            let rewardTicks = poolRef.getRewardNames()
            for rewardTick in rewardTicks {
                if let rewardVault = poolRef.getRewardDetails(rewardTick) {
                    if rewardVault.rewardVaultType != nil {
                        supportedVaults[rewardVault.rewardVaultType!] = true
                    }
                }
            }
            return supportedVaults
        }

        /// Returns whether or not the given type is accepted by the Receiver
        /// A vault that can accept any type should just return true by default
        access(all)
        view fun isSupportedVaultType(type: Type): Bool {
            pre {
                self.check(): "Forwarder capability is not valid"
            }
            let supportedVaults = self.getSupportedVaultTypes()
            return supportedVaults[type] ?? false
        }

        // deposit
        //
        // Function that takes a Vault object as an argument and forwards
        // it to the recipient's Vault using the stored reference
        //
        access(all)
        fun deposit(from: @{FungibleToken.Vault}) {
            let poolRef = self.pool.borrow()
                ?? panic("Could not borrow pool reference")

            let forwarderAddr = self.owner?.address ?? panic("No owner set in Staking Forwarder")
            let balance = from.balance
            let rewardType = from.getType()

            let poolDetails = poolRef.getDetails()
            let totalStakedAmount = poolDetails.totalStaked

            var rewardStrategyRef: &FRC20Staking.RewardStrategy? = poolRef.borrowRewardStrategy(rewardType.identifier)
            if rewardStrategyRef == nil && from.isInstance(Type<@FlowToken.Vault>()) {
                rewardStrategyRef = poolRef.borrowRewardStrategy("")
            }

            let fallbackReceiver = self.fallbackBorrow()
                ?? panic("No fallback receiver set in Staking Forwarder")

            let yieldValue = totalStakedAmount > 0.0 ? balance / totalStakedAmount : 0.0
            // If the yield value is 0 or the reward strategy is not found
            if yieldValue == 0.0 || rewardStrategyRef == nil {
                fallbackReceiver.deposit(from: <- from)
            } else {
                // Forward the tokens to staking pool
                let change <- FRC20FTShared.wrapFungibleVaultChange(
                    ftVault: <- from,
                    from: forwarderAddr,
                )
                rewardStrategyRef!.addIncome(income: <- change)
                emit ForwardedDeposit(amount: balance, from: forwarderAddr)
            }
        }
    }

    // createNewForwarder creates a new Forwarder reference with the provided recipient
    //
    access(all)
    fun createNewForwarder(_ poolAddr: Address): @Forwarder {
        return <-create Forwarder(poolAddr)
    }

    init() {
        let identifier = "FRC20StakingForwarder_".concat(self.account.address.toString())
        self.StakingForwarderStoragePath = StoragePath(identifier: identifier)!
        self.StakingForwarderPublicPath = PublicPath(identifier: identifier)!
    }
}
