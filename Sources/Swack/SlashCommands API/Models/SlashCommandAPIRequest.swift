//===----------------------------------------------------------------------===//
//
// This source file is part of the Swack open source project
//
// Copyright (c) 2018 e-Sixt
// Licensed under MIT
//
// See LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import Foundation

public struct SlashCommand: Decodable {

    public let token: String
    public let command: String
    public let text: String
    public let responseURL: String
    public let triggerId: String
    public let userId: String
    public let userName: String
    public let teamId: String
    public let channelId: String

    enum CodingKeys: String, CodingKey {
        case token
        case command
        case text
        case responseURL = "response_url"
        case userId = "user_id"
        case userName = "user_name"
        case triggerId = "trigger_id"
        case teamId = "team_id"
        case channelId = "channel_id"
    }

}

extension SlashCommand: Replyable {

    public var toChannel: String {
        return channelId
    }

    public var toUser: String {
        return userId
    }

}
