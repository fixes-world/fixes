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
import "FRC20AccountsPool"

access(all) contract FRC20Converter {
    /* --- Events --- */

    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /** --- Interfaces & Resources --- */

    /// Interface for the FRC20 Treasury Receiver
    ///
    access(all) resource interface FRC20TreasuryReceiver {
        access(all)
        fun depositFlowToken(_ token: @FungibleToken.Vault) {
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
        fun burnAndSend(_ ins: &Fixes.Inscription, recipient: &{FRC20TreasuryReceiver})
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
        fun burnAndSend(_ ins: &Fixes.Inscription, recipient: &{FRC20TreasuryReceiver}) {
            pre {
                ins.isExtractable(): "Inscription is not extractable"
            }
            post {
                ins.isExtracted(): "Inscription is not extracted"
            }
            let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
            assert(
                self.isTickerBurnable(tick),
                message: "The token is not burnable by the system burner."
            )
            // burn the tokens
            let frc20Indexer = FRC20Indexer.getIndexer()
            let flowVault <- frc20Indexer.burnFromTreasury(ins: ins)
            recipient.depositFlowToken(<- flowVault)
        }
    }

    /// Interface for the FRC20 Converter
    ///
    access(all) resource interface IFRC20Converter {

    }

    /// FRC20 Converter
    ///
    access(all) resource FTConverter: IFRC20Converter {

    }

    /** ------- Internal Methods ---- */

    /** ------- Public Methods ---- */

    /// Borrow the system burner reference
    ///
    access(all)
    view fun borrowSystemBurner(): &SystemBurner{IFRC20Burner} {
        return getAccount(self.account.address)
            .getCapability<&SystemBurner{IFRC20Burner}>(self.getSystemBurnerPublicPath())
            .borrow()
            ?? panic("Could not borrow the SystemBurner reference")
    }

    /// Create the FRC20 Converter
    ///
    access(all)
    fun createConverter(): @FTConverter {
        return <- create FTConverter()
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
        self.account.save(<- create SystemBurner(), to: storagePath)
        // link the public path
        // @deprecated in Cadence 1.0
        self.account.link<&SystemBurner{IFRC20Burner}>(self.getSystemBurnerPublicPath(), target: storagePath)

        emit ContractInitialized()
    }
}
