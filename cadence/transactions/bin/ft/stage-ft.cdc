import "FungibleTokenManager"

transaction(key: String) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let ftAdmin = acct.storage
            .borrow<auth(FungibleTokenManager.Sudo) &FungibleTokenManager.Admin>(from: FungibleTokenManager.AdminStoragePath)
            ?? panic("Missing FungibleTokenManager.Admin")
        ftAdmin.stageChildrenContract(key: key)
    }
}
