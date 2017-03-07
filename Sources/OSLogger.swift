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
import os.log

@available(watchOSApplicationExtension 3.0, *)
@available(tvOSApplicationExtension 10.0, *)
@available(iOSApplicationExtension 10.0, *)
@available(OSXApplicationExtension 10.12, *)
public final class OSLogger {
    
    static let shared = OSLogger()
    
    private init() { }
    
    public static func enable() {
        InformBureau.didSubscribe.subscribe(shared, with: OSLogger.logSub)
        InformBureau.didPublish.subscribe(shared, with: OSLogger.logPub)
    }
    
    public static func disable() {
        InformBureau.didSubscribe.unsafe.unsubscribe(shared)
        InformBureau.didPublish.unsafe.unsubscribe(shared)
    }
    
    let subLog = OSLog(subsystem: "com.alba.alba", category: "subscriptions")
    
    func logSub(_ logMessage: InformBureau.SubscriptionLogMessage) {
        var publisherLabel: (String, Any.Type)?
        var subscription: (ProxyPayload.Entry.Subscription)?
        for entry in logMessage.entries {
            switch entry {
            case .publisherLabel(let info):
                publisherLabel = info
            case .subscription(let info):
                subscription = info
            default:
                continue
            }
        }
        if let publisherLabel = publisherLabel, let subscription = subscription {
            switch subscription {
            case .byObject(identifier: let identifier, ofType: let type):
                os_log("%@ (%@) subscribed by %@:%@",
                       log: subLog,
                       type: .debug,
                       publisherLabel.0 as NSString,
                       String(describing: publisherLabel.1) as NSString,
                       String(describing: type) as NSString,
                       identifier.hashValue as NSNumber)
            case .redirection(to: let label, ofType: let type):
                os_log("%@ (%@) redirected to %@ (%@)",
                       log: subLog,
                       type: .debug,
                       publisherLabel.0 as NSString,
                       String(describing: publisherLabel.1) as NSString,
                       label as NSString,
                       String(describing: type) as NSString)
            default:
                print("Unsupported yet")
            }
        }
    }
    
    let pubLog = OSLog(subsystem: "com.alba.alba", category: "publications")
    
    func logPub(_ logMessage: InformBureau.PublishingLogMessage) {
        for entry in logMessage.entries {
            switch entry {
            case .published(publisherLabel: let label, publisherType: let type, event: let event):
                os_log("%@ (%@) published %@",
                       log: pubLog,
                       type: .info,
                       label as NSString,
                       String(describing: type) as NSString,
                       (event as? NSObject) ?? String(describing: event) as NSString)
            default:
                break
            }
        }
    }
    
}
