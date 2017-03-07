//
//  InformBureau.swift
//  Alba
//
//  Created by Oleg Dreyman on 11.02.17.
//  Copyright © 2017 John Sundell. All rights reserved.
//

public protocol InformBureauPayload {
    
    associatedtype Entry
    
    init(entries: [Entry])
    
    var entries: [Entry] { get set }
    
}

public extension InformBureauPayload {
    
    func adding(entry: @autoclosure () -> Entry) -> Self {
        if InformBureau.isEnabled {
            var updatedEntries = entries
            updatedEntries.append(entry())
            return Self(entries: updatedEntries)
        } else {
            return .empty
        }
    }
    
    static var empty: Self {
        return Self(entries: [])
    }
    
}

fileprivate final class InformBureauPublisher<Event> : Subscribable {
    
    var handlers: [EventHandler<Event>] = []
    
    func publish(_ event: Event) {
        handlers.forEach({ $0(event) })
    }
    
    fileprivate var proxy: Subscribe<Event> {
        let payload = ProxyPayload.empty.adding(entry: .publisherLabel("Alba.InformBureau (\(Event.self))"))
        return Subscribe(subscribe: { self.handlers.append($0.1) },
                              unsubscribe: { _ in },
                              payload: payload)
    }
    
}

public final class InformBureau {
    
    public typealias SubscriptionLogMessage = ProxyPayload
    public typealias PublishingLogMessage = PublishingPayload
    public typealias GeneralWarningLogMessage = String
    
    public static var isEnabled = false
        
    fileprivate static let subscriptionPublisher = InformBureauPublisher<SubscriptionLogMessage>()
    public static var didSubscribe: Subscribe<SubscriptionLogMessage> {
        return subscriptionPublisher.proxy
    }
    
    fileprivate static let publishingPublisher = InformBureauPublisher<PublishingLogMessage>()
    public static var didPublish: Subscribe<PublishingLogMessage> {
        return publishingPublisher.proxy
    }
    
    fileprivate static let generalWarningsPublisher = InformBureauPublisher<GeneralWarningLogMessage>()
    public static var generalWarnings: Subscribe<GeneralWarningLogMessage> {
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
    
    public final class Logger {
        
        static let shared = Logger()
        
        private init() { }
        
        public static func enable() {
            guard InformBureau.isEnabled else {
                print("Enable Alba.InformBureau first")
                return
            }
            InformBureau.didSubscribe.subscribe(shared, with: Logger.logSub_def)
            InformBureau.didPublish.subscribe(shared, with: Logger.logPub)
            InformBureau.generalWarnings.subscribe(shared, with: Logger.logGeneralWarning)
        }
        
        public static func disable() {
            InformBureau.didSubscribe.unsafe.unsubscribe(self)
            InformBureau.didPublish.unsafe.unsubscribe(self)
            InformBureau.generalWarnings.unsafe.unsubscribe(self)
        }
        
        func logSub_def(_ logMessage: SubscriptionLogMessage) {
            logSub(logMessage)
            print("")
        }
        
        func logSub(_ logMessage: SubscriptionLogMessage, mergeLevel: Int = 0) {
            let mergeInset: String = (0 ..< mergeLevel).reduce("", { $0.0 + "   " })
            let mark = "(S) " + mergeInset
            if mergeLevel == 0 {
                print("")
            }
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
                case .merged(otherPayload: let other):
                    print(mark + "merged with:")
                    logSub(other, mergeLevel: mergeLevel + 1)
                }
            }
        }
        
        func logPub(_ logMessage: PublishingLogMessage) {
            let mark = "(P) "
            print("")
            for entry in logMessage.entries {
                switch entry {
                case .published(publisherLabel: let publisherLabel, event: let event):
                    print(mark + "\(publisherLabel) published \(event)")
                case .handled(handlerLabel: let handlerLabel):
                    print(mark + "--> handled by \(handlerLabel)")
                }
            }
        }
        
        func logGeneralWarning(_ logMessage: GeneralWarningLogMessage) {
            print("")
            print("(W) \(logMessage)")
        }
        
    }
    
}
