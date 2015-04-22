//
//  AsyncHTTPSRequest.swift
//  magnifier2
//
//  Created by mulligans on 21/04/2015.
//  Copyright (c) 2015 mulligans. All rights reserved.
//

import Cocoa
import AppKit

class AsyncHTTPSRequest: NSObject {
    
    func getRequest(URL: String){
        var urlString = "http://api.shephertz.com" // Your Normal URL String
        var url = NSURL(string: urlString)
        var request = NSURLRequest(URL: url!)// Creating Http Request
        var textToSpeech = NSSpeechSynthesizer()
        
        // Creating NSOperationQueue to which the handler block is dispatched when the request completes or failed
        var queue: NSOperationQueue = NSOperationQueue()
        
        // Sending Asynchronous request using NSURLConnection
        NSURLConnection.sendAsynchronousRequest(request, queue: queue, completionHandler:{ (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void in
            /* Your code */
            if (error != nil){
               println(error.description)
               textToSpeech.startSpeakingString(error.description)
            } else {
                //Converting data to String
                var responseStr:NSString = NSString(data: data, encoding:    NSUTF8StringEncoding)!
                println(responseStr)
                textToSpeech.startSpeakingString(responseStr as String)
            }
        })
    }
}
