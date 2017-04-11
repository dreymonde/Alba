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

public struct WeakSubscribe<Object : AnyObject, Event> {
    
    public let proxy: Subscribe<Event>
    fileprivate let object: Object
    
    public init(proxy: Subscribe<Event>,
                object: Object) {
        self.proxy = proxy
        self.object = object
    }
        
    public func rawModify<OtherEvent>(subscribe: @escaping (Object, ObjectIdentifier, @escaping EventHandler<OtherEvent>) -> (), entry: ProxyPayload.Entry) -> WeakSubscribe<Object, OtherEvent> {
        let selfproxy = self.proxy
        let newProxy: Subscribe<OtherEvent> = selfproxy.rawModify(subscribe: { [weak object] (identifier, handle) in
            if let objecta = object {
                subscribe(objecta, identifier, handle)
            } else {
                selfproxy.unsafe.unsubscribe(objectWith: identifier)
            }
        }, entry: entry)
        return WeakSubscribe<Object, OtherEvent>(proxy: newProxy, object: object)
    }
    
    public func filter(_ condition: @escaping (Object) -> (Event) -> Bool) -> WeakSubscribe<Object, Event> {
        let sproxy = self.proxy
        return rawModify(subscribe: { (object, identifier, handle) in
            let handler: EventHandler<Event> = { [weak object] event in
                if let object = object {
                    if condition(object)(event) { handle(event) }
                } else {
                    sproxy.unsafe.unsubscribe(objectWith: identifier)
                }
            }
            sproxy.unsafe.subscribe(objectWith: identifier, with: handler)
        }, entry: .filtered)
    }
    
    public func map<OtherEvent>(_ transform: @escaping (Object) -> (Event) -> (OtherEvent)) -> WeakSubscribe<Object, OtherEvent> {
        let selfproxy = proxy
        return rawModify(subscribe: { (object, identifier, handle) in
            let handler: EventHandler<Event> = { [weak object] event in
                if let objecta = object {
                    handle(transform(objecta)(event))
                } else {
                    selfproxy.unsafe.unsubscribe(objectWith: identifier)
                }
            }
            selfproxy.unsafe.subscribe(objectWith: identifier, with: handler)
        }, entry: .mapped(fromType: Event.self, toType: OtherEvent.self))
    }
    
    public func flatMap<OtherEvent>(_ transform: @escaping (Object) -> (Event) -> (OtherEvent?)) -> WeakSubscribe<Object, OtherEvent> {
        let selfproxy = proxy
        return rawModify(subscribe: { (object, identifier, handle) in
            let handler: EventHandler<Event> = { [weak object] event in
                if let objecta = object {
                    if let transformed = transform(objecta)(event) {
                        handle(transformed)
                    }
                } else {
                    selfproxy.unsafe.unsubscribe(objectWith: identifier)
                }
            }
            selfproxy.unsafe.subscribe(objectWith: identifier, with: handler)
        }, entry: .mapped(fromType: Event.self, toType: OtherEvent.self))
    }
    
    public func subscribe(with producer: @escaping (Object) -> EventHandler<Event>) {
        proxy.subscribe(object, with: producer)
    }
    
}

public prefix func ! <T>(boolFunc: @escaping (T) -> Bool) -> ((T) -> Bool) {
    return {
        return !boolFunc($0)
    }
}
