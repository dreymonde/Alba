/**
 *  Alba
 *
 *  Copyright (c) 2016 Oleg Dreyman. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

public protocol Subscribable : class {
    
    associatedtype Subscription
    
    var subscribers: [ObjectIdentifier : Subscription] { get set }
    
    func subscribe(objectWith objectIdentifier: ObjectIdentifier, with subscription: Subscription)
    func unsubscribe(objectWith objectIdentifier: ObjectIdentifier)
    
}

public extension Subscribable {
    
    func subscribe(objectWith objectIdentifier: ObjectIdentifier, with subscription: Subscription) {
        #if DEBUG
            if let _ = subscribers[objectIdentifier] {
                print("Already existing subscription for \(objectIdentifier), overwriting...")
            }
        #endif
        subscribers[objectIdentifier] = subscription
    }
    
    func unsubscribe(objectWith objectIdentifier: ObjectIdentifier) {
        subscribers[objectIdentifier] = nil
    }
    
}

public protocol PublisherProtocol : class, Subscribable {
    
    typealias Subscription = EventHandler<Event>
    
    associatedtype Event
    
    var subscribers: [ObjectIdentifier : EventHandler<Event>] { get set }
    
    func publish(_ event: Event)
    
}

public extension PublisherProtocol {
    
    func publish(_ event: Event) {
        subscribers.values.forEach({ handle in handle(event) })
    }
    
}

public class Publisher<Event> : PublisherProtocol {
    
    public var subscribers: [ObjectIdentifier : EventHandler<Event>] = [:]
    
    public init() { }
    
}

public struct Pub<Event> {
    
    private let publisher: Publisher<Event>
    public var proxy: PublisherProxy<Event> {
        return publisher.proxy
    }

    public init(publisher: Publisher<Event> = .init()) {
        self.publisher = publisher
    }

    public mutating func publish(_ event: Event) {
        publisher.publish(event)
    }
    
    public mutating func consume(_ proxy: PublisherProxy<Event>) {
        proxy.redirect(to: publisher)
    }
    
}

public class SignedPublisher<Event> : PublisherProtocol {
    
    public var subscribers: [ObjectIdentifier : EventHandler<Signed<Event>>] = [:]

    public init() { }
    
    public func publish(_ event: Event, submitterIdentifier: ObjectIdentifier?) {
        subscribers.forEach { (subcriberIdentifier, handler) in
            if subcriberIdentifier != submitterIdentifier {
                handler(.init(event, submitterIdentifier))
            }
        }
    }
    
    public func publish(_ event: Event, submittedBy submitter: AnyObject?) {
        publish(event, submitterIdentifier: submitter.map(ObjectIdentifier.init))
    }
    
}

public struct SignedPub<Event> {
    
    private let publisher: SignedPublisher<Event>
    public var proxy: SignedPublisherProxy<Event> {
        return publisher.proxy
    }
    
    public init(publisher: SignedPublisher<Event> = .init()) {
        self.publisher = publisher
    }
    
    public mutating func publish(_ signedEvent: Signed<Event>) {
        publisher.publish(signedEvent)
    }
    
    public mutating func publish(_ event: Event, submitterIdentifier: ObjectIdentifier?) {
        publisher.publish(event, submitterIdentifier: submitterIdentifier)
    }
    
    public mutating func publish(_ event: Event, submittedBy submitter: AnyObject?) {
        publisher.publish(event, submittedBy: submitter)
    }
    
    public mutating func consume(_ proxy: SignedPublisherProxy<Event>) {
        proxy.redirect(to: publisher)
    }
    
}
