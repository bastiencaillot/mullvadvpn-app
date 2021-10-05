//
//  PreferencesDataSource.swift
//  MullvadVPN
//
//  Created by pronebird on 05/10/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import Foundation
import UIKit
import Network

protocol PreferencesDataSourceDelegate: AnyObject {
    func preferencesDataSource(_ dataSource: PreferencesDataSource, didChangeDataModel dataModel: PreferencesDataModel)
}

struct PreferencesDataModel: Equatable {
    var blockAdvertising: Bool
    var blockTracking: Bool
    var enableCustomDNS: Bool
    var customDNSDomains: [String]

    init(from dnsSettings: DNSSettings = DNSSettings()) {
        blockAdvertising = dnsSettings.blockAdvertising
        blockTracking = dnsSettings.blockTracking
        enableCustomDNS = dnsSettings.enableCustomDNS
        customDNSDomains = dnsSettings.customDNSDomains.map { addr in
            return "\(addr.ipAddress)"
        }
    }

    func asDNSSettings() -> DNSSettings {
        var dnsSettings = DNSSettings()
        dnsSettings.blockAdvertising = blockAdvertising
        dnsSettings.blockTracking = blockTracking
        dnsSettings.enableCustomDNS = enableCustomDNS
        dnsSettings.customDNSDomains = customDNSDomains.compactMap { addrString in
            if let ipv4Address = IPv4Address(addrString) {
                return .ipv4(ipv4Address)
            } else if let ipv6Address = IPv6Address(addrString) {
                return .ipv6(ipv6Address)
            } else {
                return nil
            }
        }
        return dnsSettings
    }

    var canEnableCustomDNS: Bool {
        return !blockAdvertising && !blockTracking
    }

    var effectiveEnableCustomDNS: Bool {
        return !blockAdvertising && !blockTracking && enableCustomDNS
    }
}

class PreferencesDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    struct ReuseIdentifiers {
        static let switchCellIdentifier = "switchCell"
        static let dnsEntryCellIdentifier = "dnsEntryCell"
        static let customDNSFooterIdentifier = "customDNSFooter"
    }

    enum Section: CaseIterable {
        case mullvadDNS
        case customDNS
    }

    enum Item {
        case blockAdvertising
        case blockTracking
        case useCustomDNS
        case customDNSEntry
    }

    var sections: [Section] = [.mullvadDNS, .customDNS]
    var items: [Section: [Item]] = [
        .mullvadDNS: [.blockAdvertising, .blockTracking],
        .customDNS: [.useCustomDNS]
    ]

    var dataModel = PreferencesDataModel()

    weak var delegate: PreferencesDataSourceDelegate?

    weak var tableView: UITableView? {
        didSet {
            tableView?.dataSource = self
            tableView?.delegate = self

            registerCells()
        }
    }

    func registerCells() {
        tableView?.register(SettingsSwitchCell.self, forCellReuseIdentifier: ReuseIdentifiers.switchCellIdentifier)
        
        tableView?.register(SettingsDNSTextCell.self, forCellReuseIdentifier: ReuseIdentifiers.dnsEntryCellIdentifier)

        tableView?.register(EmptyTableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: EmptyTableViewHeaderFooterView.reuseIdentifier)

        tableView?.register(SettingsStaticTextFooterView.self, forHeaderFooterViewReuseIdentifier: ReuseIdentifiers.customDNSFooterIdentifier)

    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionObject = sections[section]

        return items[sectionObject]!.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionObject = sections[indexPath.section]
        let item = items[sectionObject]![indexPath.row]

        return cellForItem(item, in: tableView, at: indexPath)
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: EmptyTableViewHeaderFooterView.reuseIdentifier)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let sectionObject = sections[section]

        switch sectionObject {
        case .mullvadDNS:
            return nil

        case .customDNS:
            guard !dataModel.canEnableCustomDNS else { return nil }

            let reusableView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseIdentifiers.customDNSFooterIdentifier) as! SettingsStaticTextFooterView

            reusableView.titleLabel.text = NSLocalizedString(
                "CUSTOM_DNS_FOOTER_LABEL",
                tableName: "Preferences",
                value: "Disable Block Ads and Block trackers to activate this setting.",
                comment: ""
            )

            return reusableView
        }
    }

    func cellForItem(_ item: Item, in tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        switch item {
        case .blockAdvertising:
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.switchCellIdentifier, for: indexPath) as! SettingsSwitchCell

            cell.titleLabel.text = NSLocalizedString(
                "BLOCK_ADS_CELL_LABEL",
                tableName: "Preferences",
                value: "Block ads",
                comment: ""
            )

            cell.setOn(dataModel.blockAdvertising, animated: false)

            cell.action = { [weak self] isOn in
                self?.setBlockAdvertising(isOn)
            }

            return cell

        case .blockTracking:
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.switchCellIdentifier, for: indexPath) as! SettingsSwitchCell

            cell.titleLabel.text = NSLocalizedString(
                "BLOCK_TRACKERS_CELL_LABEL",
                tableName: "Preferences",
                value: "Block trackers",
                comment: ""
            )

            cell.setOn(dataModel.blockTracking, animated: false)

            cell.action = { [weak self] isOn in
                self?.setBlockTracking(isOn)
            }

            return cell

        case .useCustomDNS:
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.switchCellIdentifier, for: indexPath) as! SettingsSwitchCell

            cell.titleLabel.text = NSLocalizedString(
                "CUSTOM_DNS_CELL_LABEL",
                tableName: "Preferences",
                value: "Use custom DNS",
                comment: ""
            )

            cell.isEnabled = dataModel.canEnableCustomDNS
            cell.setOn(dataModel.effectiveEnableCustomDNS, animated: false)

            cell.action = { [weak self] isOn in
                self?.setEnableCustomDNS(isOn)
            }

            return cell

        case .customDNSEntry:
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.dnsEntryCellIdentifier, for: indexPath) as! SettingsDNSTextCell

            cell.textField.text = ""

            return cell
        }
    }

    func sectionIndex(for sectionIdentifer: Section) -> Int? {
        return sections.firstIndex(of: sectionIdentifer)
    }

    func sectionIndices(for sectionIdentifiers: [Section]) -> IndexSet {
        let indices = sectionIdentifiers.compactMap { section in
            return sectionIndex(for: section)
        }
        return IndexSet(indices)
    }

    func setBlockAdvertising(_ isEnabled: Bool) {
        let prevCanEnableCustomDNS = dataModel.canEnableCustomDNS

        dataModel.blockAdvertising = isEnabled

        if prevCanEnableCustomDNS != dataModel.canEnableCustomDNS {
            tableView?.performBatchUpdates {
                tableView?.reloadSections(sectionIndices(for: [.customDNS]), with: .automatic)
            }
        }
    }

    func setBlockTracking(_ isEnabled: Bool) {
        let prevCanEnableCustomDNS = dataModel.canEnableCustomDNS

        dataModel.blockTracking = isEnabled

        if prevCanEnableCustomDNS != dataModel.canEnableCustomDNS {
            tableView?.performBatchUpdates {
                tableView?.reloadSections(sectionIndices(for: [.customDNS]), with: .automatic)
            }
        }
    }

    func setEnableCustomDNS(_ isEnabled: Bool) {
        dataModel.enableCustomDNS = isEnabled

        addCustomDNSInputItemIfNeeded()
    }

    func addCustomDNSInputItemIfNeeded() {
        guard dataModel.customDNSDomains.isEmpty else { return }

        dataModel.customDNSDomains.append("")
        items[.customDNS]?.append(.customDNSEntry)

        let section = sectionIndex(for: .customDNS)!
        let indexPath = IndexPath(row: 1, section: section)

        tableView?.performBatchUpdates {
            tableView?.insertRows(at: [indexPath], with: .automatic)
        }
    }

}
