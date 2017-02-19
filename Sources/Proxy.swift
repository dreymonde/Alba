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
        case merged(otherPayload: ProxyPayload)
    }
    
    public var entries: [Entry]
    
    public init(entries: [Entry]) {
        self.entries = entries
    }
    
}

public struct PublisherProxy<Event> {
    
    fileprivate let _subscribe: (ObjectIdentifier, @escaping EventHandler<Event>) -> ()
    fileprivate let _unsubscribe: (ObjectIdentifier) -> ()
    internal let payload: ProxyPayload
    internal let _submitName: (ObjectIdentifier, String) -> ()
    
    public init(subscribe: @escaping (ObjectIdentifier, @escaping EventHandler<Event>) -> (),
                unsubscribe: @escaping (ObjectIdentifier) -> ()) {
        self._subscribe = subscribe
        self._unsubscribe = unsubscribe
        self.payload = .empty
        self._submitName = { _ in }
    }
    
    internal init(subscribe: @escaping (ObjectIdentifier, @escaping EventHandler<Event>) -> (),
                  unsubscribe: @escaping (ObjectIdentifier) -> (),
                  payload: ProxyPayload,
                  submitName: @escaping (ObjectIdentifier, String) -> ()) {
        self._subscribe = subscribe
        self._unsubscribe = unsubscribe
        self.payload = payload
        self._submitName = submitName
    }
    
//    public var signed: SignedPublisherProxy<Event> {
//        return SignedPublisherProxy<Event>(subscribe: { (identifier, handler) in
//            self._subscribe(identifier, unsigned(handler))
//        }, unsubscribe: self._unsubscribe)
//    }
    
    public func subscribe<Object : AnyObject>(_ object: Object,
                          with producer: @escaping (Object) -> EventHandler<Event>) {
        let identifier = ObjectIdentifier(object)
        if InformBureau.isEnabled {
            self._submitName(identifier, "\(object):\(identifier.hashValue)")
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
    
    public func filter(_ condition: @escaping (Event) -> Bool) -> PublisherProxy<Event> {
        return PublisherProxy<Event>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                if condition(event) { handle(event) }
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe,
           payload: payload.adding(entry: .filtered),
           submitName: _submitName)
    }
    
    public func map<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent) -> PublisherProxy<OtherEvent> {
        return PublisherProxy<OtherEvent>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                handle(transform(event))
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe,
           payload: payload.adding(entry: .mapped(fromType: String.init(describing: Event.self),
                                                  toType: String.init(describing: OtherEvent.self))),
           submitName: _submitName)
    }
    
    public func flatMap<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent?) -> PublisherProxy<OtherEvent> {
        return PublisherProxy<OtherEvent>(subscribe: { (identifier, handle) in
            let handler: EventHandler<Event> = { event in
                if let transformed = transform(event) { handle(transformed) }
            }
            self._subscribe(identifier, handler)
        }, unsubscribe: self._unsubscribe,
           payload: payload.adding(entry: .mapped(fromType: String.init(describing: Event.self),
                                                  toType: String.init(describing: OtherEvent.self))),
           submitName: _submitName)
    }
    
    public func interrupted(with work: @escaping (Event) -> ()) -> PublisherProxy<Event> {
        return PublisherProxy<Event>(subscribe: { (identifier, handle) in
            self._subscribe(identifier, { work($0); handle($0) })
        }, unsubscribe: self._unsubscribe,
           payload: payload.adding(entry: .interrupted),
           submitName: _submitName)
    }
    
    public func merged(with other: PublisherProxy<Event>) -> PublisherProxy<Event> {
        return PublisherProxy<Event>(subscribe: { (identifier, handle) in
            self._subscribe(identifier, handle)
            other._subscribe(identifier, handle)
        }, unsubscribe: { (identifier) in
            self._unsubscribe(identifier)
            other._unsubscribe(identifier)
        }, payload: payload.adding(entry: .merged(otherPayload: other.payload)),
           submitName: { (identifier, label) in
            self._submitName(identifier, label)
            other._submitName(identifier, label)
        })
    }
    
    public func redirect<Publisher : PublisherProtocol>(to publisher: Publisher) where Publisher.Event == Event {
        if InformBureau.isEnabled {
            InformBureau.submitSubscription(payload.adding(entry: .redirected(to: "\(String.init(describing: Publisher.self)):\(publisher.label)")))
        }
        subscribe(publisher, with: Publisher.publish)
    }
    
    public func listen(with handler: @escaping EventHandler<Event>) {
        let listener = NotGoingBasicListener<Event>(subscribingTo: self, handler)
        let identifier = ObjectIdentifier(listener)
        if InformBureau.isEnabled {
            self._submitName(identifier, "Listener<\(Event.self)>:\(identifier.hashValue)")
            InformBureau.submitSubscription(payload.adding(entry: .listened(eventType: String.init(describing: Event.self))))
        }
    }
    
    public func void() -> PublisherProxy<Void> {
        return map({ _ in })
    }
    
    public var unsafe: UnsafePublisherProxy<Event> {
        return UnsafePublisherProxy(proxy: self)
    }
    
}

public struct UnsafePublisherProxy<Event> {
    
    fileprivate let proxy: PublisherProxy<Event>
    
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

public extension PublisherProxy where Event : SignedProtocol {
    
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
    
    func filterValue(_ condition: @escaping (Event.Wrapped) -> Bool) -> PublisherProxy<Event> {
        return filter({ condition($0.value) })
    }
    
    func mapValue<OtherEvent>(_ transform: @escaping (Event.Wrapped) -> OtherEvent) -> PublisherProxy<Signed<OtherEvent>> {
        return map({ (event) in
            let transformed = transform(event.value)
            let signed = Signed.init(transformed, event.submittedBy)
            return signed
        })
    }
    
    func flatMapValue<OtherEvent>(_ transform: @escaping (Event.Wrapped) -> OtherEvent?) -> PublisherProxy<Signed<OtherEvent>> {
        return flatMap({ (event) in
            let transformed = transform(event.value)
            let signed = transformed.map({ Signed.init($0, event.submittedBy) })
            return signed
        })
    }
    
    var unsigned: PublisherProxy<Event.Wrapped> {
        return self.map({ $0.value })
    }
    
}

public extension PublisherProxy {
    
    static func empty() -> PublisherProxy<Event> {
        let payload = ProxyPayload.empty.adding(entry: .publisherLabel("WARNING: Empty proxy"))
        return PublisherProxy<Event>(subscribe: { _ in },
                                     unsubscribe: { _ in },
                                     payload: payload,
                                     submitName: { _ in })
    }
    
}

public typealias SignedPublisherProxy<Event> = PublisherProxy<Signed<Event>>
