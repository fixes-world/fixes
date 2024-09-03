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
    let semiNFTCol: auth(NonFungibleToken.Withdraw, NonFungibleToken.Update) &FRC20SemiNFT.Collection

    prepare(signer: auth(Storage, Capabilities) &Account) {
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
        if acct.storage.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.storage.save(<- FRC20SemiNFT.createEmptyCollection(nftType: Type<@FRC20SemiNFT.NFT>()), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        if acct
            .capabilities.get<&FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20SemiNFT.CollectionPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20SemiNFT.Collection>(
                    FRC20SemiNFT.CollectionStoragePath
                ),
                at: FRC20SemiNFT.CollectionPublicPath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Start -- FRC20 Delegator General Initialization -------------  */
        if acct.storage.borrow<&AnyResource>(from: FRC20Staking.DelegatorStoragePath) == nil {
            let cap = acct.capabilities.storage
                .issue<auth(NonFungibleToken.Withdraw, NonFungibleToken.Update) &FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionStoragePath)
            acct.storage.save(<- FRC20Staking.createDelegator(cap), to: FRC20Staking.DelegatorStoragePath)
        }

        if acct
            .capabilities.get<&FRC20Staking.Delegator>(FRC20Staking.DelegatorPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20Staking.DelegatorPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20Staking.Delegator>(
                    FRC20Staking.DelegatorStoragePath
                ),
                at: FRC20Staking.DelegatorPublicPath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        self.semiNFTCol = acct.storage
            .borrow<auth(NonFungibleToken.Withdraw, NonFungibleToken.Update) &FRC20SemiNFT.Collection>(from: FRC20SemiNFT.CollectionStoragePath)
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
