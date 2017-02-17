//
//  InformBureau.swift
//  Alba
//
//  Created by Oleg Dreyman on 11.02.17.
//  Copyright © 2017 John Sundell. All rights reserved.
//

fileprivate class InformBureauPublisher<Event> : Subscribable {
    
    var handlers: [EventHandler<Event>] = []
    
    func publish(_ event: Event) {
        handlers.forEach({ $0(event) })
    }
    
    fileprivate var proxy: PublisherProxy<Event> {
        return PublisherProxy(subscribe: { self.handlers.append($0.1) },
                              unsubscribe: { _ in },
                              payload: .empty)
    }
    
}

public class InformBureau {
    
    public typealias SubscriptionLogMessage = ProxyPayload
    public typealias PublishingLogMessage = String
    
    public static var isEnabled = false
    
    private static let logger = Logger()
    
    public static func enableLogger() {
        didSubscribe.subscribe(logger, with: Logger.logSub)
        didPublish.subscribe(logger, with: Logger.logPub)
    }
    
    fileprivate static let subscriptionPublisher = InformBureauPublisher<SubscriptionLogMessage>()
    public static var didSubscribe: PublisherProxy<SubscriptionLogMessage> {
        return subscriptionPublisher.proxy
    }
    
    fileprivate static let publishingPublisher = InformBureauPublisher<PublishingLogMessage>()
    public static var didPublish: PublisherProxy<PublishingLogMessage> {
        return publishingPublisher.proxy
    }
    
    static func submitSubscription(_ logMessage: SubscriptionLogMessage) {
        subscriptionPublisher.publish(logMessage)
    }
    
    static func submitPublishing(_ logMessage: PublishingLogMessage) {
        publishingPublisher.publish(logMessage)
    }
    
    private class Logger {
        
        func logSub(_ logMessage: SubscriptionLogMessage) {
            let mark = "(S) "
            print("")
            for entry in logMessage.entries {
                switch entry {
                case .publisherLabel(let label):
                    print(mark + label)
                case .mapped(fromType: let from, toType: let to):
                    print(mark + "--> mapped from \(from) to \(to)")
                case .filtered:
                    print(mark + "--> filtered")
                case .interrupted:
                    print(mark + "--> interrupted")
                case .redirected(to: let label):
                    print(mark + "!-> redirected to \(label)")
                case .subscribed(identifier: let identifier, ofType: let type):
                    print(mark + "!-> subscribed by \(type):\(identifier.hashValue)")
                case .listened(let type):
                    print(mark + "!-> listened with EventHandler<\(type)>")
                }
            }
        }
        
        func logPub(_ logMessage: PublishingLogMessage) {
            print("")
            print("(P) " + logMessage)
        }
        
    }
    
}
