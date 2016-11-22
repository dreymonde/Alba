# Alba

**Alba** is a tiny yet powerful library which allows you to create sophisticated, decoupled and complex architecture using functional-reactive paradigms. **Alba** is designed to work mostly with reference semantics instances (classes).

## Usage

### Publishers

```swift
final class UUIDSubmitter : Publisher {
    typealias Event = UUID
    var subscribers: [ObjectIdentifier : (UUID) -> ()] = [:]
}

let submitter = UUIDSubmitter()
submitter.publish(UUID())

//or

let publisher = BasicPublisher<UUID>()
publisher.publish(UUID())
```

### Subscribing

You should subscribe using so-called "publisher proxy". They are eas to inject and handy to use:

```swift
final class Listener {
    
    let publisher: PublisherProxy<UUID>
    
    init(publisher: PublisherProxy<UUID>) {
        self.publisher = publisher
        publisher.subscribe(self, with: { [unowned self] in self.didReceive(uuid: $0) })
    }
    
    deinit {
        publisher.unsubscribe(self)
    }
    
    func didReceive(uuid: UUID) {
        print(uuid)
    }
    
}
```

You should use `unowned` (or `weak`, if you prefer) here because otherwise you will get reference cycle, and you should _unsubscribe_ manually (especially when using `unowned` -- you will get runtime error otherwise).

If you don't want to do that manually, you can use **Alba**'s handy functionality for that:

```swift
final class Listener {
    
    init(publisher: PublisherProxy<UUID>) {
        publisher.subscribe(self, with: Listener.didReceive)
    }
    
    func didReceive(uuid: UUID) {
        print(uuid)
    }
    
}
```

Thanks to the power of generics, this will automatically subscribe as `weak` and unsubscribe after the object is gone. And you can also get rid of that `publisher` stored property!

##### That functional things

The cool thing about publisher proxies is the ability to do interesting things on them, for example, filter and map:

```swift
final class Listener {
    
    init(publisher: PublisherProxy<String>) {
        publisher
            .flatMap({ Int($0) })
            .filter({ $0 > 0 })
            .subscribe(self, with: Listener.didReceive)
    }
    
    func didReceive(positiveNumber: Int) {
        print(positiveNumber)
    }
    
}

let listener = Listener2(publisher: BasicPublisher<String>().proxy)
```

Cool, huh?

##### Lightweight listeners

```swift
let publisher = BasicPublisher<Int>()
let listener = BasicListener<Int>(subscribingTo: publisher) { number in
    print(number)
}
publisher.publish(10)
```

### Observables

`Observable` is just a simple wrapper around a value with an embedded publisher. You can observe its changes using publicly available `proxy`:

```swift
final class State {
    var number: Observable<Int> = Observable(5)
    var isActive = Observable(false)    
}

let state = State()
state.number.proxy.subscribe( ... )
```

### Signed events

**Alba** also gives you the ability to publish *signed* events. Signed events doesn't notify its _submitter_. For example:

```swift
enum Alba {
    case v
    case y
    case t
}

final class AlbaController {
    
    private let publisher = BasicSignedPublisher<Alba>()
    let alba: SignedPublisherProxy<Alba>
    
    init() {
        self.alba = publisher.proxy
    }
    
    func submit(_ alba: Alba, by submitter: AnyObject?) {
        publisher.publish(alba, submittedBy: submitter)
    }
    
}

final class Component {
    
    init(albaPublisher: SignedPublisherProxy<Alba>) {
        albaPublisher.subscribe(self, with: Component.didReceive)
    }
    
    func didReceive(alba: Alba, submitter: ObjectIdentifier?) {
        print(alba)
    }
    
}

let controller = AlbaController()
let component = Component(albaPublisher: controller.alba)
// component will be notified:
controller.submit(.v, by: nil)
// controller won't be notified:
controller.submit(.t, by: component)
```

"Signed" APIs are mostly the same -- just add `Signed` before (`SignedPublisher`, `BasicSignedPublisher`, `BasicSignedListener`, `SignedPublisherProxy` ...). You can also drop signed thing from proxy using `.unsigned` property:

```swift
let signed = BasicSignedPublisher<Int>()
let unsignedProxy = signed.proxy.unsigned
```
