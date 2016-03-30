//
//  ViewController.swift
//  ADHelloOpenGL2
//
//  Created by duanhongjin on 16/3/30.
//  Copyright © 2016年 duanhongjin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let openGLView: ADOpenGLView = ADOpenGLView(frame: self.view.bounds)
        openGLView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.view.addSubview(openGLView)
    }

}

