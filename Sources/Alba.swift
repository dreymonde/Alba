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

// Alba - stateful event observing engine

public typealias EventHandler<Event> = (Event) -> ()

public struct _Wrapper<Value, Field> {
    public var value: Value
    public var field: Field
    
    public func map<T>(_ transform: (Value) -> T) -> _Wrapper<T, Field> {
        return _Wrapper<T, Field>(value: transform(self.value), field: self.field)
    }
    
}

public protocol Wrapper {
    
    associatedtype Wrapped
    associatedtype Field
    
    var value: Wrapped { get set }
    
    func _wrapper() -> _Wrapper<Wrapped, Field>
    init(_wrapper: _Wrapper<Wrapped, Field>)
    
}
