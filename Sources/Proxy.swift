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

public protocol PublisherProxyProtocol {
    
    associatedtype Subscription
    
    func subscribe(objectWith objectIdentifier: ObjectIdentifier, with subscription: Subscription)
    func unsubscribe(objectWith objectIdentifier: ObjectIdentifier)
    
}

public extension PublisherProxyProtocol {
    
    func subscribe(_ object: AnyObject, with subscription: Subscription) {
        let identifier = ObjectIdentifier(object)
        subscribe(objectWith: identifier, with: subscription)
    }
    
    func unsubscribe(_ object: AnyObject) {
        let identifier = ObjectIdentifier(object)
        unsubscribe(objectWith: identifier)
    }
    
}

public struct PublisherProxy<Event> : PublisherProxyProtocol {
    
    fileprivate let _subscribe: (ObjectIdentifier, @escaping EventHandler<Event>) -> ()
    fileprivate let _unsubscribe: (ObjectIdentifier) -> ()
    
    public init(subscribe: @escaping (ObjectIdentifier, @escaping EventHandler<Event>) -> (),
                unsubscribe: @escaping (ObjectIdentifier) -> ()) {
        self._subscribe = subscribe
        self._unsubscribe = unsubscribe
    }
    
    public init<Pub : Publisher>(_ publisher: Pub) where Pub.Event == Event {
        self._subscribe = { [weak publisher] in publisher?.subscribe(objectWith: $0, with: $1) }
        self._unsubscribe = { [weak publisher] in publisher?.unsubscribe(objectWith: $0) }
    }
    
    public init<Pub : Publisher>(strong publisher: Pub) where Pub.Event == Event {
        self._subscribe = publisher.subscribe(objectWith:with:)
        self._unsubscribe = publisher.unsubscribe(objectWith:)
    }
    
    public var signed: SignedPublisherProxy<Event> {
        return SignedPublisherProxy<Event>(subscribe: { (identifier, handler) in
            self._subscribe(identifier, unsigned(handler))
        }, unsubscribe: self._unsubscribe)
    }
    
    public func subscribe(objectWith objectIdentifier: ObjectIdentifier,
                          with handler: @escaping EventHandler<Event>) {
        _subscribe(objectIdentifier, handler)
    }
    
    public func unsubscribe(objectWith objectIdentifier: ObjectIdentifier) {
        _unsubscribe(objectIdentifier)
    }
    
    public func subscribe<Object : AnyObject>(_ object: Object,
                          with producer: @escaping (Object) -> EventHandler<Event>) {
        let identifier = ObjectIdentifier(object)
        self.subscribe(objectWith: identifier, with: { [weak object] in
            if let object = object {
                producer(object)($0)
            } else {
                self.unsubscribe(objectWith: identifier)
            }
        })
    }
    
    public func filter(_ condition: @escaping (Event) -> Bool) -> PublisherProxy<Event> {
        return PublisherProxy<Event>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                if condition(event) { handle(event) }
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe)
    }
    
    public func map<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent) -> PublisherProxy<OtherEvent> {
        return PublisherProxy<OtherEvent>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                handle(transform(event))
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe)
    }
    
    public func flatMap<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent?) -> PublisherProxy<OtherEvent> {
        return PublisherProxy<OtherEvent>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                if let transformed = transform(event) { handle(transformed) }
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe)
    }
    
    public func redirect<Pub : Publisher>(to publisher: Pub) where Pub.Event == Event {
        subscribe(publisher, with: Pub.publish)
    }
    
}

public struct SignedPublisherProxy<Event> : PublisherProxyProtocol {
    
    public typealias Subscription = SignedEventHandler<Event>
    
    fileprivate let _subscribe: (ObjectIdentifier, @escaping SignedEventHandler<Event>) -> ()
    fileprivate let _unsubscribe: (ObjectIdentifier) -> ()
    
    public init(subscribe: @escaping (ObjectIdentifier, @escaping SignedEventHandler<Event>) -> (),
                unsubscribe: @escaping (ObjectIdentifier) -> ()) {
        self._subscribe = subscribe
        self._unsubscribe = unsubscribe
    }
    
    public init<Pub : SignedPublisher>(_ publisher: Pub) where Pub.Event == Event {
        self._subscribe = { [weak publisher] in publisher?.subscribe(objectWith: $0, with: $1) }
        self._unsubscribe = { [weak publisher] in publisher?.unsubscribe(objectWith: $0) }
    }
    
    public init<Pub : SignedPublisher>(strong publisher: Pub) where Pub.Event == Event {
        self._subscribe = publisher.subscribe(objectWith:with:)
        self._unsubscribe = publisher.unsubscribe(objectWith:)
    }
    
    public var unsigned: PublisherProxy<Event> {
        return PublisherProxy<Event>(subscribe: { (identifier, handler) in
            self._subscribe(identifier, signed(handler))
        }, unsubscribe: self._unsubscribe)
    }
    
    public func subscribe(objectWith objectIdentifier: ObjectIdentifier,
                          with handler: @escaping SignedEventHandler<Event>) {
        _subscribe(objectIdentifier, handler)
    }
    
    public func subscribe<Object : AnyObject>(_ object: Object,
                          with producer: @escaping (Object) -> SignedEventHandler<Event>) {
        let subID = ObjectIdentifier(object)
        self.subscribe(objectWith: subID, with: { [weak object] (event, objectIdentifier) in
            if let object = object {
                producer(object)(event, objectIdentifier)
            } else {
                self.unsubscribe(objectWith: subID)
            }
        })
    }
    
    public func unsubscribe(objectWith objectIdentifier: ObjectIdentifier) {
        _unsubscribe(objectIdentifier)
    }
    
    public func filter(_ condition: @escaping (Event) -> Bool) -> SignedPublisherProxy<Event> {
        return SignedPublisherProxy<Event>(subscribe: { (identifier, handle) in
            let handler: SignedEventHandler<Event> = { event in
                if condition(event.0) { handle(event.0, event.1) }
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe)
    }
    
    public func map<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent) -> SignedPublisherProxy<OtherEvent> {
        return SignedPublisherProxy<OtherEvent>(subscribe: { (identifier, handle) in
            let handler: SignedEventHandler<Event> = { event in
                handle(transform(event.0), event.1)
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe)
    }
    
    public func flatMap<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent?) -> SignedPublisherProxy<OtherEvent> {
        return SignedPublisherProxy<OtherEvent>(subscribe: { (identifier, handle) in
            let handler: SignedEventHandler<Event> = { event in
                if let transformed = transform(event.0) { handle(transformed, event.1) }
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe)
    }
    
    public func redirect<Pub : SignedPublisher>(to publisher: Pub) where Pub.Event == Event {
        subscribe(publisher, with: Pub.publish)
    }
    
}

public extension Publisher {
    
    var proxy: PublisherProxy<Event> {
        return PublisherProxy(self)
    }
    
}

public extension SignedPublisher {
    
    var proxy: SignedPublisherProxy<Event> {
        return SignedPublisherProxy(self)
    }
    
}
