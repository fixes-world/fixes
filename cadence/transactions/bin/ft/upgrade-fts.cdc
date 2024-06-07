import "FungibleTokenManager"

transaction() {
    prepare(acct: AuthAccount) {
        let ftAdmin = acct.borrow<&FungibleTokenManager.Admin>(from: FungibleTokenManager.AdminStoragePath)
            ?? panic("Missing FungibleTokenManager.Admin")
        ftAdmin.updateAllChildrenContracts()
    }
}
