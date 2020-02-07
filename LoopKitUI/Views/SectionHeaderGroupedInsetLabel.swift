//
//  SectionHeaderGroupedInsetLabel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

public class SectionHeaderGroupedInsetLabel: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        initFont()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initFont()
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        initFont()
    }

    public func initFont() {
        font = .preferredFont(forTextStyle: .title1)
        self.adjustsFontForContentSizeCategory = true
    }
    
}
