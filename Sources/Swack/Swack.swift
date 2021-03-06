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

import Vapor
import Foundation

public typealias EventListener = (EventsAPIRequest) -> ()

public protocol SlashCommandListener: class {

    var command: String { get }

    func slashCommandReceived(command: SlashCommand, swack: Swack)

}

public protocol MessageListener: class {

    func responsible(for input: String) -> Bool
    func messageReceived(_ messageEvent: MessageEvent, swack: Swack)

}

public typealias DialogSubmissionListener = (DialogSubmission, Swack) -> Void

public class Swack {

    private let isDebug: Bool

    private let application: Application
    private let client: Client

    private let chatService: ChatService
    private let dialogService: DialogService
    private let authService: AuthService

    private var messageListeners = [MessageListener]()
    private var slashCommandListeners = [SlashCommandListener]()

    private var dialogs = [String: DialogSubmissionListener]()

    public init(token: String, application: Application, isDebug: Bool) throws {
        self.isDebug = isDebug
        self.application = application
        self.client = try application.client()
        self.chatService = ChatService(client: client, token: token)
        self.dialogService = DialogService(client: client, token: token)
        self.authService = AuthService(client: client, token: token)

        try setupRoutes()
    }

    private func setupRoutes() throws {
        let router = try application.make(Router.self)

        let eventsController = EventsController()
        eventsController.delegate = self
        try eventsController.boot(router: router)

        let slashCommandsController = SlashCommandsController()
        slashCommandsController.delegate = self
        try slashCommandsController.boot(router: router)

        let interactiveComponentsController = InteractiveComponentsController()
        interactiveComponentsController.delegate = self
        try interactiveComponentsController.boot(router: router)
    }


    public func addMessageListener(_ listener: MessageListener) {
        messageListeners.append(listener)
    }

    public func addSlashCommandListener(_ listener: SlashCommandListener) {
        slashCommandListeners.append(listener)
    }

    @discardableResult
    public func replyWithDialog(to slashCommand: SlashCommand, dialog: Dialog, onSubmission: @escaping DialogSubmissionListener) -> Future<Response> {
        let dialogOpenRequest = DialogOpenRequest(triggerId: slashCommand.triggerId, dialog: dialog)
        dialogs[dialog.callbackId] = onSubmission
        return dialogService.post(dialogOpenRequest)
    }

    private func log(object: Any) {
        guard isDebug else { return }
        print(String(reflecting: object))
    }

}


// MARK: WebAPI - Chat
extension Swack {

    @discardableResult
    public func reply(to replyable: Replyable, text: String) -> Future<Response> {
        return post(to: replyable.toChannel, text: text)
    }

    @discardableResult
    public func replyEphemeral(to replyable: Replyable, text: String) -> Future<Response> {
        let message = ChatPostEphemeralMessage(channel: replyable.toChannel, user: replyable.toUser, text: text)
        return chatService.postEphemeral(message)
    }

    @discardableResult
    public func post(to channel: String, text: String) -> Future<Response> {
        let message = ChatPostMessage(channel: channel, text: text)
        return chatService.post(message)
    }

}

extension Swack: EventsControllerDelegate {

    func received(event: EventsAPIRequest) {
        log(object: event)
        switch event.event {
        case let event as MessageEvent:
            messageEventReceived(event)
        default:
            break
        }
    }

    func messageEventReceived(_ event: MessageEvent) {
        for listener in messageListeners {
            guard listener.responsible(for: event.text) else { continue }
            listener.messageReceived(event, swack: self)
        }
    }

}

extension Swack: SlashCommandsControllerDelegate {


    func received(command: SlashCommand) {
        log(object: command)
        for listener in slashCommandListeners {
            guard listener.command == command.command else { continue }
            listener.slashCommandReceived(command: command, swack: self)
        }
    }

}

extension Swack: InteractiveComponentsControllerDelegate {

    func received(submission: DialogSubmission) {
        log(object: submission)
        dialogs[submission.callbackId]?(submission, self)
    }

}
