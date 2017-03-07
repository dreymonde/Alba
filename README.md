# Alba

**Alba** is a tiny yet powerful library which allows you to create sophisticated, decoupled and complex architecture using functional-reactive paradigms. **Alba** is designed to work mostly with reference semantics instances (classes).

## Usage

#### Create publisher

```swift
let publisher = Publisher<UUID>()
publisher.publish(UUID())
```

#### Subscribing

In order to subscribe, you should use `Subscribe` instances. The easiest way to get them is by using `.proxy` property on publishers:

```swift
final class NumbersPrinter {
    
    init(numbersPublisher: Subscribe<Int>) {
        numbersPublisher.subscribe(self, with: NumbersPrinter.print)
    }
    
    func print(_ uuid: Int) {
        print(uuid)
    }
    
}

let printer = NumbersPrinter(numbersPublisher: publisher.proxy)
publisher.publish(10) // prints "10"
```

If you're surprised by how `NumbersPrinter.print` looks - that's because this allows **Alba** to do some interesting stuff with reference cycles. Check out the [implementation](https://github.com/dreymonde/Alba/blob/master/Sources/Proxy.swift#L52) for details.

#### That functional things

The cool thing about publisher proxies is the ability to do interesting things on them, for example, filter and map:

```swift
let stringPublisher = Publisher<String>()

final class Listener {
    
    init(publisher: Subscribe<String>) {
        publisher
            .flatMap({ Int($0) })
            .filter({ $0 > 0 })
            .subscribe(self, with: Listener.didReceive)
    }
    
    func didReceive(positiveNumber: Int) {
        print(positiveNumber)
    }
    
}

let listener = Listener(publisher: stringPublisher.proxy)
stringPublisher.publish("14aq") // nothing
stringPublisher.publish("-5")   // nothing
stringPublisher.publish("15")   // prints "15"
```

Cool, huh?

#### Lightweight observing

```swift
let publisher = Publisher<Int>()
publisher.proxy.listen { (number) in
    print(number)
}
publisher.publish(112) // prints "112"
```

Be careful with `listen`. Don't prefer it over `subscribe` as it can introduce memory leaks to your application.

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

### Writing your own `Subscribe` extensions

If you want to write your own `Subscribe` extensions, you should use `rawModify` method:

```swift
public func rawModify<OtherEvent>(subscribe: (ObjectIdentifier, EventHandler<OtherEvent>) -> (), entry: @autoclosure @escaping ProxyPayload.Entry) -> Subscribe<OtherEvent>
```

Here is, for example, how you can implement `map`:

```swift
public func map<OtherEvent>(_ transform: @escaping (Event) -> OtherEvent) -> Subscribe<OtherEvent> {
    return rawModify(subscribe: { (identifier, handle) in
        let handler: EventHandler<Event> = { event in
            handle(transform(event))
        }
        self._subscribe(identifier, handler)
    }, entry: .mapped(fromType: String.init(describing: Event.self),
                      toType: String.init(describing: OtherEvent.self)))
}
```

## Installation

**Alba** is available through [Carthage][carthage-url]. To install, just write into your Cartfile:

```ruby
github "AdvancedOperations/Operations" ~> 0.5.0
```

You can also use SwiftPM. Just add to your `Package.swift`:

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/Zewo/Mapper.git", majorVersion: 0, minor: 1),
    ]
)
```

## Contributing

**Alba** is in early stage of development and is opened for any ideas. If you want to contribute, you can:

- Propose idea/bugfix in issues
- Make a pull request
- Review any other pull request (very appreciated!), since no change to this project is made without a PR.

Actually, any help is welcomed! Feel free to contact us, ask questions and propose new ideas. If you don't want to raise a public issue, you can reach me at [dreymonde@me.com](mailto:dreymonde@me.com).
