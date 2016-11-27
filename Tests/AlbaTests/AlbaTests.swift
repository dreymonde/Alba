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
import Alba

class AlbaTests: XCTestCase {
    
    func testSimplest() {
        let pub = BasicPublisher<Int>()
        let expectation = self.expectation(description: "On Sub")
        let sub = BasicListener(subscribingTo: pub) { number in
            XCTAssertEqual(number, 5)
            expectation.fulfill()
        }
        print(sub)
        pub.publish(5)
        waitForExpectations(timeout: 5.0)
    }
    
    func testSigned() {
        let pub = BasicSignedPublisher<Int>()
        let expectation = self.expectation(description: "On sub")
        let sub = BasicSignedListener(subscribingTo: pub) { (number, _) in
            if number == 5 {
                XCTFail()
            }
            if number == 7 {
                expectation.fulfill()
            }
        }
        print(sub)
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
        let pub = BasicPublisher<Int>()
        let spub = BasicSignedPublisher<Int>()
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
        let pub = BasicPublisher<Int>()
        let spub = BasicSignedPublisher<Int>()
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
        let pub = BasicPublisher<Int>()
        let pospub = pub.proxy.filter({ $0 > 0 })
        let expectation = self.expectation(description: "on sub")
        let sub = BasicListener<Int>(subscribingTo: pospub) { number in
            XCTAssertTrue(number > 0)
            if number == 10 { expectation.fulfill() }
        }
        print(sub)
        [-1, -3, 5, 7, 9, 4, 3, -2, 0, 10].forEach(pub.publish)
        waitForExpectations(timeout: 5.0)
    }
    
    func testMap() {
        let pub = BasicPublisher<Int>()
        let strpub = pub.proxy.map(String.init)
        let expectation = self.expectation(description: "onsub")
        let sub = BasicListener<String>(subscribingTo: strpub) { string in
            debugPrint(string)
            if string == "10" { expectation.fulfill() }
        }
        print(sub)
        [-1, 2, 3, 9, 7, 4, 2, 57, 10].forEach(pub.publish)
        waitForExpectations(timeout: 5.0)
    }
    
    func testFlatMap() {
        let pub = BasicPublisher<String>()
        let intpub = pub.proxy.flatMap({ Int($0) })
        let expectation = self.expectation(description: "onsub")
        let sub = BasicListener<Int>(subscribingTo: intpub) { int in
            if int == 10 { expectation.fulfill() }
        }
        print(sub)
        ["Abba", "Babbaa", "-7", "3", "10"].forEach(pub.publish)
        waitForExpectations(timeout: 5.0)
    }
    
    func testObservable() {
        var obsInt = Observable(5)
        let expectation = self.expectation(description: "onsub")
        var str = ""
        let sub = BasicListener<Int>(subscribingTo: obsInt.proxy) {
            int in
            str.append(String(int))
            if int == 10 { expectation.fulfill() }
        }
        print(sub)
        [1, 2, 3, 4, -4, 100, 10].forEach({ obsInt.value = $0 })
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(str, "1234-410010")
    }
    
    func testRedirect() {
        let pubOne = BasicPublisher<Int>()
        let pubTwo = BasicPublisher<String>()
        let expectation = self.expectation(description: "onsubtwo")
        pubOne.proxy
            .map({ $0 - 1 })
            .map(String.init)
            .redirect(to: pubTwo)
        let subTwo = BasicListener<String>(subscribingTo: pubTwo) { number in
            debugPrint(number)
            if number == "10" { expectation.fulfill() }
        }
        print(subTwo)
        pubOne.publish(3)
        pubOne.publish(5)
        pubOne.publish(11)
        waitForExpectations(timeout: 5.0)
    }
    
}