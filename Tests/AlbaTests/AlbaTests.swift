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

import Foundation
import XCTest
@testable import Alba

var isBureauWorking = false

class AlbaTests: XCTestCase {
    
    override func setUp() {
        if !isBureauWorking {
            print("Alba Inform Bureau on")
            Alba.InformBureau.isEnabled = true
            Alba.InformBureau.enableLogger()
//            Alba.InformBureau.didPublish.listen(with: { print($0) })
            isBureauWorking = true
            print("Now working")
        }
    }
    
    func testSimplest() {
        let pub = Publisher<Int>()
        let expectation = self.expectation(description: "On Sub")
        pub.proxy.listen { (number) in
            XCTAssertEqual(number, 5)
            expectation.fulfill()
        }
        pub.publish(5)
        waitForExpectations(timeout: 5.0)
    }
    
    class SignedThing {
        
        var expectation: XCTestExpectation
        
        init(expectation: XCTestExpectation) {
            self.expectation = expectation
        }
        
        func handle(_ number: Int, submittedBySelf: Bool) {
            if submittedBySelf {
                if number == 7 {
                    XCTFail()
                }
            } else {
                if number == 5 {
                    XCTFail()
                }
                if number == 7 {
                    expectation.fulfill()
                }
            }
        }
        
    }
    
    func testSigned() {
        let pub = SignedPublisher<Int>()
        let expectation = self.expectation(description: "On sub")
        let sub = SignedThing(expectation: expectation)
        pub.proxy.subscribe(sub, with: SignedThing.handle)
        pub.publish(5, submittedBy: sub)
        pub.publish(7, submittedBy: nil)
        waitForExpectations(timeout: 5.0)
    }
    
    class SignedThing2 {
        
        var expectation: XCTestExpectation
        
        init(expectation: XCTestExpectation) {
            self.expectation = expectation
        }
        
        func handle(_ number: Int, submittedByObjectWith identifier: ObjectIdentifier?) {
            if identifier?.belongsTo(self) == true {
                if number == 7 {
                    XCTFail()
                }
            } else {
                if number == 5 {
                    XCTFail()
                }
                if number == 7 {
                    expectation.fulfill()
                }
            }
        }
        
    }
    
    func testSigned2() {
        let pub = SignedPublisher<Int>()
        let expectation = self.expectation(description: "On sub")
        let sub = SignedThing2(expectation: expectation)
        pub.proxy.subscribe(sub, with: SignedThing2.handle)
        pub.publish(5, submittedBy: sub)
        pub.publish(7, submittedBy: nil)
        waitForExpectations(timeout: 5.0)
    }
    
    class DEA {
        let proxy: PublisherProxy<Int>
        let sproxy: SignedPublisherProxy<Int>
        let deinitBlock: () -> ()
        init(proxy: PublisherProxy<Int>, sproxy: SignedPublisherProxy<Int>, signed: Bool = false, deinitBlock: @escaping () -> ()) {
            self.proxy = proxy
            self.sproxy = sproxy
            self.deinitBlock = deinitBlock
            proxy.subscribe(self, with: DEA.handle)
            if signed {
                sproxy.subscribe(self, with: DEA.handleSigned)
            } else {
                sproxy.unsigned.subscribe(self, with: DEA.handle)
            }
        }
        deinit {
            print("Dealloc")
            deinitBlock()
        }
        func handle(_ int: Int) {
            print(int)
            XCTAssertNotEqual(int, 10)
        }
        func handleSigned(_ int: Int, submitter: ObjectIdentifier?) {
            print(int)
            XCTAssertNotEqual(int, 10)
        }
    }
    
    func testDealloc() {
        let pub = Publisher<Int>()
        let spub = SignedPublisher<Int>()
        let expectation = self.expectation(description: "Deinit wait")
        var dea: DEA? = DEA.init(proxy: pub.proxy, sproxy: spub.proxy, deinitBlock: { expectation.fulfill() })
        print(dea!)
        pub.publish(5)
        spub.publish(5, submittedBy: nil)
        dea = nil
        pub.publish(10)
        spub.publish(10, submittedBy: nil)
        waitForExpectations(timeout: 5.0)
    }
    
    func testDealloc2() {
        let pub = Publisher<Int>()
        let spub = SignedPublisher<Int>()
        let expectation = self.expectation(description: "Deinit wait")
        var dea: DEA? = DEA.init(proxy: pub.proxy, sproxy: spub.proxy, signed: true, deinitBlock: { expectation.fulfill() })
        print(dea!)
        pub.publish(5)
        spub.publish(5, submittedBy: nil)
        dea = nil
        pub.publish(10)
        spub.publish(10, submittedBy: nil)
        waitForExpectations(timeout: 5.0)
    }
    
    func testFilter() {
        let pub = Publisher<Int>()
        let pospub = pub.proxy.filter({ $0 > 0 })
        let expectation = self.expectation(description: "on sub")
        pospub.listen { (number) in
            XCTAssertGreaterThan(number, 0)
            if number == 10 { expectation.fulfill() }
        }
        [-1, -3, 5, 7, 9, 4, 3, -2, 0, 10].forEach(pub.publish)
        waitForExpectations(timeout: 5.0)
    }
    
    func testMap() {
        let pub = Publisher<Int>()
        let strpub = pub.proxy.map(String.init)
        let expectation = self.expectation(description: "onsub")
        strpub.listen { (string) in
            debugPrint(string)
            if string == "10" { expectation.fulfill() }
        }
        [-1, 2, 3, 9, 7, 4, 2, 57, 10].forEach(pub.publish)
        waitForExpectations(timeout: 5.0)
    }
    
    func testFlatMap() {
        let pub = Publisher<String>()
        let intpub = pub.proxy.flatMap({ Int($0) })
        let expectation = self.expectation(description: "onsub")
        intpub.listen { (number) in
            if number == 10 { expectation.fulfill() }
        }
        ["Abba", "Babbaa", "-7", "3", "10"].forEach(pub.publish)
        waitForExpectations(timeout: 5.0)
    }
    
    func testObservable() {
        var obsInt = Observable(5)
        let expectation = self.expectation(description: "onsub")
        var str = ""
        obsInt.proxy.listen { (int) in
            str.append(String(int))
            if int == 10 { expectation.fulfill() }
        }
        [1, 2, 3, 4, -4, 100, 10].forEach({ obsInt.value = $0 })
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(str, "1234-410010")
    }
    
    func testRedirect() {
        let pubOne = Publisher<Int>()
        let pubTwo = Publisher<String>()
        let expectation = self.expectation(description: "onsubtwo")
        pubOne.proxy
            .map({ $0 - 1 })
            .map(String.init)
            .redirect(to: pubTwo)
        pubTwo.proxy.listen { (number) in
            debugPrint(number)
            if number == "10" { expectation.fulfill() }
        }
        pubOne.publish(3)
        pubOne.publish(5)
        pubOne.publish(11)
        waitForExpectations(timeout: 5.0)
    }
    
    func testIntercept() {
        let pub = Publisher<Int>()
        let expectation = self.expectation(description: "onsub")
        let proxy = pub.proxy
            .interrupted(with: {
                if $0 == 10 { expectation.fulfill() }
            })
        proxy.listen { (_) in
            print("Yay")
        }
        pub.publish(5)
        pub.publish(7)
        pub.publish(10)
        waitForExpectations(timeout: 5.0)
    }
    
    func testListen() {
        let pub = Publisher<Int>()
        let expectation = self.expectation(description: "onlis")
        pub.proxy.listen { (number) in
            if number == 10 { expectation.fulfill() }
        }
        [0, 3, 4, -1, 5, 10].forEach(pub.publish)
        waitForExpectations(timeout: 5.0)
    }
    
    func testMapValue() {
//        let signed = SignedPublisher<Int>()
//        let strsgn = signed.proxy.mapValue(String.init)
    }
    
    class Hand {
        
        func handle(_ int: Int) {
            print(int)
        }
        
    }
    
    func testBureau() {
        let hand = Hand()
        let publisher = Publisher<String>(label: "Then-What")
        publisher.proxy
            .flatMap({ Int.init($0) })
            .subscribe(hand, with: Hand.handle)
    }
    
}
