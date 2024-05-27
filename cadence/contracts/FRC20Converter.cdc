/**
> Author: FIXeS World <https://fixes.world/>

# FRC20 Token Converter

This contract is used to convert FRC20 tokens to Fungible Tokens and vice versa.

*/
import "FungibleToken"
import "FlowToken"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20Indexer"

access(all) contract FRC20Converter {
    /* --- Events --- */

    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()
    /// Event emitted when the FRC20 Converter is created
    access(all) event FRC20ConverterCreated(
        _ ticker: String,
        tokenType: Type
    )
    /// Event emitted when the FRC20 tokens are burned
    access(all) event FRC20TokenBurned(
        _ ticker: String,
        amount: UFix64,
        flowRefund: UFix64,
        receiver: Type
    )

    /** --- Interfaces & Resources --- */

    /// Interface for the FRC20 Treasury Receiver
    ///
    access(all) resource interface FRC20TreasuryReceiver {
        access(all)
        fun depositFlowToken(_ token: @{FungibleToken.Vault}) {
            pre {
                token.isInstance(Type<@FlowToken.Vault>()): "Invalid token type"
            }
        }
    }

    /// Interface for the FRC20 Burner
    ///
    access(all) resource interface IFRC20Burner {
        /// check if the ticker is burnable
        access(all)
        view fun isTickerBurnable(_ tick: String): Bool
        /// all the unburnable ticks
        access(all)
        view fun getUnburnableTicks(): [String]
        /// burn and send the tokens
        access(all)
        fun burnAndSend(_ ins: auth(Fixes.Extractable) &Fixes.Inscription, recipient: &{FRC20TreasuryReceiver})
    }

    /// System Burner
    ///
    access(all) resource SystemBurner: IFRC20Burner {
        /// all the unburnable ticks
        ///
        access(all)
        view fun getUnburnableTicks(): [String] {
            return [
                FRC20FTShared.getPlatformStakingTickerName(),
                FRC20FTShared.getPlatformUtilityTickerName()
            ]
        }

        /// check if the ticker is burnable
        ///
        access(all)
        view fun isTickerBurnable(_ tick: String): Bool {
            return !self.getUnburnableTicks().contains(tick)
        }

        /// burn and send the tokens
        ///
        access(all)
        fun burnAndSend(_ ins: auth(Fixes.Extractable) &Fixes.Inscription, recipient: &{FRC20TreasuryReceiver}) {
            pre {
                ins.isExtractable(): "Inscription is not extractable"
            }
            post {
                ins.isExtracted(): "Inscription is not extracted"
            }
            let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
            let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
            assert(
                self.isTickerBurnable(tick),
                message: "The token is not burnable by the system burner."
            )
            let amt = UFix64.fromString(meta["amt"]!) ?? panic("The amount is not a valid UFix64")
            // burn the tokens
            let frc20Indexer = FRC20Indexer.getIndexer()
            let flowVault <- frc20Indexer.burnFromTreasury(ins: ins)
            let flowRefundAmount = flowVault.balance
            // deposit the flow tokens
            recipient.depositFlowToken(<- flowVault)

            // emit the event
            emit FRC20TokenBurned(
                tick,
                amount: amt,
                flowRefund: flowRefundAmount,
                receiver: recipient.getType()
            )
        }
    }

    /// Interface for the FRC20 Converter
    ///
    access(all) resource interface IConverter {
        /// get the ticker name
        access(all)
        view fun getTickerName(): String
        /// get the token type
        access(all)
        view fun getTokenType(): Type
        /// convert the frc20 to the frc20 FT
        access(all)
        fun convertFromIndexer(ins: auth(Fixes.Extractable) &Fixes.Inscription, recipient: &{FungibleToken.Receiver}) {
            pre {
                ins.isExtractable(): "Inscription is not extractable"
                recipient.getSupportedVaultTypes()[self.getTokenType()] == true: "Recipient does not support the token type"
            }
            post {
                ins.isExtracted(): "Inscription is not extracted"
            }
        }
        /// convert the frc20 FT to the frc20
        access(all)
        fun convertBackToIndexer(ins: auth(Fixes.Extractable) &Fixes.Inscription, vault: @{FungibleToken.Vault}) {
            pre {
                ins.isExtractable(): "Inscription is not extractable"
                vault.getType() == self.getTokenType(): "Vault does not support the token type"
            }
            post {
                ins.isExtracted(): "Inscription is not extracted"
            }
        }
    }

    /// The general FRC20 Converter for arbitrary FRC20 Token
    ///
    access(all) resource FTConverter: IConverter {
        access(self)
        let adminCap: Capability<auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IAdminWritable}>

        init(
            _ cap: Capability<auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IAdminWritable}>
        ) {
            self.adminCap = cap

            // emit the event
            let minter = self.borrowMinterRef()
            emit FRC20ConverterCreated(
                minter.getSymbol(),
                tokenType: minter.getTokenType()
            )
        }

        // ---- IConverter ----

        /// get the ticker name
        ///
        access(all)
        view fun getTickerName(): String {
            let minter = self.borrowMinterRef()
            return minter.getSymbol()
        }

        /// get the token type
        access(all)
        view fun getTokenType(): Type {
            let minter = self.borrowMinterRef()
            return minter.getTokenType()
        }

        /// convert the frc20 to the frc20 FT
        ///
        access(all)
        fun convertFromIndexer(ins: auth(Fixes.Extractable) &Fixes.Inscription, recipient: &{FungibleToken.Receiver}) {
            // borrow the minter reference
            let minter = self.borrowMinterRef()

            // parse the metadata
            let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
            let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
            let minterTicker = minter.getSymbol()
            assert(
                minterTicker == tick,
                message: "The token tick does not match the converter ticker"
            )

            let amt = UFix64.fromString(meta["amt"]!) ?? panic("The amount is not a valid UFix64")
            let minterType = minter.getTokenType()
            // convert the tokens
            let emptyVault <- minter.mintTokens(amount: 0.0)
            let convertedVault <- minter.initializeVaultByInscription(vault: <- emptyVault, ins: ins)
            assert(
                convertedVault.getType() == minterType,
                message: "The converted vault type does not match the minter type"
            )
            assert(
                amt == convertedVault.balance,
                message: "The converted vault balance does not match the inscription amount"
            )

            recipient.deposit(from: <- convertedVault)
        }

        /// convert the frc20 FT to the frc20
        ///
        access(all)
        fun convertBackToIndexer(ins: auth(Fixes.Extractable) &Fixes.Inscription, vault: @{FungibleToken.Vault}) {
            // borrow the minter reference
            let minter = self.borrowMinterRef()

            // parse the metadata
            let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
            let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
            let minterTicker = minter.getSymbol()
            assert(
                minterTicker == tick,
                message: "The token tick does not match the converter ticker"
            )
            // burn the tokens
            minter.burnTokenWithInscription(vault: <- vault, ins: ins)
        }

        // ----- Internal Methods ----

        /// Borrow the admin reference
        ///
        access(self)
        view fun borrowAdminRef(): auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IAdminWritable} {
            return self.adminCap.borrow()
                ?? panic("Could not borrow the admin reference")
        }

        /// Borrow the super minter reference
        ///
        access(self)
        view fun borrowMinterRef(): auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IMinter} {
            return self.borrowAdminRef().borrowSuperMinter()
        }
    }

    /** ------- Public Methods ---- */

    /// Borrow the system burner reference
    ///
    access(all)
    view fun borrowSystemBurner(): &SystemBurner {
        return getAccount(self.account.address)
            .capabilities.get<&SystemBurner>(self.getSystemBurnerPublicPath())
            .borrow()
            ?? panic("Could not borrow the SystemBurner reference")
    }

    /// Create the FRC20 Converter
    ///
    access(all)
    fun createConverter(
        _ privCap: Capability<auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IAdminWritable}>
    ): @FTConverter {
        return <- create FTConverter(privCap)
    }

    /// Borrow the FRC20 Converter
    ///
    access(all)
    view fun borrowConverter(_ addr: Address): &FTConverter? {
        return getAccount(addr)
            .capabilities.get<&FTConverter>(self.getFTConverterPublicPath())
            .borrow()
    }

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FRC20Converter_".concat(self.account.address.toString()).concat("_")
    }

    /// Get the system burner storage path
    ///
    access(all)
    view fun getSystemBurnerStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("SystemBurner"))!
    }

    /// Get the system burner public path
    ///
    access(all)
    view fun getSystemBurnerPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("SystemBurner"))!
    }

    /// Get the ft converter storage path
    ///
    access(all)
    view fun getFTConverterStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("FTConverter"))!
    }

    /// Get the ft converter public path
    ///
    access(all)
    view fun getFTConverterPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("FTConverter"))!
    }

    init() {
        let storagePath = self.getSystemBurnerStoragePath()
        self.account.storage.save(<- create SystemBurner(), to: storagePath)
        // publish the public path
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&SystemBurner>(storagePath),
            at: self.getSystemBurnerPublicPath()
        )

        emit ContractInitialized()
    }
}
