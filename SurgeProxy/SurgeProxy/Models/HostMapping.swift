//
//  HostMapping.swift
//  SurgeProxy
//
//  Host mapping model
//

import Foundation

struct HostMapping: Codable, Identifiable {
    var id: String { domain }
    let domain: String
    let value: String
}
