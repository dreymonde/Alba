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
        let payload = ProxyPayload.empty.adding(entry: .publisherLabel("Alba.InformBureau (\(Event.self))"))
        return PublisherProxy(subscribe: { self.handlers.append($0.1) },
                              unsubscribe: { _ in },
                              payload: payload)
    }
    
}

public class InformBureau {
    
    public typealias SubscriptionLogMessage = ProxyPayload
    public typealias PublishingLogMessage = String
    public typealias GeneralWarningLogMessage = String
    
    public static var isEnabled = false
        
    fileprivate static let subscriptionPublisher = InformBureauPublisher<SubscriptionLogMessage>()
    public static var didSubscribe: PublisherProxy<SubscriptionLogMessage> {
        return subscriptionPublisher.proxy
    }
    
    fileprivate static let publishingPublisher = InformBureauPublisher<PublishingLogMessage>()
    fileprivate static var didPublish: PublisherProxy<PublishingLogMessage> {
        return publishingPublisher.proxy
    }
    
    fileprivate static let generalWarningsPublisher = InformBureauPublisher<GeneralWarningLogMessage>()
    public static var generalWarnings: PublisherProxy<GeneralWarningLogMessage> {
        return generalWarningsPublisher.proxy
    }
    
    static func submitSubscription(_ logMessage: SubscriptionLogMessage) {
        subscriptionPublisher.publish(logMessage)
    }
    
    static func submitPublishing(_ logMessage: PublishingLogMessage) {
        publishingPublisher.publish(logMessage)
    }
    
    static func submitGeneralWarning(_ logMessage: GeneralWarningLogMessage) {
        generalWarningsPublisher.publish(logMessage)
    }
    
    public class Logger {
        
        static let shared = Logger()
        
        private init() { }
        
        public static func enable() {
            guard InformBureau.isEnabled else {
                print("Enable Alba.InformBureau first")
                return
            }
            InformBureau.didSubscribe.subscribe(shared, with: Logger.logSub)
            InformBureau.generalWarnings.subscribe(shared, with: Logger.logGeneralWarning)
        }
        
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
            print("(P) " + logMessage)
        }
        
        func logGeneralWarning(_ logMessage: GeneralWarningLogMessage) {
            print("")
            print("(W) \(logMessage)")
        }
        
    }
    
}
