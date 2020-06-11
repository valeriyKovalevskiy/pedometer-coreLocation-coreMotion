//
//  ViewController.swift
//  test
//
//  Created by Valeriy Kovalevskiy on 6/11/20.
//  Copyright © 2020 Valeriy Kovalevskiy. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        LocationForUnity.sharedInstance.startPlugin()
    }


}

