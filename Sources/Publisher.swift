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
    
    associatedtype Event
    
    var proxy: PublisherProxy<Event> { get }
    
}

public protocol PublisherProtocol : class, Subscribable {
        
    associatedtype Event
    
    var label: String { get }
    
    var subscribers: [ObjectIdentifier : EventHandler<Event>] { get set }
    
    func publish(_ event: Event)
    
}

public extension PublisherProtocol {
    
    var proxy: PublisherProxy<Event> {
        return PublisherProxy(subscribe: { self.subscribers[$0] = $1 },
                              unsubscribe: { self.subscribers[$0] = nil })
    }
    
}

public extension PublisherProtocol {
    
    func publish(_ event: Event) {
        subscribers.values.forEach({ handle in handle(event) })
    }
    
}

public class Publisher<Event> : PublisherProtocol {
    
    public var subscribers: [ObjectIdentifier : EventHandler<Event>] = [:]
    
    internal var names: [ObjectIdentifier : String] = [:]
    
    public var label: String
    
    public init(label: String = "unnamed") {
        self.proxy = PublisherProxy.empty()
        let initialPayload = ProxyPayload.empty.adding(entry: .publisherLabel("\(String.init(describing: Publisher<Event>.self)):\(label)"))
        self.label = label
        self.proxy = PublisherProxy(subscribe: { self.subscribers[$0] = $1 },
                                    unsubscribe: { self.subscribers[$0] = nil },
                                    payload: initialPayload,
                                    submitName: { self.assignName($0.1, toObjectWith: $0.0) })
    }
    
    public private(set) var proxy: PublisherProxy<Event>
    
    public func publish(_ event: Event) {
        if !InformBureau.isEnabled {
            subscribers.values.forEach({ handle in handle(event) })
        } else {
            var payload = PublishingPayload.empty
            payload.entries.append(.published(publisherLabel: "\(self):\(label)", event: "\(event)"))
            subscribers.forEach { identifier, handle in
                handle(event)
                if let name = names[identifier] {
                    payload.entries.append(PublishingPayload.Entry.handled(handlerLabel: name))
                }
            }
            InformBureau.submitPublishing(payload)
        }
    }
    
}

public struct PublishingPayload : InformBureauPayload {
    
    public enum Entry {
        case published(publisherLabel: String, event: String)
        case handled(handlerLabel: String)
    }
    
    public var entries: [Entry]
    
    public init(entries: [Entry]) {
        self.entries = entries
    }
    
}

internal extension Publisher {
    
    func assignName(_ name: String, toObjectWith identifier: ObjectIdentifier) {
        if InformBureau.isEnabled {
            names[identifier] = name
        }
    }
    
}

public typealias SignedPublisher<Event> = Publisher<Signed<Event>>

public extension Publisher where Event : SignedProtocol {
    
    func publish(_ event: Event.Wrapped, submitterIdentifier: ObjectIdentifier?) {
        let signed = Signed<Event.Wrapped>(event, submitterIdentifier)
        self.publish(.init(signed))
    }
    
    func publish(_ event: Event.Wrapped, submittedBy submitter: AnyObject?) {
        publish(event, submitterIdentifier: submitter.map(ObjectIdentifier.init))
    }
    
}
