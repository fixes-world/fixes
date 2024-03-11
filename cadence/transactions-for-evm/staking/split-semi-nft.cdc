// Third Party Imports
import "NonFungibleToken"
import "MetadataViews"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20SemiNFT"
import "FRC20Staking"
import "FRC20StakingManager"
import "EVMAgent"

transaction(
    nftId: UInt64,
    percent: UFix64,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let semiNFTCol: &FRC20SemiNFT.Collection

    prepare(signer: AuthAccount) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "split-semi-nft(UInt64|UFix64)",
            params: [nftId.toString(), percent.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.save(<- FRC20SemiNFT.createEmptyCollection(), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        if acct
            .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20SemiNFT.CollectionPublicPath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPublicPath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
            // Link private path (will be deprecated in Cadence 1.0)
            acct.unlink(FRC20SemiNFT.CollectionPrivatePath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPrivatePath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Start -- FRC20 Delegator General Initialization -------------  */
        if acct.borrow<&AnyResource>(from: FRC20Staking.DelegatorStoragePath) == nil {
            let semiNFTColCap = acct
                .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPrivatePath)
            acct.save(<- FRC20Staking.createDelegator(semiNFTColCap), to: FRC20Staking.DelegatorStoragePath)
        }

        if acct
            .getCapability<&FRC20Staking.Delegator{FRC20Staking.DelegatorPublic}>(FRC20Staking.DelegatorPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20Staking.DelegatorPublicPath)
            acct.link<&FRC20Staking.Delegator{FRC20Staking.DelegatorPublic}>(
                FRC20Staking.DelegatorPublicPath,
                target: FRC20Staking.DelegatorStoragePath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        self.semiNFTCol = acct.borrow<&FRC20SemiNFT.Collection>(from: FRC20SemiNFT.CollectionStoragePath)
            ?? panic("Could not borrow a reference to the owner's collection")
    }

    pre {
        percent > 0.0 && percent < 1.0: "Percent must be between 0.0 and 1.0"
    }

    execute {
        let nftRef = self.semiNFTCol.borrowFRC20SemiNFT(id: nftId)
            ?? panic("Could not borrow a reference to the NFT with ID :".concat(nftId.toString()))

        let splittedNft <- nftRef.split(percent)
        self.semiNFTCol.deposit(token: <- splittedNft)
    }
}
