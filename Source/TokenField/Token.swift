//
//  Token.swift
//  iCook
//
//  Created by Ben on 03/03/2016.
//  Copyright © 2016 Polydice, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

internal class Token: UIView {

  var text = "" {
    didSet {
      updateTextLabel()
      frame = CGRect(origin: CGPoint.zero, size: systemLayoutSizeFitting(UILayoutFittingCompressedSize))
    }
  }

  var isHighlighted = false {
    didSet {
      updateTextLabel()
    }
  }

  var normalTextAttributes: [NSAttributedStringKey: NSObject] = [
    .foregroundColor: UIColor(red: 0.14, green: 0.38, blue: 0.95, alpha: 1),
    .backgroundColor: UIColor.clear
  ] {
    didSet {
      if !isHighlighted { updateTextLabel() }
      delimiterLabel.textColor = self.normalTextAttributes[.foregroundColor] as? UIColor
    }
  }

  var highlightedTextAttributes: [NSAttributedStringKey: NSObject] = [
    .foregroundColor: UIColor.white,
    .backgroundColor: UIColor(red: 0.14, green: 0.38, blue: 0.95, alpha: 1)
  ] {
    didSet {
      if isHighlighted { updateTextLabel() }
    }
  }

  var cornerRadiusConstant: InsetLabel.CornerRadius = .constant(3) {
    didSet {
      if isHighlighted { updateTextLabel() }
    }
  }

  // MARK: - Private Properties

  private(set) lazy var delimiterLabel: UILabel = {
    let _label = UILabel()
    _label.textColor = self.normalTextAttributes[.foregroundColor] as? UIColor
    _label.textAlignment = .right
    return _label
  }()

  private(set) lazy var textLabel: UILabel = {
    let _label = InsetLabel(contentEdgeInsets: UIEdgeInsets(top: 3, left: 5, bottom: 3, right: 5), cornerRadius: cornerRadiusConstant)
    _label.textAlignment = .center
    _label.textColor = self.normalTextAttributes[.foregroundColor] as? UIColor
    _label.backgroundColor = self.normalTextAttributes[.backgroundColor] as? UIColor
    _label.numberOfLines = 1
    return _label
  }()

  // MARK: - Initialization

  override init(frame: CGRect) {
    super.init(frame: frame)
    setUpSubviews()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setUpSubviews()
  }

  convenience init(
    text: String,
    delimiter: String = ",",
    normalAttributes: [NSAttributedStringKey: NSObject]? = nil,
    highlightedAttributes: [NSAttributedStringKey: NSObject]? = nil,
    cornerRadiusConstant: CGFloat? = nil
  ) {
    self.init()
    if let attributes = normalAttributes { normalTextAttributes = attributes }
    if let attributes = highlightedAttributes { highlightedTextAttributes = attributes }
    if let attributes = cornerRadiusConstant { self.cornerRadiusConstant = .constant(attributes) }
    delimiterLabel.text = delimiter
    ({
      // Workaround to trigger didSet inside the initializer
      self.text = text
    })()
  }

  // MARK: - Private Methods

  private func updateTextLabel() {
    var attributes = isHighlighted ? highlightedTextAttributes : normalTextAttributes
    if let color = attributes[.backgroundColor] as? UIColor {
      textLabel.backgroundColor = color
    }
    // Avoid overlapped translucent background colors
    attributes[.backgroundColor] = nil
    textLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
    if let textLabel = textLabel as? InsetLabel {
      textLabel.cornerRadius = cornerRadiusConstant
    }

    delimiterLabel.textColor = normalTextAttributes[.foregroundColor] as? UIColor
    delimiterLabel.font = normalTextAttributes[.font] as? UIFont
  }

  private func setUpSubviews() {
    addSubview(textLabel)
    addSubview(delimiterLabel)
    textLabel.translatesAutoresizingMaskIntoConstraints = false
    delimiterLabel.translatesAutoresizingMaskIntoConstraints = false

    let views = [
      "text": textLabel,
      "delimiter": delimiterLabel
    ]
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[text][delimiter]-5-|",
      options: [.alignAllCenterY],
      metrics: nil,
      views: views
    ))
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-2-[text]-2-|",
      options: [],
      metrics: nil,
      views: views
    ))
  }

}
