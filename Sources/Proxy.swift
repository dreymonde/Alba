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

public struct ProxyPayload : InformBureauPayload {
    
    public enum Entry {
        case publisherLabel(String)
        case mapped(fromType: String, toType: String)
        case filtered
        case interrupted
        case redirected(to: String)
        case subscribed(identifier: ObjectIdentifier, ofType: String)
        case listened(eventType: String)
    }
    
    public var entries: [Entry]
    
    public init(entries: [Entry]) {
        self.entries = entries
    }
    
}

public struct Subscribe<Event> {
    
    fileprivate let _subscribe: (ObjectIdentifier, @escaping EventHandler<Event>) -> ()
    fileprivate let _unsubscribe: (ObjectIdentifier) -> ()
    internal let payload: ProxyPayload
    
    public init(subscribe: @escaping (ObjectIdentifier, @escaping EventHandler<Event>) -> (),
                unsubscribe: @escaping (ObjectIdentifier) -> (),
                label: String = "unnnamed") {
        self._subscribe = subscribe
        self._unsubscribe = unsubscribe
        self.payload = ProxyPayload.empty.adding(entry: .publisherLabel(label))
    }
    
    internal init(subscribe: @escaping (ObjectIdentifier, @escaping EventHandler<Event>) -> (),
                  unsubscribe: @escaping (ObjectIdentifier) -> (),
                  payload: ProxyPayload) {
        self._subscribe = subscribe
        self._unsubscribe = unsubscribe
        self.payload = payload
    }
    
//    public var signed: SignedSubscribe<Event> {
//        return SignedSubscribe<Event>(subscribe: { (identifier, handler) in
//            self._subscribe(identifier, unsigned(handler))
//        }, unsubscribe: self._unsubscribe)
//    }
    
    public func subscribe<Object : AnyObject>(_ object: Object,
                          with producer: @escaping (Object) -> EventHandler<Event>) {
        let identifier = ObjectIdentifier(object)
        if InformBureau.isEnabled {
            InformBureau.submitSubscription(payload.adding(entry: .subscribed(identifier: identifier, ofType: String(describing: Object.self))))
        }
        self._subscribe(identifier, { [weak object] in
            if let object = object {
                producer(object)($0)
            } else {
                self._unsubscribe(identifier)
            }
        })
    }
    
    public func filter(_ condition: @escaping (Event) -> Bool) -> Subscribe<Event> {
        return Subscribe<Event>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                if condition(event) { handle(event) }
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe,
           payload: payload.adding(entry: .filtered))
    }
    
    public func map<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent) -> Subscribe<OtherEvent> {
        return Subscribe<OtherEvent>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                handle(transform(event))
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe,
           payload: payload.adding(entry: .mapped(fromType: String.init(describing: Event.self),
                                                  toType: String.init(describing: OtherEvent.self))))
    }
    
    public func flatMap<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent?) -> Subscribe<OtherEvent> {
        return Subscribe<OtherEvent>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                if let transformed = transform(event) { handle(transformed) }
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe,
           payload: payload.adding(entry: .mapped(fromType: String.init(describing: Event.self),
                                                  toType: String.init(describing: OtherEvent.self))))
    }
    
    public func interrupted(with work: @escaping (Event) -> ()) -> Subscribe<Event> {
        return Subscribe<Event>(subscribe: { (identifier, handle) in
            self._subscribe(identifier, { work($0); handle($0) })
        }, unsubscribe: self._unsubscribe,
           payload: payload.adding(entry: .interrupted))
    }
    
    public func redirect<Publisher : PublisherProtocol>(to publisher: Publisher) where Publisher.Event == Event {
        if InformBureau.isEnabled {
            InformBureau.submitSubscription(payload.adding(entry: .redirected(to: "\(String.init(describing: Publisher.self)):\(publisher.label)")))
        }
        subscribe(publisher, with: Publisher.publish)
    }
    
    public func listen(with handler: @escaping EventHandler<Event>) {
        let listener = NotGoingBasicListener<Event>(subscribingTo: self, handler)
        if InformBureau.isEnabled {
            InformBureau.submitSubscription(payload.adding(entry: .listened(eventType: String.init(describing: Event.self))))
        }
    }
    
    public func void() -> Subscribe<Void> {
        return map({ _ in })
    }
    
    public var unsafe: UnsafeSubscribe<Event> {
        return UnsafeSubscribe(proxy: self)
    }
    
}

public struct UnsafeSubscribe<Event> {
    
    fileprivate let proxy: Subscribe<Event>
    
    public func subscribe(_ object: AnyObject, with subscription: @escaping EventHandler<Event>) {
        let identifier = ObjectIdentifier(object)
        proxy._subscribe(identifier, subscription)
    }
    
    public func unsubscribe(_ object: AnyObject) {
        let identifier = ObjectIdentifier(object)
        proxy._unsubscribe(identifier)
    }
    
    public func subscribe(objectWith objectIdentifier: ObjectIdentifier,
                          with handler: @escaping EventHandler<Event>) {
        proxy._subscribe(objectIdentifier, handler)
    }
    
    public func unsubscribe(objectWith objectIdentifier: ObjectIdentifier) {
        proxy._unsubscribe(objectIdentifier)
    }
    
}

public extension Subscribe where Event : SignedProtocol {
    
    public func subscribe<Object : AnyObject>(_ object: Object,
                          with producer: @escaping (Object) -> EventHandler<(Event.Wrapped, submitterIdentifier: ObjectIdentifier?)>) {
        let identifier = ObjectIdentifier(object)
        self._subscribe(identifier, { [weak object] event in
            if let object = object {
                let handler = producer(object)
                handler((event.value, event.submittedBy))
            } else {
                self._unsubscribe(identifier)
            }
        })
    }
    
    public func subscribe<Object : AnyObject>(_ object: Object,
                          with producer: @escaping (Object) -> EventHandler<(Event.Wrapped, submittedBySelf: Bool)>) {
        let identifier = ObjectIdentifier(object)
        self._subscribe(identifier, { [weak object] event in
            if let object = object {
                let handler = producer(object)
                handler((event.value, event.submittedBy == identifier))
            } else {
                self._unsubscribe(identifier)
            }
        })
    }
    
    func filterValue(_ condition: @escaping (Event.Wrapped) -> Bool) -> Subscribe<Event> {
        return filter({ condition($0.value) })
    }
    
    func mapValue<OtherEvent>(_ transform: @escaping (Event.Wrapped) -> OtherEvent) -> Subscribe<Signed<OtherEvent>> {
        return map({ (event) in
            let transformed = transform(event.value)
            let signed = Signed.init(transformed, event.submittedBy)
            return signed
        })
    }
    
    func flatMapValue<OtherEvent>(_ transform: @escaping (Event.Wrapped) -> OtherEvent?) -> Subscribe<Signed<OtherEvent>> {
        return flatMap({ (event) in
            let transformed = transform(event.value)
            let signed = transformed.map({ Signed.init($0, event.submittedBy) })
            return signed
        })
    }
    
    var unsigned: Subscribe<Event.Wrapped> {
        return self.map({ $0.value })
    }
    
}

public extension Subscribe {
    
    static func empty() -> Subscribe<Event> {
        let payload = ProxyPayload.empty.adding(entry: .publisherLabel("WARNING: Empty proxy"))
        return Subscribe<Event>(subscribe: { _ in },
                                     unsubscribe: { _ in },
                                     payload: payload)
    }
    
}

public typealias SignedSubscribe<Event> = Subscribe<Signed<Event>>
