/**
> Author: Fixes Lab <https://github.com/fixes-world/>

# FGameMishal

This contract is used to define the basic game elements.
The basic elements of a Mishal Game will be defined here.

*/
import "Burner"
import "FungibleToken"
// Fixes Imports
import "Fixes"
import "FixesHeartbeat"

access(all) contract FGameMishal {
    // Entitlements for the Editor role
    access(all) entitlement Editor;
    // Entitlements for the Creator role (Like the creator of the game)
    access(all) entitlement Creator;
    // Entitlements for the Host role (Like the host of the game)
    access(all) entitlement Host;
    // Entitlements for the Player role (Like the player of the game)
    access(all) entitlement Player; // Not used for now

    // ----- Events -----

    access(all) event LibrarySettingChanged(_ library: Address, key: UInt8, value: Int64)
    access(all) event LibraryEntryAdded(_ library: Address, _ category: UInt8, _ uuid: UInt64, _ name: String, _ tags: [String])
    access(all) event LibraryEntryRemoved(_ library: Address, _ category: UInt8, _ uuid: UInt64)

    access(all) event UnitStatusApplied(_ unitUID: UInt64, _ attributes: Attributes, _ defence: Defence, _ potentiality: Potentiality)

    access(all) event EntryDeposited(_ library: Address, _ category: UInt8, _ uuid: UInt64, _ amount: UFix64, _ to: Address?, entryUUID: UInt64, collectionUUID: UInt64)
    access(all) event EntryWithdrawn(_ library: Address, _ category: UInt8, _ uuid: UInt64, _ amount: UFix64, _ from: Address?, entryUUID: UInt64, collectionUUID: UInt64)

    access(all) event CreatureItemEquipped(_ library: Address, _ item: String, _ owner: Address?, itemUUID: UInt64, uuid: UInt64)
    access(all) event CreatureItemUnequipped(_ library: Address, _ item: String, _ owner: Address?, itemUUID: UInt64, uuid: UInt64)

    access(all) event CreatureSettingUpdated(_ type: String, _ uuid: UInt64, _ setting: UInt8, _ value: Int64)
    access(all) event CreatureBioPromptAdded(_ owner: Address?, uuid: UInt64, _ prompt: String)

    access(all) event PawnPotentialityGained(_ owner: Address?, _ amount: UInt64, uuid: UInt64)
    access(all) event PawnPotentialityConsumed(_ owner: Address?, _ consume: UInt64, _ usable: UInt64, _ used: UInt64, uuid: UInt64)
    access(all) event PawnAttributeUpgraded(_ owner: Address?, _ type: UInt8, _ amount: UInt64, uuid: UInt64)
    access(all) event PawnAbilityCultivated(_ owner: Address?, _ ability: String, _ consume: UInt64, _ abilityUp: UInt64, uuid: UInt64)

    access(all) event PawnHealthReset(_ owner: Address?, _ strength: Int64, _ vitality: Int64, _ spirit: Int64, uuid: UInt64)
    access(all) event PawnHealthRecovered(_ owner: Address?, _ type: UInt8, _ amount: Int64, uuid: UInt64)
    access(all) event PawnHealthDamaged(_ owner: Address?, _ type: UInt8, _ amount: Int64, uuid: UInt64)

    // ----- Contract Level Variables -----

    // The counter variable for the library items
    access(all) let libraryItems: {Address: UInt64}

    access(all) let libraryStoragePath: StoragePath
    access(all) let libraryPublicPath: PublicPath

    // ----- Resources -----

    access(all) enum LibrarySettings: UInt8 {
        access(all) case INIT_POTENTIALITY
        access(all) case INIT_ATTRIBUTE_VALUE
        access(all) case INIT_DEFENCE_VALUE
    }

    access(all) enum AttributeType: UInt8 {
        access(all) case STRENGTH
        access(all) case VITALITY
        access(all) case SPIRIT
    }

    access(all) enum AttackType: UInt8 {
        access(all) case PHYSICAL
        access(all) case EROSION
        access(all) case OCCULT
        access(all) case TRUE_DAMAGE
    }

    access(all) enum DefenceType: UInt8 {
        access(all) case PHYSICAL // To defend physical damage
        access(all) case ENDURANCE // To defend erosion damage
        access(all) case RESISTANCE // To defend occult damage
    }

    access(all) enum LibraryCategory: UInt8 {
        access(all) case OBJECT
        access(all) case ITEM
        access(all) case ABILITY
        access(all) case SHAPE
        access(all) case FEATURE
        access(all) case CREATURE
    }

    access(all) enum EquipSlot: UInt8 {
        access(all) case WEAPONS // 武器
        access(all) case HEAD // 头饰
        access(all) case ARMOR // 盔甲
        access(all) case FEET // 鞋子
        access(all) case HARNESS // 马具
        access(all) case EARRINGS // 耳饰
        access(all) case NECK // 项链
        access(all) case RINGS // 戒指
        access(all) case WRISTS // 手镯
        access(all) case GLOVES // 手套
        access(all) case FOOTWEAR // 足饰
        access(all) case BELT // 腰饰
        access(all) case TAIL // 尾饰
        access(all) case SHAWL // 披肩
        access(all) case COAT // 服装
        access(all) case MAKEUP // 妆饰
        access(all) case ACCESSORY // 配饰
    }

    access(all) enum CreatureSettings: UInt8 {
        access(all) case GENDER
        access(all) case FORM
        access(all) case SIZE
        access(all) case MOVE_SPEED
        access(all) case PERCEPTION_RANGE
        access(all) case OCCUPY_RANGE
    }

    // The Public Library resource is used to store the settings of Mishal Game.
    access(all) resource Library {
        access(contract) let settings: {LibrarySettings: Int64}

        access(self) let objects: @{UInt64: Object}
        access(self) let items: @{UInt64: Item}
        access(self) let abilities: @{UInt64: Ability}
        access(self) let shapes: @{UInt64: Shape}
        access(self) let features: @{UInt64: Feature}
        access(self) let creatures: @{UInt64: Creature}
        access(self) let nameToUID: {LibraryCategory: {String: UInt64}}
        access(self) let tagToUIDs: {LibraryCategory: {String: [UInt64]}}

        init() {
            self.settings = {
                LibrarySettings.INIT_POTENTIALITY: 36,
                LibrarySettings.INIT_ATTRIBUTE_VALUE: 3,
                LibrarySettings.INIT_DEFENCE_VALUE: 0
            }
            self.objects <- {}
            self.items <- {}
            self.abilities <- {}
            self.shapes <- {}
            self.features <- {}
            self.creatures <- {}
            self.nameToUID = {}
            self.tagToUIDs = {}

            // initialize the nameToUID and tagToUIDs
            self.nameToUID[LibraryCategory.OBJECT] = {}
            self.nameToUID[LibraryCategory.ITEM] = {}
            self.nameToUID[LibraryCategory.ABILITY] = {}
            self.nameToUID[LibraryCategory.SHAPE] = {}
            self.nameToUID[LibraryCategory.FEATURE] = {}
            self.nameToUID[LibraryCategory.CREATURE] = {}

            self.tagToUIDs[LibraryCategory.OBJECT] = {}
            self.tagToUIDs[LibraryCategory.ITEM] = {}
            self.tagToUIDs[LibraryCategory.ABILITY] = {}
            self.tagToUIDs[LibraryCategory.SHAPE] = {}
            self.tagToUIDs[LibraryCategory.FEATURE] = {}
            self.tagToUIDs[LibraryCategory.CREATURE] = {}
        }

        access(Editor)
        fun setSetting(key: LibrarySettings, value: Int64) {
            self.settings[key] = value

            emit LibrarySettingChanged(self.owner?.address ?? panic("Owner not found"), key: key.rawValue, value: value)
        }

        access(Editor)
        fun addObject(object: @Object) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.OBJECT)[object.name] == nil:
                    "Object name already exists"
            }
            let uuid = object.uuid
            let name = object.name
            let tags = object.tags
            self.setNameAndTags(LibraryCategory.OBJECT, uuid, name, tags)

            self.objects[uuid] <-! object

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.OBJECT.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addItem(item: @Item) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.ITEM)[item.name] == nil:
                    "Item name already exists"
            }
            let uuid = item.uuid
            let name = item.name
            let tags = item.tags
            self.setNameAndTags(LibraryCategory.ITEM, uuid, name, tags)

            self.items[uuid] <-! item

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.ITEM.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addAbility(ability: @Ability) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.ABILITY)[ability.name] == nil:
                    "Ability name already exists"
            }
            let uuid = ability.uuid
            let name = ability.name
            let tags = ability.tags
            self.setNameAndTags(LibraryCategory.ABILITY, uuid, name, tags)

            self.abilities[uuid] <-! ability

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.ABILITY.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addShape(shape: @Shape) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.SHAPE)[shape.name] == nil:
                    "Shape name already exists"
            }
            let uuid = shape.uuid
            let name = shape.name
            let tags = shape.tags
            self.setNameAndTags(LibraryCategory.SHAPE, uuid, name, tags)

            self.shapes[uuid] <-! shape

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.SHAPE.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addFeature(feature: @Feature) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.FEATURE)[feature.name] == nil:
                    "Feature name already exists"
            }
            let uuid = feature.uuid
            let name = feature.name
            let tags = feature.tags
            self.setNameAndTags(LibraryCategory.FEATURE, uuid, name, tags)

            self.features[uuid] <-! feature

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.FEATURE.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addCreature(creature: @Creature) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.CREATURE)[creature.name] == nil:
                    "Creature name already exists"
            }
            let uuid = creature.uuid
            let name = creature.name
            let tags = creature.tags
            self.setNameAndTags(LibraryCategory.CREATURE, uuid, name, tags)

            self.creatures[uuid] <-! creature

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.CREATURE.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun removeEntry(_ category: LibraryCategory, _ uuid: UInt64) {
            self.removeNameAndTags(category, uuid)

            switch category {
                case LibraryCategory.OBJECT:
                    Burner.burn(<- self.objects.remove(key: uuid))
                case LibraryCategory.ITEM:
                    Burner.burn(<- self.items.remove(key: uuid))
                case LibraryCategory.ABILITY:
                    Burner.burn(<- self.abilities.remove(key: uuid))
                case LibraryCategory.SHAPE:
                    Burner.burn(<- self.shapes.remove(key: uuid))
                case LibraryCategory.FEATURE:
                    Burner.burn(<- self.features.remove(key: uuid))
                case LibraryCategory.CREATURE:
                    Burner.burn(<- self.creatures.remove(key: uuid))
                default:
                    panic("Invalid category")
            }

            emit LibraryEntryRemoved(
                self.owner?.address ?? panic("Owner not found"),
                category.rawValue,
                uuid
            )
        }

        // -------- Public Functions --------

        access(all) view
        fun borrowObject(_ uuid: UInt64): &Object? {
            return &self.objects[uuid]
        }

        access(all) view
        fun borrowObjectByName(_ name: String): &Object? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.OBJECT)[name] {
                return self.borrowObject(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowItem(_ uuid: UInt64): &Item? {
            return &self.items[uuid]
        }

        access(all) view
        fun borrowItemByName(_ name: String): &Item? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.ITEM)[name] {
                return self.borrowItem(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowAbility(_ uuid: UInt64): &Ability? {
            return &self.abilities[uuid]
        }

        access(all) view
        fun borrowAbilityByName(_ name: String): &Ability? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.ABILITY)[name] {
                return self.borrowAbility(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowShape(_ uuid: UInt64): &Shape? {
            return &self.shapes[uuid]
        }

        access(all) view
        fun borrowShapeByName(_ name: String): &Shape? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.SHAPE)[name] {
                return self.borrowShape(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowFeature(_ uuid: UInt64): &Feature? {
            return &self.features[uuid]
        }

        access(all) view
        fun borrowFeatureByName(_ name: String): &Feature? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.FEATURE)[name] {
                return self.borrowFeature(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowCreature(_ uuid: UInt64): &Creature? {
            return &self.creatures[uuid]
        }

        access(all) view
        fun borrowCreatureByName(_ name: String): &Creature? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.CREATURE)[name] {
                return self.borrowCreature(uuid)
            }
            return nil
        }

        access(self) view
        fun borrowNameToUIDDictionary(_ category: LibraryCategory): auth(Mutate) &{String: UInt64} {
            return &self.nameToUID[category] as auth(Mutate) &{String: UInt64}?
                ?? panic("Name to UID dictionary not found")
        }

        access(self) view
        fun borrowTagToUIDsDictionary(_ category: LibraryCategory): auth(Mutate) &{String: [UInt64]} {
            return &self.tagToUIDs[category] as auth(Mutate) &{String: [UInt64]}?
                ?? panic("Tag to UID dictionary not found")
        }

        access(self) view
        fun getTagUIDs(_ category: LibraryCategory, _ tag: String): [UInt64] {
            let tagToUIDs = self.borrowTagToUIDsDictionary(category)
            if let uids = tagToUIDs[tag] {
                return *uids
            }
            return []
        }

        // -------- Private Functions --------

        access(self)
        fun borrowNamable(_ category: LibraryCategory, _ uuid: UInt64): &{Nameable}? {
            switch category {
                case LibraryCategory.OBJECT:
                    return self.borrowObject(uuid)
                case LibraryCategory.ITEM:
                    return self.borrowItem(uuid)
                case LibraryCategory.ABILITY:
                    return self.borrowAbility(uuid)
                case LibraryCategory.SHAPE:
                    return self.borrowShape(uuid)
                case LibraryCategory.FEATURE:
                    return self.borrowFeature(uuid)
                case LibraryCategory.CREATURE:
                    return self.borrowCreature(uuid)
                default:
                    return nil
            }
        }

        access(self)
        fun setNameAndTags(_ category: LibraryCategory, _ uuid: UInt64, _ name: String, _ tags: [String]) {
            let nameToUID = self.borrowNameToUIDDictionary(category)
            let tagToUIDs = self.borrowTagToUIDsDictionary(category)

            // set the name to the uuid
            nameToUID[name] = uuid

            // set the tags to the uuid
            for tag in tags {
                if tagToUIDs[tag] == nil {
                    tagToUIDs[tag] = [uuid]
                } else {
                    tagToUIDs[tag]!.append(uuid)
                }
            }
        }

        access(self)
        fun removeNameAndTags(_ category: LibraryCategory, _ uuid: UInt64) {
            let nameToUID = self.borrowNameToUIDDictionary(category)
            let tagToUIDs = self.borrowTagToUIDsDictionary(category)

            if let namable = self.borrowNamable(category, uuid) {
                let _ = nameToUID.remove(key: namable.name)
                for tag in namable.tags {
                    if let tagArr = tagToUIDs[tag] {
                        if let idIndex = tagArr.firstIndex(of: uuid) {
                            let _ = tagArr.remove(at: idIndex)
                        }
                    }
                }
            }
        }
    }

    // ------------ Library Entities ------------

    access(all) struct interface Copyable {
        access(all) fun copy(): {Copyable}
    }

    access(all) struct Potentiality: Copyable {
        access(all) var initial: Int64

        view init(
            initial: Int64,
        ) {
            self.initial = initial
        }

        access(all) fun copy(): {Copyable} { return self }

        access(contract)
        fun add(_ amount: Int64) {
            post {
                self.initial >= 0: "Initial potentiality cannot be negative"
            }
            self.initial = self.initial + amount
        }
    }

    // The basic attributes of a character
    access(all) struct Attributes: Copyable {
        access(all) var strength: Int64
        access(all) var vitality: Int64
        access(all) var spirit: Int64

        view init(strength: Int64, vitality: Int64, spirit: Int64) {
            self.strength = strength
            self.vitality = vitality
            self.spirit = spirit
        }

        access(all) fun copy(): {Copyable} { return self }

        access(all) view
        fun getValue(_ type: AttributeType): Int64 {
            switch type {
                case AttributeType.STRENGTH:
                    return self.strength
                case AttributeType.VITALITY:
                    return self.vitality
                case AttributeType.SPIRIT:
                    return self.spirit
                default:
                    return 0
            }
        }

        /// This method will not check if the value is negative
        access(Host)
        fun setValue(_ type: AttributeType, _ value: Int64) {
            switch type {
                case AttributeType.STRENGTH:
                    self.strength = value
                case AttributeType.VITALITY:
                    self.vitality = value
                case AttributeType.SPIRIT:
                    self.spirit = value
                default:
                    panic("Invalid attribute type")
            }
        }

        // For this method, the final value cannot be negative
        access(Host)
        fun addValue(_ type: AttributeType, _ value: Int64) {
            post {
                self.strength >= 0: "Strength cannot be negative"
                self.vitality >= 0: "Vitality cannot be negative"
                self.spirit >= 0: "Spirit cannot be negative"
            }
            switch type {
                case AttributeType.STRENGTH:
                    self.strength = self.strength + value
                    if self.strength < 0 {
                        self.strength = 0
                    }
                case AttributeType.VITALITY:
                    self.vitality = self.vitality + value
                    if self.vitality < 0 {
                        self.vitality = 0
                    }
                case AttributeType.SPIRIT:
                    self.spirit = self.spirit + value
                    if self.spirit < 0 {
                        self.spirit = 0
                    }
                default:
                    panic("Invalid attribute type")
            }
        }
    }

    access(all) struct Defence: Copyable {
        access(all) var physical: Int64
        access(all) var endurance: Int64
        access(all) var resistance: Int64

        view init(physical: Int64, endurance: Int64, resistance: Int64) {
            self.physical = physical
            self.endurance = endurance
            self.resistance = resistance
        }

        access(all) fun copy(): {Copyable} { return self }

        access(all) view
        fun getValue(_ type: DefenceType): Int64 {
            switch type {
                case DefenceType.PHYSICAL:
                    return self.physical
                case DefenceType.ENDURANCE:
                    return self.endurance
                case DefenceType.RESISTANCE:
                    return self.resistance
                default:
                    return 0
            }
        }

        access(all) view
        fun getDefenceFrom(_ type: AttackType): Int64 {
            switch type {
                case AttackType.PHYSICAL:
                    return self.physical
                case AttackType.EROSION:
                    return self.endurance
                case AttackType.OCCULT:
                    return self.resistance
                case AttackType.TRUE_DAMAGE:
                    return 0
                default:
                    return 0
            }
        }

        // This method will not check if the value is negative
        access(Host)
        fun setValue(_ type: DefenceType, _ value: Int64) {
            switch type {
                case DefenceType.PHYSICAL:
                    self.physical = value
                case DefenceType.ENDURANCE:
                    self.endurance = value
                case DefenceType.RESISTANCE:
                    self.resistance = value
                default:
                    panic("Invalid defence type")
            }
        }
    }

    // The status of the unit
    access(all) struct UnitStatus: Copyable {
        access(all) var attributes: Attributes
        access(all) var defence: Defence
        access(all) var potentiality: Potentiality

        access(all) var slotsOccupied: {EquipSlot: [String]}

        view init(
            attributes: Attributes,
            defence: Defence,
            potentiality: Potentiality
        ) {
            self.attributes = attributes
            self.defence = defence
            self.potentiality = potentiality
            self.slotsOccupied = {}
        }

        access(all) fun copy(): {Copyable} { return self }

        access(contract)
        fun setAttributes(_ attributes: Attributes) {
            self.attributes = attributes
        }

        access(contract)
        fun setDefence(_ defence: Defence) {
            self.defence = defence
        }

        access(contract)
        fun setPotentiality(_ potentiality: Potentiality) {
            self.potentiality = potentiality
        }

        access(contract) view
        fun borrowWritableSlotsOccupied(): auth(Mutate) &{EquipSlot: [String]} {
            return &self.slotsOccupied
        }

        access(all) view
        fun borrowAttributes(): &Attributes {
            return &self.attributes
        }

        access(all) view
        fun borrowDefence(): &Defence {
            return &self.defence
        }

        access(all) view
        fun borrowPotentiality(): &Potentiality {
            return &self.potentiality
        }
    }

    access(all) resource interface Nameable {
        access(all) let name: String
        access(all) let tags: [String]

        access(all) view
        fun hasAnyTag(): Bool {
            return self.tags.length > 0
        }

        access(all) view
        fun withTag(_ tag: String): Bool {
            return self.tags.contains(tag)
        }
    }

    access(all) resource interface ValueCarrier {
        // The value of the item
        access(all) var value: UFix64?

        access(all) view
        fun hasValue(): Bool {
            return self.value != nil
        }

        access(Host)
        fun setValue(value: UFix64) {
            self.value = value
        }

        access(Host)
        fun addValue(value: UFix64) {
            post {
                (self.value ?? 0.0) >= 0.0: "Value cannot be negative"
            }
            self.value = (self.value ?? 0.0) + value
        }
    }

    access(all) resource interface EffectsCarrier {
        access(all) let effects: [String]

        access(all) view
        fun hasEffects(): Bool {
            return self.effects.length > 0
        }

        access(Host)
        fun addEffect(effect: String) {
            self.effects.append(effect)
        }

        access(Host)
        fun removeEffect(effect: String) {
            if let index = self.effects.firstIndex(of: effect) {
                let _ = self.effects.remove(at: index)
            }
        }
    }

    // The AttributeCarrier resource interface is used to get the attributes of the entry.
    access(all) resource interface AttributeCarrier {
        access(all) view fun borrowAttributes(): &Attributes?

        access(all) view fun hasAttributes(): Bool {
            return self.borrowAttributes() != nil
        }

        access(all) view fun getAttrStr(): Int64 {
            return self.borrowAttributes()?.strength ?? 0
        }

        access(all) view fun getAttrVit(): Int64 {
            return self.borrowAttributes()?.vitality ?? 0
        }

        access(all) view fun getAttrSpir(): Int64 {
            return self.borrowAttributes()?.spirit ?? 0
        }
    }

    // The DefenceCarrier resource interface is used to get the defence of the entry.
    access(all) resource interface DefenceCarrier {
        access(all) view fun borrowDefence(): &Defence?

        access(all) view fun hasDefence(): Bool {
            return self.borrowDefence() != nil
        }

        access(all) view fun getDefPhys(): Int64 {
            return self.borrowDefence()?.physical ?? 0
        }

        access(all) view fun getDefEnd(): Int64 {
            return self.borrowDefence()?.endurance ?? 0
        }

        access(all) view fun getDefRes(): Int64 {
            return self.borrowDefence()?.resistance ?? 0
        }
    }

    // The PotentialityCarrier resource interface is used to get the potentiality of the entry.
    access(all) resource interface PotentialityCarrier {
        access(all) view fun borrowPotentiality(): &Potentiality?

        access(all) view fun hasPotentiality(): Bool {
            return self.borrowPotentiality() != nil
        }

        access(all) view fun getInitialPotentiality(): Int64 {
            return self.borrowPotentiality()?.initial ?? 0
        }
    }

    // The OptionalStatusCarrier resource interface is used to get the optional status of the entry.
    access(all) resource interface OptionalStatusCarrier: AttributeCarrier, DefenceCarrier, PotentialityCarrier {
        access(all) let attributes: Attributes?
        access(all) let defence: Defence?
        access(all) let potentiality: Potentiality?

        access(all) view fun borrowAttributes(): &Attributes? {
            return &self.attributes
        }

        access(all) view fun borrowDefence(): &Defence? {
            return &self.defence
        }

        access(all) view fun borrowPotentiality(): &Potentiality? {
            return &self.potentiality
        }
    }

    // The LiveUnitStatusCarrier resource interface is used to get the live status of the entry.
    access(all) resource interface LiveUnitStatusCarrier: AttributeCarrier, DefenceCarrier, PotentialityCarrier {
        access(all) view fun borrowStatus(): &UnitStatus

        access(all) view fun borrowAttributes(): &Attributes? {
            return self.borrowStatus().borrowAttributes()
        }

        access(all) view fun borrowDefence(): &Defence? {
            return self.borrowStatus().borrowDefence()
        }

        access(all) view fun borrowPotentiality(): &Potentiality? {
            return self.borrowStatus().borrowPotentiality()
        }
    }

    access(all) resource interface ComposableUnitStatusCarrier: LiveUnitStatusCarrier {
        access(all) view fun borrowStatus(): &UnitStatus

        access(all) fun borrowAttributesElements(): [&Attributes]
        access(all) fun borrowDefenceElements(): [&Defence]
        access(all) fun borrowPotentialityElements(): [&Potentiality]

        access(contract)
        fun applyStatus(_ isLast: Bool) {
            // during initializing, we don't need to apply the status if it's not the last one
            if self.owner == nil && !isLast {
                return
            }

            let status = self.borrowStatus()

            // Calculate the new attributes of the unit
            let attributes = self.borrowAttributesElements()
            let newAttributes = Attributes(strength: 0, vitality: 0, spirit: 0)
            for attribute in attributes {
                newAttributes.setValue(AttributeType.STRENGTH, newAttributes.strength + attribute.strength)
                newAttributes.setValue(AttributeType.VITALITY, newAttributes.vitality + attribute.vitality)
                newAttributes.setValue(AttributeType.SPIRIT, newAttributes.spirit + attribute.spirit)
            }
            status.setAttributes(newAttributes)

            // Calculate the new defence of the unit
            let defence = self.borrowDefenceElements()
            let newDefence = Defence(physical: 0, endurance: 0, resistance: 0)
            for one in defence {
                newDefence.setValue(DefenceType.PHYSICAL, newDefence.physical + one.physical)
                newDefence.setValue(DefenceType.ENDURANCE, newDefence.endurance + one.endurance)
                newDefence.setValue(DefenceType.RESISTANCE, newDefence.resistance + one.resistance)
            }
            status.setDefence(newDefence)

            // Calculate the new potentiality of the unit
            let potentiality = self.borrowPotentialityElements()
            let newPotentiality = Potentiality(initial: 0)
            for one in potentiality {
                newPotentiality.add(one.initial)
            }
            status.setPotentiality(newPotentiality)

            // Emit the event
            emit UnitStatusApplied(
                self.uuid,
                status.attributes.copy() as! Attributes,
                status.defence.copy() as! Defence,
                status.potentiality.copy() as! Potentiality
            )
        }
    }

    // The EntryIdentifier resource is used to identify the entry.
    access(all) struct EntryIdentifier {
        access(all) let library: Address
        access(all) let category: LibraryCategory
        access(all) let id: UInt64

        view init(library: Address, category: LibraryCategory, id: UInt64) {
            pre {
                FGameMishal.borrowLibrary(library) != nil: "It should be a valid library."
            }
            self.library = library
            self.category = category
            self.id = id
        }

        access(all) view
        fun getStringID(): String {
            return self.library.toString().concat("-").concat(self.category.rawValue.toString()).concat("-").concat(self.id.toString())
        }

        access(all) view
        fun clone(): EntryIdentifier {
            return self
        }

        access(all) view
        fun verify(_ type: LibraryCategory): Bool {
            if type != self.category {
                return false
            }
            switch self.category {
                case LibraryCategory.OBJECT:
                    return self.borrowObject() != nil
                case LibraryCategory.ITEM:
                    return self.borrowItem() != nil
                case LibraryCategory.ABILITY:
                    return self.borrowAbility() != nil
                case LibraryCategory.SHAPE:
                    return self.borrowShape() != nil
                case LibraryCategory.FEATURE:
                    return self.borrowFeature() != nil
                case LibraryCategory.CREATURE:
                    return self.borrowCreature() != nil
                default:
                    return false
            }
        }

        access(all) view
        fun borrowObject(): &Object? {
            if self.category == LibraryCategory.OBJECT {
                return self.borrowLibrary().borrowObject(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowItem(): &Item? {
            if self.category == LibraryCategory.ITEM {
                return self.borrowLibrary().borrowItem(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowAbility(): &Ability? {
            if self.category == LibraryCategory.ABILITY {
                return self.borrowLibrary().borrowAbility(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowShape(): &Shape? {
            if self.category == LibraryCategory.SHAPE {
                return self.borrowLibrary().borrowShape(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowFeature(): &Feature? {
            if self.category == LibraryCategory.FEATURE {
                return self.borrowLibrary().borrowFeature(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowCreature(): &Creature? {
            if self.category == LibraryCategory.CREATURE {
                return self.borrowLibrary().borrowCreature(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowLibrary(): &Library {
            return FGameMishal.borrowLibrary(self.library) ?? panic("Library not found")
        }
    }

    // The FungibleEntry resource is used to store the fungible entry.
    access(all) resource FungibleEntry: FungibleToken.Vault {
        access(all) let identifier: EntryIdentifier
        access(all) var balance: UFix64

        view init(identifier: EntryIdentifier, amount: UFix64) {
            self.identifier = identifier
            self.balance = amount
        }

        access(all) view fun getCount(): UInt64 {
            return UInt64(self.balance)
        }

        access(all) view fun getViews(): [Type] {
            return []
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }

        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }

        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @FungibleEntry {
            self.balance = self.balance - amount
            return <-create FungibleEntry(identifier: self.identifier, amount: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @FungibleEntry
            self.balance = self.balance + vault.balance
            destroy vault
        }

        access(all) fun createEmptyVault(): @FungibleEntry {
            return <-create FungibleEntry(identifier: self.identifier, amount: 0.0)
        }
    }

    // The EntryContainer resource interface is used to borrow the entry by ID.
    access(all) resource interface EntryContainer {
        access(all) view
        fun borrowEntryByID(_ id: String): &FungibleEntry?

        access(Creator)
        fun deposit(entry: @FungibleEntry)

        access(Creator)
        fun withdraw(_ id: String, amount: UFix64?): @FungibleEntry
    }

    // Check if the entry is uniqueness
    access(all) view
    fun isEntryUniqueness(_ category: LibraryCategory): Bool {
        switch category {
            case LibraryCategory.OBJECT:
                return false
            case LibraryCategory.ITEM:
                return false
            default:
                return true
        }
    }

    // The EntryCollection resource is used to store the entries.
    access(all) resource EntryCollection: EntryContainer {
        access(all) let entries: @{String: FungibleEntry}
        access(all) let categories: {LibraryCategory: [String]}

        view init() {
            self.entries <- {}
            self.categories = {}
        }

        access(all) view fun getLength(): Int {
            return self.entries.length
        }

        access(all) view fun getLengthByCategory(_ category: LibraryCategory): Int {
            return self.categories[category]?.length ?? 0
        }

        access(all)
        fun getEntryIdentifiers(_ category: LibraryCategory?): [EntryIdentifier] {
            let ret: [EntryIdentifier] = []
            let keys = category == nil ? self.entries.keys : self.getKeysByCategory(category!)
            for id in keys {
                if let ref = self.borrowEntryByID(id) {
                    ret.append(ref.identifier.clone())
                }
            }
            return ret
        }

        access(all)
        fun borrowEntries(_ category: LibraryCategory?): [&FungibleEntry] {
            let ret: [&FungibleEntry] = []
            let keys = category == nil ? self.entries.keys : self.getKeysByCategory(category!)
            for id in keys {
                if let ref = self.borrowEntryByID(id) {
                    ret.append(ref)
                }
            }
            return ret
        }

        access(all) view
        fun getKeysByCategory(_ category: LibraryCategory): [String] {
            return self.categories[category] ?? []
        }

        access(all) view
        fun borrowEntryByID(_ id: String): &FungibleEntry? {
            return &self.entries[id]
        }

        access(Creator)
        fun deposit(entry: @FungibleEntry) {
            pre {
                emit EntryDeposited(
                    entry.identifier.library,
                    entry.identifier.category.rawValue,
                    entry.identifier.id,
                    entry.balance,
                    self.owner?.address,
                    entryUUID: entry.uuid,
                    collectionUUID: self.uuid
                )
            }
            let uid = entry.identifier.getStringID()

            if FGameMishal.isEntryUniqueness(entry.identifier.category) {
                assert(entry.balance == 1.0 && self.entries[uid] == nil, message: "Non-fungible entry must have a balance of 1.0")
            }

            if let oldRef = self.borrowEntryByID(uid) {
                oldRef.deposit(from: <- entry)
            } else {
                self.entries[uid] <-! entry
            }
        }

        access(Creator)
        fun withdraw(_ id: String, amount: UFix64?): @FungibleEntry {
            post {
                result.identifier.getStringID() == id: "The ID of the withdrawn token must be the same as the requested ID"
                emit EntryWithdrawn(
                    result.identifier.library,
                    result.identifier.category.rawValue,
                    result.identifier.id,
                    result.balance,
                    self.owner?.address,
                    entryUUID: result.uuid,
                    collectionUUID: self.uuid
                )
            }
            let ref = self.borrowEntryByID(id)
                ?? panic("EntryCollection.withdraw: Could not withdraw an entry with ID ".concat(id).concat(". Check if the entry exists."))
            if FGameMishal.isEntryUniqueness(ref.identifier.category) {
                assert(amount == nil, message: "Non-fungible entry cannot have an amount")
                return <- self.entries.remove(key: id)!
            } else {
                assert(amount != nil, message: "Fungible entry must have an amount")
                assert(
                    ref.isAvailableToWithdraw(amount: amount!),
                    message: "EntryCollection.withdraw: The entry is not available to withdraw, amount: "
                        .concat(amount!.toString())
                        .concat(", available: ")
                        .concat(ref.balance.toString())
                )
                return <- ref.withdraw(amount: amount!)
            }
        }

        access(Host) view
        fun borrowEditableEntry(_ id: String): auth(FungibleToken.Withdraw) &FungibleEntry? {
            return &self.entries[id]
        }
    }

    // The Object resource represents a static, non-playable object in the game
    access(all) resource Object: DefenceCarrier, ValueCarrier, Nameable {
        access(all) let name: String
        access(all) let tags: [String]
        // The defence of the character
        access(all) let defence: Defence
        // The value of the object
        access(all) var value: UFix64?

        view init(
            name: String,
            tags: [String],
            defence: Defence,
            value: UFix64?
        ) {
            self.name = name
            self.tags = tags
            self.defence = defence
            self.value = value
        }

        access(all) view fun borrowDefence(): &Defence? {
            return &self.defence as &Defence
        }
    }

    access(all) resource Item: OptionalStatusCarrier, ValueCarrier, EffectsCarrier, Nameable {
        access(all) let name: String
        access(all) let tags: [String]
        // The value of the item
        access(all) var value: UFix64?
        // Main attributes of the character
        access(all) let attributes: Attributes?
        // The defence of the character
        access(all) let defence: Defence?
        // The potentiality of the item
        access(all) let potentiality: Potentiality?
        // The effects of the item
        access(all) let effects: [String]
        // The slots occupied by the item
        access(all) let slotsOccupied: {EquipSlot: UInt8}
        // The slots provided by the item
        access(all) let slotsProvided: {EquipSlot: UInt8}

        view init(
            name: String,
            tags: [String],
            value: UFix64?,
            attributes: Attributes?,
            defence: Defence?,
            potentiality: Potentiality?,
            effects: [String],
            slotsOccupied: {EquipSlot: UInt8},
            slotsProvided: {EquipSlot: UInt8},
        ) {
            self.name = name
            self.tags = tags
            self.value = value
            self.attributes = attributes
            self.defence = defence
            self.potentiality = potentiality
            self.effects = effects
            self.slotsOccupied = slotsOccupied
            self.slotsProvided = slotsProvided
        }

        access(all) view
        fun isEquippable(): Bool {
            return self.slotsOccupied.length > 0
        }

        access(all) view
        fun isProvidedSlots(): Bool {
            return self.slotsProvided.length > 0
        }
    }

    access(all) resource Ability: AttributeCarrier, EffectsCarrier, Nameable {
        access(all) let name: String
        access(all) let tags: [String]
        access(all) let level: UInt64
        access(all) let occupy: AttributeType?
        access(all) let effects: [String]
        access(all) let attributes: Attributes?

        view init(
            level: UInt64,
            name: String,
            tags: [String],
            occupy: AttributeType?,
            effects: [String],
            attributes: Attributes?,
        ) {
            self.name = name
            self.tags = tags
            self.level = level
            self.occupy = occupy
            self.effects = effects
            self.attributes = attributes
        }

        access(all) view fun borrowAttributes(): &Attributes? {
            return &self.attributes
        }
    }

    // The CreatureSettingsCarrier resource interface is used to get the settings of the creature.
    access(all) resource interface CreatureSettingsCarrier {
        access(contract) view
        fun borrowWritableSettings(): auth(Mutate) &{CreatureSettings: Int64}

        access(all) view
        fun getSetting(_ setting: CreatureSettings): Int64? {
            let settings = self.borrowWritableSettings()
            return settings[setting]
        }

        access(all) view
        fun hasSettings(): Bool {
            let settings = self.borrowWritableSettings()
            return settings.length > 0
        }

        access(Host)
        fun updateSetting(_ setting: CreatureSettings, _ value: Int64) {
            let settings = self.borrowWritableSettings()
            settings[setting] = value

            emit CreatureSettingUpdated(
                self.getType().identifier,
                self.uuid,
                setting.rawValue,
                value
            )
        }
    }

    access(all) resource interface SettingsUnit: CreatureSettingsCarrier {
        access(all) let settings: {CreatureSettings: Int64}

        access(contract) view
        fun borrowWritableSettings(): auth(Mutate) &{CreatureSettings: Int64} {
            return &self.settings
        }
    }

    access(all) resource Shape: SettingsUnit, Nameable {
        access(all) let name: String
        access(all) let tags: [String]
        access(all) let settings: {CreatureSettings: Int64}
        access(all) let slotsAvailable: {EquipSlot: UInt8}

        view init(
            name: String,
            tags: [String],
            bodySize: Int64,
            occupyRange: Int64,
            moveSpeed: Int64,
            perceptionRange: Int64,
            slotsAvailable: {EquipSlot: UInt8 }
        ) {
            self.name = name
            self.tags = tags
            self.settings = {}
            self.slotsAvailable = slotsAvailable

            self.settings[CreatureSettings.SIZE] = bodySize
            self.settings[CreatureSettings.MOVE_SPEED] = moveSpeed
            self.settings[CreatureSettings.PERCEPTION_RANGE] = perceptionRange
            self.settings[CreatureSettings.OCCUPY_RANGE] = occupyRange
        }
    }

    // The ShapeCarrier resource interface is used to get the shape of the creature.
    access(all) resource interface ShapeCarrier: CreatureSettingsCarrier, EntryContainer {
        access(all) view fun getShapeIdentifier(): EntryIdentifier?

        access(all) view
        fun borrowShape(): &Shape? {
            if let shape = self.getShapeIdentifier() {
                return shape.borrowShape()
            }
            return nil
        }

        access(all) view
        fun hasShape(): Bool {
            return self.getShapeIdentifier() != nil
        }

        access(all) view
        fun getGender(): Int64? {
            let settings = self.borrowWritableSettings()
            if let gender = settings[CreatureSettings.GENDER] {
                return gender
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.GENDER)
            }
            return nil
        }

        access(all) view
        fun getForm(): Int64? {
            let settings = self.borrowWritableSettings()
            if let form = settings[CreatureSettings.FORM] {
                return form
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.FORM)
            }
            return nil
        }

        access(all) view
        fun getSize(): Int64? {
            let settings = self.borrowWritableSettings()
            if let size = settings[CreatureSettings.SIZE] {
                return size
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.SIZE)
            }
            return nil
        }

        access(all) view
        fun getMoveSpeed(): Int64? {
            let settings = self.borrowWritableSettings()
            if let moveSpeed = settings[CreatureSettings.MOVE_SPEED] {
                return moveSpeed
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.MOVE_SPEED)
            }
            return nil
        }

        access(all) view
        fun getPerceptionRange(): Int64? {
            let settings = self.borrowWritableSettings()
            if let perceptionRange = settings[CreatureSettings.PERCEPTION_RANGE] {
                return perceptionRange
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.PERCEPTION_RANGE)
            }
            return nil
        }

        access(all) view
        fun getOccupyRange(): Int64? {
            let settings = self.borrowWritableSettings()
            if let occupyRange = settings[CreatureSettings.OCCUPY_RANGE] {
                return occupyRange
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.OCCUPY_RANGE)
            }
            return nil
        }

        // --- Gameplay Methods ---

        access(Host)
        fun applyShape(_ shape: @FungibleEntry) {
            pre {
                shape.identifier.verify(LibraryCategory.SHAPE): "Shape identifier is invalid"
            }
        }
    }

    access(all) resource interface AbilitiesCarrier: EntryContainer {
        access(all) view fun getAbilitiesLength(): Int
        access(all) fun getAbilityIdentifiers(): [EntryIdentifier]

        access(all)
        fun borrowAbilities(): [&Ability] {
            return self.getAbilityIdentifiers()
                .map(view fun (_ x: EntryIdentifier): &Ability? {
                    return x.borrowAbility()
                })
                .filter(view fun (_ x: &Ability?): Bool {
                    return x != nil
                })
                .map(view fun (_ x: &Ability?): &Ability {
                    return x!
                })
        }

        access(all) view
        fun hasAbilities(): Bool {
            return self.getAbilitiesLength() > 0
        }

        // --- Gameplay Methods ---

        access(Host)
        fun gainAbility(_ ability: @FungibleEntry) {
            pre {
                ability.identifier.verify(LibraryCategory.ABILITY): "Ability identifier is invalid"
            }
        }

        access(Host)
        fun dropAbility(_ ability: EntryIdentifier): @FungibleEntry {
            post {
                result.identifier.getStringID() == ability.getStringID(): "The ID of the withdrawn token must be the same as the requested ID"
                result.identifier.verify(LibraryCategory.ABILITY): "Entry is not an ability"
            }
        }
    }

    access(all) resource interface ItemsCarrier: EntryContainer {
        access(all) view fun getItemsLength(): Int
        access(all) fun borrowItemEntries(): [&FungibleEntry]

        access(all)
        fun borrowItems(): [&Item] {
            let itemEntries = self.borrowItemEntries()

            let ret: [&Item] = []
            for itemEntry in itemEntries {
                if let item = itemEntry.identifier.borrowItem() {
                    var amount = itemEntry.getCount()
                    while amount > 0 {
                        ret.append(item)
                        amount = amount - 1
                    }
                }
            }
            return ret
        }

        access(all) view
        fun hasItems(): Bool {
            return self.getItemsLength() > 0
        }

        // --- Item Gameplay Methods ---

        access(Host)
        fun lootItem(_ entry: @FungibleEntry) {
            pre {
                entry.identifier.verify(LibraryCategory.ITEM): "Entry is not an item"
            }
        }

        access(Host)
        fun dropItem(_ item: EntryIdentifier, _ amount: UFix64?): @FungibleEntry {
            post {
                result.identifier.getStringID() == item.getStringID(): "The ID of the withdrawn token must be the same as the requested ID"
                result.identifier.verify(LibraryCategory.ITEM): "Entry is not an item"
            }
        }
    }

    // This is a resource that can borrow a writable collection
    access(all) resource interface CollectionContainer {
        access(contract)
        view fun borrowWritableCollection(): auth(Creator, Host) &EntryCollection

        access(all) view
        fun borrowReadonlyCollection(): &EntryCollection {
            return self.borrowWritableCollection()
        }
    }

    access(all) resource interface UnitCollectionBaseCarrier: AbilitiesCarrier, ItemsCarrier, ShapeCarrier, CollectionContainer {

        // --- Implement EntryContainer ---

        access(all) view fun borrowEntryByID(_ id: String): &FungibleEntry? {
            let collection = self.borrowReadonlyCollection()
            return collection.borrowEntryByID(id)
        }

        access(Creator)
        fun deposit(entry: @FungibleEntry) {
            self.borrowWritableCollection().deposit(entry: <-entry)
        }

        access(Creator)
        fun withdraw(_ id: String, amount: UFix64?): @FungibleEntry {
            return <- self.borrowWritableCollection().withdraw(id, amount: amount)
        }

        // --- Implement AbilitiesCarrier ---

        access(all) view fun getAbilitiesLength(): Int {
            let collection = self.borrowReadonlyCollection()
            return collection.getLengthByCategory(LibraryCategory.ABILITY)
        }

        access(all)
        fun getAbilityIdentifiers(): [EntryIdentifier] {
            let collection = self.borrowReadonlyCollection()
            return collection.getEntryIdentifiers(LibraryCategory.ABILITY)
        }

        // --- Implement ItemsCarrier ---

        access(all) view fun getItemsLength(): Int {
            let collection = self.borrowReadonlyCollection()
            return collection.getLengthByCategory(LibraryCategory.ITEM)
        }

        access(all)
        fun borrowItemEntries(): [&FungibleEntry] {
            let collection = self.borrowReadonlyCollection()
            return collection.borrowEntries(LibraryCategory.ITEM)
        }

        // --- Implement ShapeCarrier ---

        // Borrow the shape of the unit
        access(all) view
        fun getShapeIdentifier(): EntryIdentifier? {
            let collection = self.borrowReadonlyCollection()
            let shape = collection.getKeysByCategory(LibraryCategory.SHAPE)
            if shape.length > 0 {
                if let entry = collection.borrowEntryByID(shape[0]) {
                    return entry.identifier.clone()
                }
            }
            return nil
        }

        // Apply a shape to the unit
        access(Host)
        fun applyShape(_ shape: @FungibleEntry) {
            let collection = self.borrowReadonlyCollection()
            let shapes = collection.getKeysByCategory(LibraryCategory.SHAPE)

            // if the shape exists, remove it
            if shapes.length > 0 {
                for key in shapes {
                    Burner.burn(<-self.withdraw(key, amount: nil))
                }
            }

            // deposit the new shape
            self.deposit(entry: <-shape)
        }
    }

    // This is a resource inteface with a collection resource stored in it
    access(all) resource interface CollectionContainerUnit: CollectionContainer {
        access(all) let collection: @EntryCollection

        // ---- Implement UnitCollectionBaseCarrier ----

        access(contract) view
        fun borrowWritableCollection(): auth(Creator, Host) &EntryCollection {
            return &self.collection
        }
    }

    // This is a static collection unit that all resource are directly stored in it
    access(all) resource interface StaticCollectionUnit: UnitCollectionBaseCarrier, CollectionContainerUnit {
        // ---- Implement Item Gameplay Methods ----

        access(Host)
        fun lootItem(_ entry: @FungibleEntry) {
            self.deposit(entry: <-entry)
        }

        access(Host)
        fun dropItem(_ item: EntryIdentifier, _ amount: UFix64?): @FungibleEntry {
            return <- self.withdraw(item.getStringID(), amount: amount)
        }

        // ---- Implement Ability Gameplay Methods ----

        access(Host)
        fun gainAbility(_ ability: @FungibleEntry) {
            self.deposit(entry: <-ability)
        }

        access(Host)
        fun dropAbility(_ ability: EntryIdentifier): @FungibleEntry {
            return <- self.withdraw(ability.getStringID(), amount: nil)
        }
    }

    // The Feature resource is used to define the features of the entry.
    access(all) resource Feature: Nameable, OptionalStatusCarrier, StaticCollectionUnit, EffectsCarrier, SettingsUnit {
        access(all) let name: String
        access(all) let tags: [String]
        access(all) let attributes: Attributes?
        access(all) let defence: Defence?
        access(all) let potentiality: Potentiality?
        access(all) let collection: @EntryCollection
        access(all) let effects: [String]
        access(all) let settings: {CreatureSettings: Int64}

        init(
            name: String,
            tags: [String],
            attributes: Attributes?,
            defence: Defence?,
            potentiality: Potentiality?,
            shape: EntryIdentifier?,
            abilities: [EntryIdentifier],
            items: [EntryIdentifier],
            itemAmounts: {String: UFix64},
            effects: [String],
            settings: {CreatureSettings: Int64}
        ) {
            for abilityIdentifier in abilities {
                assert(abilityIdentifier.verify(LibraryCategory.ABILITY), message: "Ability identifier is invalid")
            }
            for itemIdentifier in items {
                assert(itemIdentifier.verify(LibraryCategory.ITEM), message: "Item identifier is invalid")
            }

            self.name = name
            self.tags = tags
            self.attributes = attributes
            self.defence = defence
            self.potentiality = potentiality
            self.effects = effects
            self.settings = settings
            self.collection <- create EntryCollection()

            // Set the entries for shape, abilities, items
            if shape != nil {
                self.applyShape(<-create FungibleEntry(identifier: shape!, amount: 1.0))
            }
            for abilityIdentifier in abilities {
                self.gainAbility(<-create FungibleEntry(identifier: abilityIdentifier, amount: 1.0))
            }
            if items.length > 0 {
                assert(itemAmounts.length == items.length, message: "Item amounts must be the same length as items")
                for itemIdentifier in items {
                    let id = itemIdentifier.getStringID()
                    let amount = itemAmounts[id] ?? 0.0
                    self.lootItem(<-create FungibleEntry(identifier: itemIdentifier, amount: amount))
                }
            }
        }
    }

    access(all) resource interface FeaturesCarrier: EntryContainer {
        access(all) view fun getFeaturesLength(): Int
        access(all) fun getFeatureIdentifiers(): [EntryIdentifier]

        access(all)
        fun borrowFeatures(): [&Feature] {
            return self.getFeatureIdentifiers()
                .map(view fun (_ x: EntryIdentifier): &Feature? {
                    return x.borrowFeature()
                })
                .filter(view fun (_ x: &Feature?): Bool {
                    return x != nil
                })
                .map(view fun (_ x: &Feature?): &Feature {
                    return x!
                })
        }

        access(all) view
        fun hasFeatures(): Bool {
            return self.getFeaturesLength() > 0
        }

        // ---- Implement Feature Gameplay Methods ----

        access(Host)
        fun applyFeature(_ feature: @FungibleEntry) {
            pre {
                feature.identifier.verify(LibraryCategory.FEATURE): "Feature identifier is invalid"
            }
        }
    }

    access(all) resource interface UnitCollectionCarrier: UnitCollectionBaseCarrier, FeaturesCarrier {
        access(all) view fun getFeaturesLength(): Int {
            let collection = self.borrowReadonlyCollection()
            return collection.getLengthByCategory(LibraryCategory.FEATURE)
        }

        access(all)
        fun getFeatureIdentifiers(): [EntryIdentifier] {
            let collection = self.borrowReadonlyCollection()
            return collection.getEntryIdentifiers(LibraryCategory.FEATURE)
        }
    }

    access(all) resource interface BioCarrier {
        access(Host) view fun borrowWritableBioPrompts(): auth(Mutate) &[String]

        access(all) view fun borrowBioPrompts(): &[String] { return self.borrowWritableBioPrompts() }

        access(Host)
        fun addBioPrompt(_ prompt: String) {
            let prompts = self.borrowWritableBioPrompts()
            prompts.append(prompt)

            emit CreatureBioPromptAdded(
                self.owner?.address,
                uuid: self.uuid,
                prompt
            )
        }
    }

    /// The EquipableUnit defines the core interface for a game unit, including status, equipment, and inventory logic.
    access(all) resource interface EquipableCreatureInterface: ComposableUnitStatusCarrier, AbilitiesCarrier, ItemsCarrier, FeaturesCarrier, ShapeCarrier {
        /// Returns a reference to the creature's own base attributes.
        ///
        /// @return Reference to the base Attributes struct.
        access(all) view fun borrowSelfAttributes(): &Attributes
        /// Returns a reference to the creature's own base defence.
        ///
        /// @return Reference to the base Defence struct.
        access(all) view fun borrowSelfDefence(): &Defence
        /// Returns a reference to the creature's own base potentiality.
        ///
        /// @return Reference to the base Potentiality struct.
        access(all) view fun borrowSelfPotentiality(): &Potentiality

        // ---- Implement ComposableUnitStatusCarrier ----

        /// Collects all attribute sources (self, features, abilities, equipped items) for status calculation.
        ///
        /// @return Array of references to all Attributes affecting the creature.
        access(all)
        fun borrowAttributesElements(): [&Attributes] {
            let ret: [&Attributes] = [self.borrowSelfAttributes()]

            // From Features
            let features = self.borrowFeatures()
            for feature in features {
                if feature.hasAttributes() {
                    if let attributes = feature.borrowAttributes() {
                        ret.append(attributes)
                    }
                }
            }

            // From Abilities
            let abilities = self.borrowAbilities()
            for ability in abilities {
                if ability.hasAttributes() {
                    if let attributes = ability.borrowAttributes() {
                        ret.append(attributes)
                    }
                }
            }

            // From Items
            let items = self.borrowEquippedItems()
            for item in items {
                if item.hasAttributes() {
                    if let attributes = item.borrowAttributes() {
                        ret.append(attributes)
                    }
                }
            }
            return ret
        }

        /// Collects all defence sources (self, features, equipped items) for status calculation.
        ///
        /// @return Array of references to all Defence affecting the creature.
        access(all)
        fun borrowDefenceElements(): [&Defence] {
            let ret: [&Defence] = [self.borrowSelfDefence()]

            // From Features
            let features = self.borrowFeatures()
            for feature in features {
                if feature.hasDefence() {
                    if let defence = feature.borrowDefence() {
                        ret.append(defence)
                    }
                }
            }

            // From Items
            let items = self.borrowEquippedItems()
            for item in items {
                if item.hasDefence() {
                    if let defence = item.borrowDefence() {
                        ret.append(defence)
                    }
                }
            }
            return ret
        }

        /// Collects all potentiality sources (self, features, equipped items) for status calculation.
        ///
        /// @return Array of references to all Potentiality affecting the creature.
        access(all)
        fun borrowPotentialityElements(): [&Potentiality] {
            let ret: [&Potentiality] = [self.borrowSelfPotentiality()]

            // From Features
            let features = self.borrowFeatures()
            for feature in features {
                if feature.hasPotentiality() {
                    if let potentiality = feature.borrowPotentiality() {
                        ret.append(potentiality)
                    }
                }
            }

            // From Items
            let items = self.borrowEquippedItems()
            for item in items {
                if item.hasPotentiality() {
                    if let potentiality = item.borrowPotentiality() {
                        ret.append(potentiality)
                    }
                }
            }
            return ret
        }

        // ---- Implement Item equipment info ----

        /// Returns all available equipment slots, including those from shape and equipped items.
        ///
        /// @return Dictionary of EquipSlot to available count.
        access(all)
        fun getSlotsAll(): {EquipSlot: UInt8} {
            let all: {EquipSlot: UInt8} = {}

            // All Slots = Shape Slots + Equipped Items Slots
            let shape = self.borrowShape() ?? panic("Shape not found")
            let shapeSlots = shape.slotsAvailable

            // Shape Slots
            for slot in shapeSlots.keys {
                all[slot] = shapeSlots[slot]!
            }

            // Equipped Items Slots
            let equippedItems = self.borrowEquippedItems()
            for item in equippedItems {
                if item.isProvidedSlots() {
                    let slots = item.slotsProvided
                    for slot in slots.keys {
                        if all[slot] == nil {
                            all[slot] = slots[slot]!
                        } else {
                            all[slot] = all[slot]! + slots[slot]!
                        }
                    }
                }
            }

            return all
        }

        /// Returns a mutable reference to the slots occupied by equipped items.
        ///
        /// @return Mutable reference to the EquipSlot mapping.
        access(Host) view fun borrowSlotsOccupied(): auth(Mutate) &{EquipSlot: [String]} {
            let status = self.borrowStatus()
            return status.borrowWritableSlotsOccupied()
        }

        /// Checks if a specific item is currently equipped.
        ///
        /// @param item The EntryIdentifier of the item to check.
        /// @return True if the item is equipped, false otherwise.
        access(all) view
        fun hasItemEquipped(_ item: EntryIdentifier): Bool {
            let slots = self.borrowSlotsOccupied()
            let id = item.getStringID()
            for slot in slots.keys {
                if let occupied = slots[slot] {
                    if occupied.contains(id) {
                        return true
                    }
                }
            }
            return false
        }

        /// Returns all currently equipped items as references.
        ///
        /// @return Array of references to equipped Item resources.
        access(all)
        fun borrowEquippedItems(): [&Item] {
            let ret: [&Item] = []

            let slots = self.borrowSlotsOccupied()
            // get unique ids
            let uniqueIds: [String] = []
            for slot in slots.keys {
                if let occupied = slots[slot] {
                    for id in occupied {
                        if !uniqueIds.contains(id) {
                            uniqueIds.append(id)
                        }
                    }
                }
            }
            // borrow the items
            for id in uniqueIds {
                if let entry = self.borrowEntryByID(id) {
                    if let item = entry.identifier.borrowItem() {
                        ret.append(item)
                    }
                }
            }
            return ret
        }

        /// Checks if an item can be equipped by the creature.
        ///
        /// @param item The EntryIdentifier of the item to check.
        /// @return True if the item can be equipped, false otherwise.
        access(all)
        fun isItemEquippable(_ item: EntryIdentifier): Bool {
            if let itemRef = item.borrowItem() {
                return self._isItemEquippable(itemRef)
            }
            return false
        }

        /// Equips an item to the creature, updating occupied slots and emitting an event.
        ///
        /// @param item The EntryIdentifier of the item to equip.
        access(Host)
        fun equipItem(_ item: EntryIdentifier) {
            let itemRef = item.borrowItem() ?? panic("Not Exists, Item: ".concat(item.getStringID()))
            let itemId = item.getStringID()
            assert(self.borrowEntryByID(itemId) != nil, message: "Not Found in Inventory, Item: ".concat(itemId))
            assert(!self.hasItemEquipped(item), message: "Already Equipped, Item: ".concat(itemId))
            assert(self._isItemEquippable(itemRef), message: "Not Equippable, Item: ".concat(itemId))

            let slots = self.borrowSlotsOccupied()
            let requiredSlots = itemRef.slotsOccupied
            for slot in requiredSlots.keys {
                if let occupied = slots[slot] {
                    let newOccupied: [String] = *occupied
                    var toOccupy = requiredSlots[slot]!
                    while toOccupy > 0 {
                        newOccupied.append(itemId)
                        toOccupy = toOccupy - 1
                    }
                    slots[slot] = newOccupied
                }
            }

            emit CreatureItemEquipped(
                item.library,
                itemId,
                self.owner?.address,
                itemUUID: itemRef.uuid,
                uuid: self.uuid
            )
        }

        /// Unequips an item from the creature, updating occupied slots and emitting an event.
        ///
        /// @param item The EntryIdentifier of the item to unequip.
        access(Host)
        fun unequipItem(_ item: EntryIdentifier) {
            let itemRef = item.borrowItem() ?? panic("Not Exists, Item: ".concat(item.getStringID()))
            let itemId = item.getStringID()
            assert(self.borrowEntryByID(itemId) != nil, message: "Not Found in Inventory, Item: ".concat(itemId))
            assert(self.hasItemEquipped(item), message: "Not Equipped, Item: ".concat(itemId))

            let slots = self.borrowSlotsOccupied()
            let requiredSlots = itemRef.slotsOccupied
            for slot in requiredSlots.keys {
                if let occupied = slots[slot] {
                    let newOccupied: [String] = []
                    for id in occupied {
                        if id != itemId {
                            newOccupied.append(id)
                        }
                    }
                    slots[slot] = newOccupied
                }
            }

            emit CreatureItemUnequipped(
                item.library,
                itemId,
                self.owner?.address,
                itemUUID: itemRef.uuid,
                uuid: self.uuid
            )
        }

        /// Internal: Checks if an item reference can be equipped based on slot availability.
        ///
        /// @param itemRef Reference to the Item resource.
        /// @return True if the item can be equipped, false otherwise.
        access(contract)
        fun _isItemEquippable(_ itemRef: &Item): Bool {
            let allSlots = self.getSlotsAll()
            let occupiedSlots = self.borrowSlotsOccupied()
            let requiredSlots = itemRef.slotsOccupied;
            for slot in requiredSlots.keys {
                let allCount = allSlots[slot] ?? 0
                let occupiedCount = UInt8(occupiedSlots[slot]?.length ?? 0)
                if allCount - occupiedCount < requiredSlots[slot]! {
                    return false
                }
            }
            return true
        }

        // --- Equipable Methods - Feature, Read ---

        // Returns a map of fixed abilities (from features) by their string ID
        access(all)
        fun getFixedAbilities(): {String: Bool} {
            let ret: {String: Bool} = {}
            let features = self.borrowFeatures()

            for feature in features {
                if feature.hasAbilities() {
                    let abilities = feature.getAbilityIdentifiers()
                    for ability in abilities {
                        if ret[ability.getStringID()] == nil {
                            ret[ability.getStringID()] = true
                        }
                    }
                }
            }
            return ret
        }

        // Returns a map of fixed items (from features) and their amounts
        access(all)
        fun getFixedItems(): {String: UFix64} {
            let ret: {String: UFix64} = {}
            let features = self.borrowFeatures()

            for feature in features {
                if feature.hasItems() {
                    let items = feature.borrowItemEntries()
                    for item in items {
                        let itemId = item.identifier.getStringID()
                        ret[itemId] = item.balance + (ret[itemId] ?? 0.0)
                    }
                }
            }
            return ret
        }
    }

    // This is a resource that can apply features to itself
    access(all) resource interface StaticCollectionWithFeatures: StaticCollectionUnit {
        access(all)
        fun applyFeature(_ feature: @FungibleEntry) {
            self.deposit(entry: <- feature)
        }
    }

    // This is a resource that can store bio prompts
    access(all) resource interface BioPromptsUnit {
        access(all) let bioPrompts: [String]

        access(Host) view
        fun borrowWritableBioPrompts(): auth(Mutate) &[String] {
            return &self.bioPrompts
        }
    }

    // This is a resource that can store a merged status
    access(all) resource interface MergableStatusUnit {
        access(all) let status: UnitStatus

        /// Returns a reference to the merged status of the creature.
        ///
        /// @return Reference to the UnitStatus struct.
        access(all) view
        fun borrowStatus(): &UnitStatus {
            return &self.status
        }
    }

    /// The Creature resource represents a static, character template with fixed attributes, defence, potentiality, and inventory.
    access(all) resource Creature: Nameable, BioPromptsUnit, MergableStatusUnit, EquipableCreatureInterface, UnitCollectionCarrier, SettingsUnit, StaticCollectionWithFeatures {
        /// The name of the creature.
        access(all) let name: String
        /// The tags associated with the creature.
        access(all) let tags: [String]
        /// The collection of entries (items, abilities, etc.) owned by the creature.
        access(all) let collection: @EntryCollection
        /// The settings of the creature (e.g., gender, size, etc.).
        access(all) let settings: {CreatureSettings: Int64}
        /// The base attributes of the creature.
        access(all) let baseAttributes: Attributes
        /// The base defence of the creature.
        access(all) let baseDefence: Defence
        /// The base potentiality of the creature.
        access(all) let basePotentiality: Potentiality
        /// The merged status of the creature (after applying features, items, etc.).
        access(all) let status: UnitStatus
        /// The bio prompts of the creature.
        access(all) let bioPrompts: [String]

        /// Initializes a new Creature resource.
        ///
        /// @param name The name of the creature.
        /// @param tags The tags associated with the creature.
        /// @param shape The EntryIdentifier for the creature's shape.
        /// @param settings The settings for the creature.
        /// @param attributes The base attributes.
        /// @param defence The base defence.
        /// @param potentiality The base potentiality.
        /// @param features The EntryIdentifiers for features to apply.
        /// @param abilities The EntryIdentifiers for abilities to add.
        /// @param items The EntryIdentifiers for items to add.
        /// @param itemAmounts The mapping of item IDs to their amounts.
        /// @param bioPrompts The bio prompts for the creature.
        init(
            name: String,
            tags: [String],
            shape: EntryIdentifier,
            settings: {CreatureSettings: Int64},
            attributes: Attributes,
            defence: Defence,
            potentiality: Potentiality,
            features: [EntryIdentifier],
            abilities: [EntryIdentifier],
            items: [EntryIdentifier],
            itemAmounts: {String: UFix64},
            bioPrompts: [String]
        ) {
            self.name = name
            self.tags = tags
            self.settings = settings
            self.bioPrompts = bioPrompts
            self.baseAttributes = attributes
            self.baseDefence = defence
            self.basePotentiality = potentiality
            // Initialize the status
            self.status = UnitStatus(
                attributes: self.baseAttributes,
                defence: self.baseDefence,
                potentiality: self.basePotentiality
            )
            self.collection <- create EntryCollection()

            // Set the entries for shape, abilities, items
            self.applyShape(<-create FungibleEntry(identifier: shape, amount: 1.0))

            for featureIdentifier in features {
                self.applyFeature(<-create FungibleEntry(identifier: featureIdentifier, amount: 1.0))
            }

            for abilityIdentifier in abilities {
                self.gainAbility(<-create FungibleEntry(identifier: abilityIdentifier, amount: 1.0))
            }

            if items.length > 0 {
                assert(itemAmounts.length == items.length, message: "Item amounts must be the same length as items")
                for itemIdentifier in items {
                    assert(itemIdentifier.verify(LibraryCategory.ITEM), message: "Item identifier is invalid")
                    let id = itemIdentifier.getStringID()
                    let amount = itemAmounts[id] ?? 0.0
                    self.lootItem(<-create FungibleEntry(identifier: itemIdentifier, amount: amount))
                }
            }

            // apply the status
            self.applyStatus(true)
        }

        /// Returns a reference to the base attributes of the creature.
        ///
        /// @return Reference to the base Attributes struct.
        access(all) view
        fun borrowSelfAttributes(): &Attributes {
            return &self.baseAttributes
        }

        /// Returns a reference to the base defence of the creature.
        ///
        /// @return Reference to the base Defence struct.
        access(all) view
        fun borrowSelfDefence(): &Defence {
            return &self.baseDefence
        }

        /// Returns a reference to the base potentiality of the creature.
        ///
        /// @return Reference to the base Potentiality struct.
        access(all) view
        fun borrowSelfPotentiality(): &Potentiality {
            return &self.basePotentiality
        }
    }

    // ------------ Playable Unit ------------

    // PlayableUnit interface represents a unit that can participate in gameplay and have health-related actions
    access(all) resource interface PlayableUnit: ComposableUnitStatusCarrier {
        // Returns a mutable reference to the unit's health attributes
        access(Host) view fun borrowHealth(): auth(Mutate) &Attributes

        // ---- Gameplay Methods, Read ---

        // Returns true if any of the health attributes are zero or below, indicating the unit is stunned
        access(all) view
        fun isStunned(): Bool {
            let health = self.borrowHealth()
            return health.strength <= 0 || health.vitality <= 0 || health.spirit <= 0
        }

        // Returns true if all health attributes are zero or below, indicating the unit is dead
        access(all) view
        fun isDead(): Bool {
            let health = self.borrowHealth()
            return health.strength <= 0 && health.vitality <= 0 && health.spirit <= 0
        }

        // ---- Gameplay Methods, Write ---

        // Resets the unit's health to match its current status attributes
        access(Host)
        fun resetHealth() {
            let health = self.borrowHealth()
            let status = self.borrowStatus()

            health.setValue(AttributeType.STRENGTH, status.attributes.strength)
            health.setValue(AttributeType.VITALITY, status.attributes.vitality)
            health.setValue(AttributeType.SPIRIT, status.attributes.spirit)

            emit PawnHealthReset(
                self.owner?.address ?? panic("Owner not found"),
                health.strength,
                health.vitality,
                health.spirit,
                uuid: self.uuid
            )
        }

        // Recovers a specific attribute of health by a given amount, not exceeding the max value
        access(Host)
        fun recoverHealth(_ type: AttributeType, _ amount: Int64) {
            let health = self.borrowHealth()
            let status = self.borrowStatus()

            let maxAttr = status.attributes.getValue(type)
            let currentAttr = health.getValue(type)

            var recoverAmount = amount
            if currentAttr + amount > maxAttr {
                recoverAmount = maxAttr - currentAttr
            }

            health.setValue(type, currentAttr + recoverAmount)

            emit PawnHealthRecovered(
                self.owner?.address ?? panic("Owner not found"),
                type.rawValue,
                recoverAmount,
                uuid: self.uuid
            )
        }

        // Applies damage to a specific health attribute based on attack and defense values
        access(Host)
        fun damageHealth(
            _ attacks: {AttackType: Int64},
            _ penetration: Int64,
            _ type: AttributeType,
            _ extraDefence: Defence?
        ) {
            let health = self.borrowHealth()
            let status = self.borrowStatus()

            var biggestDamage: Int64 = 0
            for attackType in attacks.keys {
                let atk = attacks[attackType] ?? 0
                var def = status.defence.getDefenceFrom(attackType)
                if extraDefence != nil {
                    def = def + extraDefence!.getDefenceFrom(attackType)
                }
                if def > penetration {
                    def = def - penetration
                } else {
                    def = 0
                }

                let damage = atk - def
                if damage > biggestDamage {
                    biggestDamage = damage
                }
            }

            health.addValue(type, -1 * biggestDamage)

            emit PawnHealthDamaged(
                self.owner?.address ?? panic("Owner not found"),
                type.rawValue,
                biggestDamage,
                uuid: self.uuid
            )
        }
    }

    access(all) resource interface EquipableUnit: EquipableCreatureInterface {
        // ---- Implement Feature Gameplay Methods ----

        // This is static, so we don't need to apply it for now
        access(Host)
        fun applyFeature(_ feature: @FungibleEntry) {
            // borrow the feature
            let featureRef = feature.identifier.borrowFeature() ?? panic("Not Exists, Feature: ".concat(feature.identifier.getStringID()))

            // apply the feature to the collection
            self.deposit(entry: <- feature)

            // generate the abilities and items from the feature
            let abilitiesFromFeature = featureRef.getAbilityIdentifiers()
            for abilityIdentifier in abilitiesFromFeature {
                self.gainAbility(<-create FungibleEntry(identifier: abilityIdentifier, amount: 1.0))
            }

            // generate the items from the feature
            let itemsFromFeature = featureRef.borrowItemEntries()
            for itemEntry in itemsFromFeature {
                self.lootItem(<- create FungibleEntry(identifier: itemEntry.identifier.clone(), amount: itemEntry.balance))
            }
        }

        // ---- Equipable Item Gameplay Methods ----

        // Adds an item to the unit's collection and equips it if possible
        access(Host)
        fun lootItem(_ entry: @FungibleEntry) {
            let itemId = entry.identifier
            let itemRef = itemId.borrowItem() ?? panic("Not Exists, Item: ".concat(itemId.getStringID()))

            self.deposit(entry: <-entry)

            if itemRef.isEquippable() && self._isItemEquippable(itemRef) {
                self.equipItem(itemId)
            }

            self.applyStatus(false)
        }

        // Removes an item from the unit's collection, unequipping it if necessary
        access(Host)
        fun dropItem(_ item: EntryIdentifier, _ amount: UFix64?): @FungibleEntry {
            if self.hasItemEquipped(item) {
                self.unequipItem(item)
            }

            let ret <- self.withdraw(item.getStringID(), amount: amount)

            self.applyStatus(false)

            return <- ret
        }
    }

    // CultivableUnit interface represents a unit that can be cultivated (upgraded) by using potentiality
    access(all) resource interface CultivableUnit: EquipableUnit, UnitCollectionCarrier {
        // The potentiality used by the character
        access(all) var potentialityUsed: UInt64
        // The potentiality obtained by the character
        access(all) var potentialityObtained: UInt64
        // The cultivation progress for each ability (by string ID)
        access(all) var cultivation: {String: UInt64}

        // Returns a mutable reference to the unit's cultivable attributes
        access(Host) view fun borrowCultivableAttributes(): auth(Mutate) &Attributes

        // ---- Cultivable Methods, Read ----

        // Returns the amount of potentiality available for upgrades
        access(all) view
        fun getUsablePotentiality(): UInt64 {
            let status = self.borrowStatus()
            return UInt64(status.potentiality.initial) + self.potentialityObtained - self.potentialityUsed
        }

        // Checks if the unit can upgrade a specific attribute based on available potentiality
        access(all) view
        fun canUpgradeAttribute(_ type: AttributeType): Bool {
            // +1 attribute requires unused potentiality = 3 x current attribute value
            let attributes = self.borrowCultivableAttributes()
            let currentValue = attributes.getValue(type)
            let unusedPotentiality = self.getUsablePotentiality()
            return Int64(unusedPotentiality) >= 3 * currentValue
        }

        // --- Cultivable Methods - Attribute, Write ---

        // Increases the amount of potentiality obtained
        access(Host)
        fun gainPotentiality(_ amount: UInt64) {
            self.potentialityObtained = self.potentialityObtained + amount

            emit PawnPotentialityGained(
                self.owner?.address ?? panic("Owner not found"),
                amount,
                uuid: self.uuid
            )
        }

        // Upgrades a specific attribute by consuming potentiality
        access(Host)
        fun upgradeAttribute(_ type: AttributeType, _ amount: UInt64) {
            let attributes = self.borrowCultivableAttributes()

            var toUpgrade = amount
            while toUpgrade > 0 {
                assert(self.canUpgradeAttribute(type), message: "Not enough potentiality to upgrade attribute")
                // consume potentiality = 3 x current attribute value
                let currentValue = attributes.getValue(type)
                // consume potentiality
                self.consumePotentiality(UInt64(currentValue * 3))

                // upgrade attribute
                attributes.addValue(type, 1)

                toUpgrade = toUpgrade - 1
            }

            emit PawnAttributeUpgraded(
                self.owner?.address ?? panic("Owner not found"),
                type.rawValue,
                amount,
                uuid: self.uuid
            )
        }

        // --- Cultivable Methods - Ability, Read ---

        // Returns the cultivation level for a specific ability
        access(all) view
        fun getCultivationLevel(_ ability: EntryIdentifier): UInt64 {
            return self.cultivation[ability.getStringID()] ?? 0
        }

        // Returns the total attributes occupied by all countable abilities
        access(all)
        fun getAbilitiesOccupiedAttributes(): Attributes {
            let occupied = Attributes(strength: 0, vitality: 0, spirit: 0)
            let ownedAbilities = self.getAbilityIdentifiers()
            let fixedAbilities = self.getFixedAbilities()

            // fixed abilities are not counted
            let countableAbilities = ownedAbilities.filter(view fun (ability: EntryIdentifier): Bool {
                return fixedAbilities[ability.getStringID()] == nil
            })

            for abilityRef in countableAbilities {
                let abilityRef = abilityRef.borrowAbility() ?? panic("Not Exists, Ability: ".concat(abilityRef.getStringID()))
                if let occupy = abilityRef.occupy {
                    occupied.addValue(occupy, Int64(abilityRef.level))
                }
            }
            return occupied
        }

        // --- Cultivable Methods - Ability, Write ---

        // Increases the cultivation level of an ability by consuming potentiality
        access(Host)
        fun cultivateAbility(_ ability: EntryIdentifier, consume: UInt64, abilityUp: UInt64) {
            let itemId = ability.getStringID()
            assert(self.borrowEntryByID(itemId) != nil, message: "Ability already exists")

            self.consumePotentiality(consume)

            let cultivation = self.cultivation[ability.getStringID()] ?? 0
            self.cultivation[ability.getStringID()] = cultivation + abilityUp

            emit PawnAbilityCultivated(
                self.owner?.address ?? panic("Owner not found"),
                ability.getStringID(),
                consume,
                abilityUp,
                uuid: self.uuid
            )
        }

        // Adds a new ability to the unit, consuming potentiality and updating status
        access(Host)
        fun gainAbility(_ ability: @FungibleEntry) {
            let itemId = ability.identifier.getStringID()
            assert(self.borrowEntryByID(itemId) == nil, message: "Ability already exists")

            self.cultivation[itemId] = 0

            let abilityRef = ability.identifier.borrowAbility() ?? panic("Not Exists, Ability: ".concat(itemId))

            // check if the ability is fixed
            let fixedAbilities = self.getFixedAbilities()
            // For fixed abilities, we don't consume potentiality
            if fixedAbilities[itemId] != true {
                // Consume potentiality = 3 x ability level
                self.consumePotentiality(abilityRef.level * 3)

                let status = self.borrowStatus()
                // Check ability occupied value
                if let attributeToOccupy = abilityRef.occupy {
                    let occupied = self.getAbilitiesOccupiedAttributes()
                    let currentAttr = status.attributes.getValue(attributeToOccupy)
                    let occupiedAttr = occupied.getValue(attributeToOccupy)
                    assert(occupiedAttr + Int64(abilityRef.level) <= currentAttr, message: "Attribute is full")
                }
            }

            // Add ability to collection
            self.deposit(entry: <- ability)

            // Apply the ability effects
            self.applyStatus(false)
        }

        // Removes an ability from the unit and resets its cultivation
        access(Host)
        fun dropAbility(_ ability: EntryIdentifier): @FungibleEntry {
            let itemId = ability.getStringID()
            assert(self.borrowEntryByID(itemId) != nil, message: "Ability not exists")

            // Clear cultivation
            self.cultivation[itemId] = 0

            let ret <- self.withdraw(itemId, amount: nil)

            self.applyStatus(false)

            return <- ret
        }

        // --- Cultivable Methods - Potentiality, Write ---

        // Consumes a specified amount of potentiality for upgrades or actions
        access(contract)
        fun consumePotentiality(_ consume: UInt64) {
            pre {
                self.getUsablePotentiality() >= consume: "Not enough potentiality to consume, consume: "
                    .concat(consume.toString())
                    .concat(", usable: ")
                    .concat(self.getUsablePotentiality().toString())
            }
            self.potentialityUsed = self.potentialityUsed + consume

            emit PawnPotentialityConsumed(
                self.owner?.address ?? panic("Owner not found"),
                consume,
                self.getUsablePotentiality(),
                self.potentialityUsed,
                uuid: self.uuid
            )
        }
    }

    // Pawn resource represents a playable and cultivable character in the game
    access(all) resource Pawn: PlayableUnit, CultivableUnit, CollectionContainerUnit, BioPromptsUnit, MergableStatusUnit, SettingsUnit {
        // The address of the library this pawn belongs to
        access(contract) let library: Address
        // Initial defence (will not be changed after initialization)
        access(self) let initDefence: Defence
        // Initial potentiality (will not be changed after initialization)
        access(self) let initPotentiality: Potentiality

        // --- Status Properties ---

        // The merged status of the character
        access(all) let status: UnitStatus
        // The health of the character, can be damaged
        access(all) var health: Attributes

        // --- Cultivable Property ---

        // The potentiality used by the character
        access(all) var potentialityUsed: UInt64
        // The potentiality obtained by the character
        access(all) var potentialityObtained: UInt64
        // The cultivation of the character
        access(all) var cultivation: {String: UInt64}

        // Cultivable attributes, can be upgraded by potentiality
        access(all) let attributes: Attributes

        // The collection of the character (items, abilities, etc.)
        access(all) let collection: @EntryCollection

        // --- Settings ---

        // The settings of the character
        access(all) let settings: {CreatureSettings: Int64}
        // The bio prompts of the character
        access(all) let bioPrompts: [String]

        // Initializes a new Pawn with the given parameters
        init(
            _ library: Address,
            template: EntryIdentifier?,
            shape: EntryIdentifier?,
            features: [EntryIdentifier],
            items: [EntryIdentifier],
            itemAmounts: {String: UFix64},
            abilities: [EntryIdentifier],
            bioPrompts: [String]
        ) {
            self.library = library

            self.settings = {}
            self.bioPrompts = bioPrompts

            // Clone the parameters
            var shapeToApply = shape

            let featuresToApply = features
            let featuresDict: {String: Bool} = {}
            for feature in features {
                featuresDict[feature.getStringID()] = true
            }

            let itemsToApply = items
            let itemAmountsToApply = itemAmounts
            for item in items {
                let itemId = item.getStringID()
                itemAmountsToApply[itemId] = itemAmounts[itemId] ?? 0.0
            }

            let abilitiesToApply = abilities
            let abilitiesDict: {String: Bool} = {}
            for ability in abilities {
                abilitiesDict[ability.getStringID()] = true
            }

            // Apply the template if it exists
            if template != nil {
                let creature = template!.borrowCreature() ?? panic("Not Exists, Creature: ".concat(template!.getStringID()))

                // Extract template's Abilities, Defence, Potentiality
                self.initDefence = creature.borrowSelfDefence().copy() as! Defence
                self.initPotentiality = creature.borrowSelfPotentiality().copy() as! Potentiality
                self.attributes = creature.borrowSelfAttributes().copy() as! Attributes

                // If the shape is not provided, use the template's shape
                if shapeToApply == nil {
                    // A creature must have a shape
                    let templateShapeIdentifier = creature.getShapeIdentifier() ?? panic("Shape not exists for Creature: ".concat(template!.getStringID()))
                    shapeToApply = templateShapeIdentifier
                }

                // Extract template's Features
                let templateFeatures = creature.getFeatureIdentifiers()
                for feature in templateFeatures {
                    let featureId = feature.getStringID()
                    if featuresDict[featureId] == nil {
                        featuresToApply.append(feature)
                        featuresDict[featureId] = true
                    }
                }

                // Extract template's Abilities
                let templateAbilities = creature.getAbilityIdentifiers()
                for ability in templateAbilities {
                    let abilityId = ability.getStringID()
                    if abilitiesDict[abilityId] == nil {
                        abilitiesToApply.append(ability)
                    }
                }

                // Extract template's Items
                let templateItems = creature.borrowItemEntries()
                for item in templateItems {
                    let itemId = item.identifier.getStringID()
                    itemAmountsToApply[itemId] = (itemAmountsToApply[itemId] ?? 0.0) + item.balance
                }

                // Apply the template's settings
                if creature.hasSettings() {
                    let templateSettings = creature.borrowWritableSettings()
                    for key in templateSettings.keys {
                        self.settings[key] = templateSettings[key]!
                    }
                }

                // Apply the template's bio prompts
                let templateBioPrompts = creature.borrowWritableBioPrompts()
                for prompt in templateBioPrompts {
                    self.bioPrompts.append(prompt)
                }
            } else {
                // If the template is not provided, that is a player, so we need to use the library's settings

                let lib = FGameMishal.borrowLibrary(library) ?? panic("Library not found")
                let initPtt = lib.settings[LibrarySettings.INIT_POTENTIALITY] ?? 36
                let initDef = lib.settings[LibrarySettings.INIT_DEFENCE_VALUE] ?? 0
                let initAttr = lib.settings[LibrarySettings.INIT_ATTRIBUTE_VALUE] ?? 3

                self.initDefence = Defence(physical: initDef, endurance: initDef, resistance: initDef)
                self.initPotentiality = Potentiality(initial: initPtt)
                self.attributes = Attributes(strength: initAttr, vitality: initAttr, spirit: initAttr)
            }

            // Initialize the status and health, but it will be reset later
            self.status = UnitStatus(
                attributes: self.attributes,
                defence: self.initDefence,
                potentiality: self.initPotentiality
            )
            self.health = Attributes(strength: 0, vitality: 0, spirit: 0)

            // Initialize the cultivable properties
            self.potentialityUsed = 0
            self.potentialityObtained = 0
            self.cultivation = {}

            // Initialize the collection
            self.collection <- create EntryCollection()

            // Set the entries for shape, abilities, items
            self.applyShape(<-create FungibleEntry(identifier: shapeToApply!, amount: 1.0))

            for featureIdentifier in featuresToApply {
                self.applyFeature(<-create FungibleEntry(identifier: featureIdentifier, amount: 1.0))
            }

            for abilityIdentifier in abilitiesToApply {
                self.gainAbility(<-create FungibleEntry(identifier: abilityIdentifier, amount: 1.0))
            }

            if itemsToApply.length > 0 {
                assert(itemAmountsToApply.length == itemsToApply.length, message: "Item amounts must be the same length as items")
                for itemIdentifier in itemsToApply {
                    let id = itemIdentifier.getStringID()
                    let amount = itemAmountsToApply[id] ?? 0.0
                    self.lootItem(<-create FungibleEntry(identifier: itemIdentifier, amount: amount))
                }
            }

            // Apply the status and reset the health
            self.applyStatus(true)
            self.resetHealth()
        }

        // ---- Interface Implementation ----

        // Returns a reference to the pawn's cultivable attributes
        access(all) view
        fun borrowSelfAttributes(): &Attributes {
            return self.borrowCultivableAttributes()
        }

        // Returns a reference to the pawn's initial defence
        access(all) view
        fun borrowSelfDefence(): &Defence {
            return &self.initDefence
        }

        // Returns a reference to the pawn's initial potentiality
        access(all) view
        fun borrowSelfPotentiality(): &Potentiality {
            return &self.initPotentiality
        }

        // Returns a mutable reference to the pawn's cultivable attributes
        access(Host) view
        fun borrowCultivableAttributes(): auth(Mutate) &Attributes {
            return &self.attributes
        }

        // Returns a mutable reference to the pawn's health attributes
        access(Host) view
        fun borrowHealth(): auth(Mutate) &Attributes {
            return &self.health
        }
    }

    // ---- Public Functions ----

    access(all)
    fun createLibrary(): @Library {
        return <- create Library()
    }

    access(all) view
    fun borrowLibrary(_ address: Address): &Library? {
        return getAccount(address).capabilities
            .get<&Library>(self.libraryPublicPath)
            .borrow()
    }

    access(all) view
    fun borrowPopularLibrary(): &Library? {
        // Borrow the libraray with the highest item count
        var maxItemCount: UInt64 = 0
        var popularLibrary: &Library? = nil

        let keys = self.libraryItems.keys
        for key in keys {
            if self.libraryItems[key]! > maxItemCount {
                maxItemCount = self.libraryItems[key]!
                if let library = self.borrowLibrary(key) {
                    popularLibrary = library
                }
            }
        }
        return popularLibrary
    }

    init() {
        self.libraryItems = {}

        let identifier = "FGameMishal_".concat(self.account.address.toString())
        self.libraryStoragePath = StoragePath(identifier: identifier.concat("_Library"))!
        self.libraryPublicPath = PublicPath(identifier: identifier.concat("_Library"))!
    }
}
