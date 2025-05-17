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
    // Entitlements for the Manage role (Like the host of the game)
    access(all) entitlement Manage;

    // ----- Events -----

    access(all) event LibrarySettingChanged(_ library: Address, key: UInt8, value: Int64)
    access(all) event LibraryEntryAdded(_ library: Address, _ category: UInt8, _ uuid: UInt64, _ name: String, _ tags: [String])
    access(all) event LibraryEntryRemoved(_ library: Address, _ category: UInt8, _ uuid: UInt64)

    access(all) event UnitStatusApplied(_ unitUID: UInt64, _ attributes: Attributes, _ defence: Defence, _ potentiality: Potentiality)

    access(all) event EntryDeposited(_ library: Address, _ category: UInt8, _ uuid: UInt64, _ amount: UFix64, _ to: Address?, entryUUID: UInt64, collectionUUID: UInt64)
    access(all) event EntryWithdrawn(_ library: Address, _ category: UInt8, _ uuid: UInt64, _ amount: UFix64, _ from: Address?, entryUUID: UInt64, collectionUUID: UInt64)

    access(all) event CreatureItemEquipped(_ library: Address, _ item: String, _ owner: Address?, itemUUID: UInt64)
    access(all) event CreatureItemUnequipped(_ library: Address, _ item: String, _ owner: Address?, itemUUID: UInt64)

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

        access(contract)
        fun setStrength(_ strength: Int64) {
            self.strength = strength
        }

        access(contract)
        fun addStrength(_ strength: Int64) {
            self.strength = self.strength + strength
        }

        access(contract)
        fun setVitality(_ vitality: Int64) {
            self.vitality = vitality
        }

        access(contract)
        fun addVitality(_ vitality: Int64) {
            self.vitality = self.vitality + vitality
        }

        access(contract)
        fun setSpirit(_ spirit: Int64) {
            self.spirit = spirit
        }

        access(contract)
        fun addSpirit(_ spirit: Int64) {
            self.spirit = self.spirit + spirit
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

        access(contract)
        fun setPhysical(_ physical: Int64) {
            self.physical = physical
        }

        access(contract)
        fun addPhysical(_ physical: Int64) {
            self.physical = self.physical + physical
        }

        access(contract)
        fun setEndurance(_ endurance: Int64) {
            self.endurance = endurance
        }

        access(contract)
        fun addEndurance(_ endurance: Int64) {
            self.endurance = self.endurance + endurance
        }

        access(contract)
        fun setResistance(_ resistance: Int64) {
            self.resistance = resistance
        }

        access(contract)
        fun addResistance(_ resistance: Int64) {
            self.resistance = self.resistance + resistance
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

        access(Manage)
        fun setValue(value: UFix64) {
            self.value = value
        }

        access(Manage)
        fun addValue(value: UFix64) {
            self.value = (self.value ?? 0.0) + value
        }
    }

    access(all) resource interface EffectsCarrier {
        access(all) let effects: [String]

        access(all) view
        fun hasEffects(): Bool {
            return self.effects.length > 0
        }

        access(Manage)
        fun addEffect(effect: String) {
            self.effects.append(effect)
        }

        access(Manage)
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
        fun applyStatus() {
            let status = self.borrowStatus()

            // Calculate the new attributes of the unit
            let attributes = self.borrowAttributesElements()
            let newAttributes = Attributes(strength: 0, vitality: 0, spirit: 0)
            for attribute in attributes {
                newAttributes.addStrength(attribute.strength)
                newAttributes.addVitality(attribute.vitality)
                newAttributes.addSpirit(attribute.spirit)
            }
            status.setAttributes(newAttributes)

            // Calculate the new defence of the unit
            let defence = self.borrowDefenceElements()
            let newDefence = Defence(physical: 0, endurance: 0, resistance: 0)
            for one in defence {
                newDefence.addPhysical(one.physical)
                newDefence.addEndurance(one.endurance)
                newDefence.addResistance(one.resistance)
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
    }

    access(all) resource Ability: AttributeCarrier, EffectsCarrier, Nameable {
        access(all) let name: String
        access(all) let tags: [String]
        access(all) let level: UInt64
        access(all) let occupy: Attributes
        access(all) let effects: [String]

        view init(
            level: UInt64,
            name: String,
            tags: [String],
            occupy: Attributes,
            effects: [String]
        ) {
            self.name = name
            self.tags = tags
            self.level = level
            self.occupy = occupy
            self.effects = effects
        }

        access(all) view fun borrowAttributes(): &Attributes? {
            return &self.occupy as &Attributes
        }
    }

    // The CreatureSettingsCarrier resource interface is used to get the settings of the creature.
    access(all) resource interface CreatureSettingsCarrier {
        access(all) let settings: {CreatureSettings: Int64}

        access(all) view
        fun getSetting(_ setting: CreatureSettings): Int64? {
            return self.settings[setting]
        }

        access(all) view
        fun hasSettings(): Bool {
            return self.settings.length > 0
        }
    }

    access(all) resource Shape: CreatureSettingsCarrier, Nameable {
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
    access(all) resource interface ShapeCarrier: CreatureSettingsCarrier {
        access(all) let settings: {CreatureSettings: Int64}

        access(all) view fun borrowShape(): &Shape?

        access(all) view
        fun hasShape(): Bool {
            return self.borrowShape() != nil
        }

        access(all) view
        fun getGender(): Int64? {
            if let gender = self.settings[CreatureSettings.GENDER] {
                return gender
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.GENDER)
            }
            return nil
        }

        access(all) view
        fun getForm(): Int64? {
            if let form = self.settings[CreatureSettings.FORM] {
                return form
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.FORM)
            }
            return nil
        }

        access(all) view
        fun getSize(): Int64? {
            if let size = self.settings[CreatureSettings.SIZE] {
                return size
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.SIZE)
            }
            return nil
        }

        access(all) view
        fun getMoveSpeed(): Int64? {
            if let moveSpeed = self.settings[CreatureSettings.MOVE_SPEED] {
                return moveSpeed
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.MOVE_SPEED)
            }
            return nil
        }

        access(all) view
        fun getPerceptionRange(): Int64? {
            if let perceptionRange = self.settings[CreatureSettings.PERCEPTION_RANGE] {
                return perceptionRange
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.PERCEPTION_RANGE)
            }
            return nil
        }

        access(all) view
        fun getOccupyRange(): Int64? {
            if let occupyRange = self.settings[CreatureSettings.OCCUPY_RANGE] {
                return occupyRange
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.OCCUPY_RANGE)
            }
            return nil
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
                    ret.append(EntryIdentifier(library: ref.identifier.library, category: ref.identifier.category, id: ref.identifier.id))
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

        access(all)
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

            if self.isNonFungible(entry.identifier.category) {
                assert(entry.balance == 1.0 && self.entries[uid] == nil, message: "Non-fungible entry must have a balance of 1.0")
            }

            if let oldRef = self.borrowEntryByID(uid) {
                oldRef.deposit(from: <- entry)
            } else {
                self.entries[uid] <-! entry
            }
        }

        access(Manage)
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
            if self.isNonFungible(ref.identifier.category) {
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

        access(Manage) view
        fun borrowEditableEntry(_ id: String): auth(FungibleToken.Withdraw) &FungibleEntry? {
            return &self.entries[id]
        }

        access(self) view
        fun isNonFungible(_ category: LibraryCategory): Bool {
            switch category {
                case LibraryCategory.OBJECT:
                    return false
                case LibraryCategory.ITEM:
                    return false
                default:
                    return true
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
    }

    access(all) resource interface EquippedItemsCarrier: ItemsCarrier {
        access(all) view fun getSlotsAll(): {EquipSlot: UInt8}
        access(Manage) view fun borrowSlotsOccupied(): auth(Mutate) &{EquipSlot: [String]}

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

        access(all) view
        fun isItemEquippable(_ item: EntryIdentifier): Bool {
            if let itemRef = item.borrowItem() {
                return self._isItemEquippable(itemRef)
            }
            return false
        }

        access(Manage)
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
            )
        }

        access(Manage)
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
        }

        access(contract) view
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
    }

    access(all) resource interface UnitCollectionBaseCarrier: AbilitiesCarrier, ItemsCarrier, ShapeCarrier {
        access(Manage) view fun borrowCollection(): auth(Manage) &EntryCollection

        access(all) view fun borrowEntryByID(_ id: String): &FungibleEntry? {
            let collection = self.borrowCollection()
            return collection.borrowEntryByID(id)
        }

        access(all) view fun getAbilitiesLength(): Int {
            let collection = self.borrowCollection()
            return collection.getLengthByCategory(LibraryCategory.ABILITY)
        }

        access(all)
        fun getAbilityIdentifiers(): [EntryIdentifier] {
            let collection = self.borrowCollection()
            return collection.getEntryIdentifiers(LibraryCategory.ABILITY)
        }

        access(all) view fun getItemsLength(): Int {
            let collection = self.borrowCollection()
            return collection.getLengthByCategory(LibraryCategory.ITEM)
        }

        access(all)
        fun borrowItemEntries(): [&FungibleEntry] {
            let collection = self.borrowCollection()
            return collection.borrowEntries(LibraryCategory.ITEM)
        }

        access(all) view fun borrowShape(): &Shape? {
            let collection = self.borrowCollection()
            let shape = collection.getKeysByCategory(LibraryCategory.SHAPE)
            if shape.length > 0 {
                if let entry = collection.borrowEntryByID(shape[0]) {
                    return entry.identifier.borrowShape()
                }
            }
            return nil
        }
    }

    // The Feature resource is used to define the features of the entry.
    access(all) resource Feature: Nameable, OptionalStatusCarrier, UnitCollectionBaseCarrier, EffectsCarrier {
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

            // Set the entries

            // check identifiers
            if shape != nil {
                assert(shape!.verify(LibraryCategory.SHAPE), message: "Shape identifier is invalid")
                self.collection.deposit(entry: <-create FungibleEntry(identifier: shape!, amount: 1.0))
            }
            for abilityIdentifier in abilities {
                self.collection.deposit(entry: <-create FungibleEntry(identifier: abilityIdentifier, amount: 1.0))
            }
            if items.length > 0 {
                assert(itemAmounts.length == items.length, message: "Item amounts must be the same length as items")
                for itemIdentifier in items {
                    let id = itemIdentifier.getStringID()
                    let amount = itemAmounts[id] ?? 0.0
                    self.collection.deposit(entry: <-create FungibleEntry(identifier: itemIdentifier, amount: amount))
                }
            }
        }

        access(Manage) view
        fun borrowCollection(): auth(Manage) &EntryCollection {
            return &self.collection
        }
    }

    access(all) resource interface FeaturesCarrier {
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
    }

    access(all) resource interface UnitCollectionCarrier: UnitCollectionBaseCarrier, FeaturesCarrier {
        access(all) view fun getFeaturesLength(): Int {
            let collection = self.borrowCollection()
            return collection.getLengthByCategory(LibraryCategory.FEATURE)
        }

        access(all)
        fun getFeatureIdentifiers(): [EntryIdentifier] {
            let collection = self.borrowCollection()
            return collection.getEntryIdentifiers(LibraryCategory.FEATURE)
        }
    }

    access(all) resource interface BioCarrier {
        access(all) let bioPrompts: [String]

        access(all) view
        fun borrowBioPrompts(): &[String] {
            return &self.bioPrompts
        }

        access(Manage)
        fun addBioPrompt(_ prompt: String) {
            self.bioPrompts.append(prompt)
        }
    }

    access(all) resource interface CreatureInterface: ComposableUnitStatusCarrier, AbilitiesCarrier, EquippedItemsCarrier, FeaturesCarrier, ShapeCarrier {
        access(all) view fun borrowSelfAttributes(): &Attributes
        access(all) view fun borrowSelfDefence(): &Defence
        access(all) view fun borrowSelfPotentiality(): &Potentiality

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
    }

    access(all) resource Creature: Nameable, CreatureInterface, UnitCollectionCarrier, BioCarrier {
        access(all) let name: String
        access(all) let tags: [String]
        access(all) let collection: @EntryCollection
        // The settings of the character
        access(all) let settings: {CreatureSettings: Int64}
        // Main attributes of the character
        access(all) let baseAttributes: Attributes
        // The base defence of the character
        access(all) let baseDefence: Defence
        // The potentiality of the character
        access(all) let basePotentiality: Potentiality
        // The merged status of the character
        access(all) let status: UnitStatus
        // The bio prompts of the character
        access(all) let bioPrompts: [String]

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

            assert(shape.verify(LibraryCategory.SHAPE), message: "Shape identifier is invalid")
            self.collection.deposit(entry: <-create FungibleEntry(identifier: shape, amount: 1.0))

            for featureIdentifier in features {
                assert(featureIdentifier.verify(LibraryCategory.FEATURE), message: "Feature identifier is invalid")
                self.collection.deposit(entry: <-create FungibleEntry(identifier: featureIdentifier, amount: 1.0))
            }

            for abilityIdentifier in abilities {
                assert(abilityIdentifier.verify(LibraryCategory.ABILITY), message: "Ability identifier is invalid")
                self.collection.deposit(entry: <-create FungibleEntry(identifier: abilityIdentifier, amount: 1.0))
            }

            if items.length > 0 {
                assert(itemAmounts.length == items.length, message: "Item amounts must be the same length as items")
                for itemIdentifier in items {
                    assert(itemIdentifier.verify(LibraryCategory.ITEM), message: "Item identifier is invalid")
                    let id = itemIdentifier.getStringID()
                    let amount = itemAmounts[id] ?? 0.0
                    self.collection.deposit(entry: <-create FungibleEntry(identifier: itemIdentifier, amount: amount))
                }
            }

            // apply the status
            self.applyStatus()
        }

        access(all) view
        fun borrowStatus(): &UnitStatus {
            return &self.status
        }

        access(all) view
        fun borrowSelfAttributes(): &Attributes {
            return &self.baseAttributes
        }

        access(all) view
        fun borrowSelfDefence(): &Defence {
            return &self.baseDefence
        }

        access(all) view
        fun borrowSelfPotentiality(): &Potentiality {
            return &self.basePotentiality
        }

        access(Manage) view
        fun borrowCollection(): auth(Manage) &EntryCollection {
            return &self.collection
        }
    }

    // ------------ Player ------------

    access(all) resource CultivableProperty {
        access(contract) let library: Address

        // --- Exported Properties ---

        access(all) let attributes: Attributes
        access(all) let defence: Defence
        access(all) let potentiality: Potentiality

        // The merged status of the character
        access(all) let status: UnitStatus

        // --- Cultivable Property ---

        access(all) var potentialityUsed: UInt64
        access(all) var potentialityObtained: UInt64

        // The collection of the character
        access(all) let collection: @EntryCollection

        view init(
            _ library: Address
        ) {
            self.library = library
            let lib = FGameMishal.borrowLibrary(library) ?? panic("Library not found")
            let initPtt = lib.settings[LibrarySettings.INIT_POTENTIALITY] ?? 36
            let initDef = lib.settings[LibrarySettings.INIT_DEFENCE_VALUE] ?? 0
            let initAttr = lib.settings[LibrarySettings.INIT_ATTRIBUTE_VALUE] ?? 3

            self.attributes = Attributes(strength: initAttr, vitality: initAttr, spirit: initAttr)
            self.defence = Defence(physical: initDef, endurance: initDef, resistance: initDef)
            self.potentiality = Potentiality(initial: initPtt)

            self.status = UnitStatus(
                attributes: self.attributes,
                defence: self.defence,
                potentiality: self.potentiality
            )

            self.potentialityUsed = 0
            self.potentialityObtained = 0

            self.collection <- create EntryCollection()
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

        access(all) view
        fun borrowStatus(): &UnitStatus {
            return &self.status
        }

        access(Manage) view
        fun borrowCollection(): auth(Manage) &EntryCollection {
            return &self.collection
        }
    }

    // The Pawn resource is refered to as the character in the game.
    access(all) resource Pawn: CreatureInterface, UnitCollectionCarrier, BioCarrier {
        // The cultivable property of the character
        access(all) let cultivable: @CultivableProperty
        // The settings of the character
        access(all) let settings: {CreatureSettings: Int64}
        // The bio prompts of the character
        access(all) let bioPrompts: [String]

        init(
            _ library: Address,
            shape: EntryIdentifier,
            features: [EntryIdentifier],
            items: [EntryIdentifier],
            itemAmounts: {String: UFix64},
            bioPrompts: [String]
        ) {
            self.settings = {}
            self.bioPrompts = bioPrompts
            self.cultivable <- create CultivableProperty(library)

            assert(shape.verify(LibraryCategory.SHAPE), message: "Shape identifier is invalid")
            self.cultivable.collection.deposit(entry: <-create FungibleEntry(identifier: shape, amount: 1.0))

            for featureIdentifier in features {
                assert(featureIdentifier.verify(LibraryCategory.FEATURE), message: "Feature identifier is invalid")
                self.cultivable.collection.deposit(entry: <-create FungibleEntry(identifier: featureIdentifier, amount: 1.0))
            }

            if items.length > 0 {
                assert(itemAmounts.length == items.length, message: "Item amounts must be the same length as items")
                for itemIdentifier in items {
                    assert(itemIdentifier.verify(LibraryCategory.ITEM), message: "Item identifier is invalid")
                    let id = itemIdentifier.getStringID()
                    let amount = itemAmounts[id] ?? 0.0
                    self.cultivable.collection.deposit(entry: <-create FungibleEntry(identifier: itemIdentifier, amount: amount))
                }
            }

            self.applyStatus()
        }

        access(all) view
        fun borrowSelfAttributes(): &Attributes {
            return self.cultivable.borrowAttributes()
        }

        access(all) view
        fun borrowSelfDefence(): &Defence {
            return self.cultivable.borrowDefence()
        }

        access(all) view
        fun borrowSelfPotentiality(): &Potentiality {
            return self.cultivable.borrowPotentiality()
        }

        access(all) view
        fun borrowStatus(): &UnitStatus {
            return self.cultivable.borrowStatus()
        }

        access(Manage) view
        fun borrowCollection(): auth(Manage) &EntryCollection {
            return self.cultivable.borrowCollection()
        }

        // ---- Pawn Cultivable Functions ----
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
