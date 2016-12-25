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

public class BasicListener<Event> {
    
    public let publisher: PublisherProxy<Event>
    public let handler: EventHandler<Event>
    
    public init(subscribingTo publisher: PublisherProxy<Event>,
                _ handler: @escaping EventHandler<Event>) {
        self.publisher = publisher
        self.handler = handler
        publisher.subscribe(self, with: handler)
    }
    
    public init<Pub : PublisherProtocol>(subscribingTo publisher: Pub,
                _ handler: @escaping EventHandler<Event>) where Pub.Event == Event {
        self.publisher = publisher.proxy
        self.handler = handler
        self.publisher.subscribe(self, with: handler)
    }
    
    deinit {
        publisher.unsubscribe(self)
    }
    
}

public class BasicSignedListener<Event> {
    
    public let publisher: SignedPublisherProxy<Event>
    public let handler: SignedEventHandler<Event>
    
    public init(subscribingTo publisher: SignedPublisherProxy<Event>,
                _ handler: @escaping SignedEventHandler<Event>) {
        self.publisher = publisher
        self.handler = handler
        publisher.subscribe(self, with: handler)
    }
    
    public init<Pub : SignedPublisherProtocol>(subscribingTo publisher: Pub,
                _ handler: @escaping SignedEventHandler<Event>) where Pub.Event == Event {
        self.publisher = publisher.proxy
        self.handler = handler
        self.publisher.subscribe(self, with: handler)
    }
    
    deinit {
        publisher.unsubscribe(self)
    }
    
}

internal class NotGoingBasicListener<Event> {
    
    let publisher: PublisherProxy<Event>
    let handler: EventHandler<Event>
    
    init(subscribingTo publisher: PublisherProxy<Event>,
         _ handler: @escaping EventHandler<Event>) {
        self.publisher = publisher
        self.handler = handler
        publisher.subscribe(self, with: self.handle)
    }
    
    init<Pub : PublisherProtocol>(subscribingTo publisher: Pub,
         _ handler: @escaping EventHandler<Event>) where Pub.Event == Event {
        self.publisher = publisher.proxy
        self.handler = handler
        self.publisher.subscribe(self, with: self.handle)
    }
    
    func handle(_ event: Event) {
        self.handler(event)
    }
    
    deinit {
        publisher.unsubscribe(self)
    }
    
}

internal class NotGoingBasicSignedListener<Event> {
    
    let publisher: SignedPublisherProxy<Event>
    let handler: SignedEventHandler<Event>
    
    init(subscribingTo publisher: SignedPublisherProxy<Event>,
         _ handler: @escaping SignedEventHandler<Event>) {
        self.publisher = publisher
        self.handler = handler
        publisher.subscribe(self, with: self.handle)
    }
    
    init<Pub : SignedPublisherProtocol>(subscribingTo publisher: Pub,
         _ handler: @escaping SignedEventHandler<Event>) where Pub.Event == Event {
        self.publisher = publisher.proxy
        self.handler = handler
        self.publisher.subscribe(self, with: self.handle)
    }
    
    func handle(_ event: Event, identifier: ObjectIdentifier?) {
        self.handler(event, identifier)
    }
    
    deinit {
        publisher.unsubscribe(self)
    }
    
}

