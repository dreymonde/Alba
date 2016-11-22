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

public protocol Publisher : class, Subscribable {
    
    typealias Subscription = EventHandler<Event>
    
    associatedtype Event
    
    var subscribers: [ObjectIdentifier : EventHandler<Event>] { get set }
    
    func publish(_ event: Event)
    
}

public extension Publisher {
    
    func publish(_ event: Event) {
        subscribers.values.forEach({ handle in handle(event) })
    }
    
}

public protocol SignedPublisher : class, Subscribable {
    
    typealias Subscription = SignedEventHandler<Event>
    
    associatedtype Event
    
    var subscribers: [ObjectIdentifier : SignedEventHandler<Event>] { get set }
    
    func publish(_ event: Event, submitterIdentifier: ObjectIdentifier?)
    
}

public extension SignedPublisher {
    
    func publish(_ event: Event, submitterIdentifier: ObjectIdentifier?) {
        subscribers.forEach { (subcriberIdentifier, handler) in
            if subcriberIdentifier != submitterIdentifier {
                handler(event, submitterIdentifier)
            }
        }
    }
    
    func publish(_ event: Event, submittedBy submitter: AnyObject?) {
        publish(event, submitterIdentifier: submitter.map(ObjectIdentifier.init))
    }
        
}

public class BasicPublisher<Event> : Publisher {
    
    public var subscribers: [ObjectIdentifier : EventHandler<Event>] = [:]
    
    public init() { }
    
}

public class BasicSignedPublisher<Event> : SignedPublisher {
    
    public var subscribers: [ObjectIdentifier : SignedEventHandler<Event>] = [:]

    public init() { }
    
}
