//
//  RunningApplicationProvider.swift
//  PosturePet
//
//  Created by 강찬휘 on 6/9/26.
//

import AppKit

final class RunningApplicationProvider {
    func fetchRunningApps() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications
            .filter {$0.activationPolicy == .regular}
            .compactMap{ app in
                guard let name = app.localizedName else { return nil }
                
                return RunningAppInfo(
                    id: app.bundleIdentifier ?? name,
                    name: name,
                    bundleIdentifier: app.bundleIdentifier
                )
            }
            .sorted { $0.name < $1.name }
    }
}
