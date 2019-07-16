//
//  TokenField.swift
//  iCook
//
//  Created by Ben on 01/03/2016.
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

/// The protocol defines the messages sent to a delegate. All the methods are optional.
@objc public protocol TokenFieldDelegate: NSObjectProtocol {
  /// Tells the delegate that editing began for the token field.
  @objc optional func tokenFieldDidBeginEditing(_ tokenField: TokenField)
  /// Tells the delegate that editing stopped for the token field.
  @objc optional func tokenFieldDidEndEditing(_ tokenField: TokenField)
  /// Tells the delegate that the token field will process the pressing of the return button.
  @objc optional func tokenFieldWillReturn(_ tokenField: TokenField)
  /// Tells the delegate the input text is changed.
  @objc optional func tokenField(_ tokenField: TokenField, didChangeInputText text: String)
  /// Asks the delegate if the text should become a token in the token field.
  @objc optional func tokenField(_ tokenField: TokenField, shouldCompleteText text: String) -> Bool
  /// Tells the delegate that the text becomes a token in the token field.
  @objc optional func tokenField(_ tokenField: TokenField, didCompleteText text: String)
  /// Tells the delegate that the token at certain index is removed from the token field.
  @objc optional func tokenField(_ tokenField: TokenField, didDeleteText text: String, atIndex index: Int)
  /// Asks the delegate for the subsequent delimiter string for a completed text in the token field.
  @objc optional func tokenField(_ tokenField: TokenField, subsequentDelimiterForCompletedText text: String) -> String
  /// Asks the delegate if it should change characters in that range
  @objc optional func tokenField(_ tokenField: TokenField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
}


/// A text field that groups input texts with delimiters.
@IBDesignable
open class TokenField: UIView, UITextFieldDelegate, BackspaceTextFieldDelegate {

  // MARK: - Public Properties

  /// The receiver's delegate.
  public weak var delegate: TokenFieldDelegate?

  /// Characters that completes a new token, defaults are whitespace and commas.
  public var delimiters = [" ", ",", "，"]

  /// Texts of each created token.
  public var texts: [String] {
    return tokens.map { $0.text }
  }

  /// The image on the left of text field.
  @IBInspectable public var icon: UIImage? {
    didSet {
      if let icon = icon {
        let imageView = UIImageView(image: icon)
        imageView.contentMode = .center
        leftView = imageView
      } else {
        leftView = nil
      }
    }
  }

  /// The text field that handles text inputs.
  /// Do not change textField's delegate, which is required to be handled by `TokenField`.
  public var textField: UITextField {
    return inputTextField
  }

  /// The placeholder with the default color and font.
  @IBInspectable public var placeholder: String? {
    get {
      return attributedPlaceholder?.string
    }
    set {
      if let text = newValue {
        attributedPlaceholder = NSAttributedString(
          string: text,
          attributes: [.foregroundColor: UIColor(red: 0.78, green: 0.78, blue: 0.80, alpha: 0.9)]
        )
      } else {
        attributedPlaceholder = nil
      }
    }
  }

  // MARK: - UI Customization

  /// The placeholder with customized attributes.
  public var attributedPlaceholder: NSAttributedString? {
    didSet {
      guard let attributedText = attributedPlaceholder else {
        placeholderLabel.text = nil
        return
      }
      placeholderLabel.attributedText = attributedText

      if placeholderLabel.superview != nil { return }
      insertSubview(placeholderLabel, belowSubview: scrollView)
      placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
      placeholderLabel.setContentHuggingPriority(UILayoutPriority(rawValue: UILayoutPriority.defaultLow.rawValue - 1), for: .horizontal)
      addConstraint(NSLayoutConstraint(item: placeholderLabel, attribute: .leading, relatedBy: .equal, toItem: scrollView, attribute: .leading, multiplier: 1, constant: 0))
      addConstraint(NSLayoutConstraint(item: placeholderLabel, attribute: .trailing, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .trailing, multiplier: 1, constant: 10))
      addConstraint(NSLayoutConstraint(item: placeholderLabel, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0))
    }
  }

  /// Customized attributes for tokens in the normal state, e.g. `.font` and `.foregroundColor`.
  public var normalTokenAttributes: [NSAttributedStringKey: NSObject]? {
    didSet {
      tokens.forEach { $0.normalTextAttributes = normalTokenAttributes ?? [:] }
    }
  }

  /// Customized attributes for tokens in the highlighted state.
  public var highlightedTokenAttributes: [NSAttributedStringKey: NSObject]? {
    didSet {
      tokens.forEach { $0.highlightedTextAttributes = normalTokenAttributes ?? [:] }
    }
  }

  /// The tint color of icon image and text field.
  open override var tintColor: UIColor! {
    didSet {
      inputTextField.tintColor = tintColor
      leftView?.tintColor = tintColor
    }
  }

  /// The text color of text field in the interface builder. Same as textField.text.
  @IBInspectable var textColor: UIColor? {
    get {
      return inputTextField.textColor
    }
    set {
      inputTextField.textColor = newValue
    }
  }

  /// The corner radius of token field in the interface builder. Same as layer.cornerRadius.
  @IBInspectable var cornerRadius: CGFloat {
    get {
      return layer.cornerRadius
    }
    set {
      layer.cornerRadius = newValue
      layer.masksToBounds = newValue > 0
    }
  }

  // MARK: - Private Properties

  private var tokens = [Token]()

  private lazy var inputTextField: BackspaceTextField = {
    let _textField = BackspaceTextField()
    _textField.backgroundColor = UIColor.clear
    _textField.clearButtonMode = .whileEditing
    _textField.autocorrectionType = .no
    _textField.returnKeyType = .search
    _textField.delegate = self
    _textField.backspaceDelegate = self
    _textField.addTarget(self, action: .togglePlaceholderIfNeeded, for: .allEditingEvents)
    return _textField
  }()

  private var leftView: UIView? {
    didSet {
      oldValue?.removeFromSuperview()
      leftEdgeConstraint.isActive = leftView == nil
      if let icon = leftView {
        addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[icon]-10-[wrapper]", options: [], metrics: nil, views: ["icon": icon, "wrapper": scrollView]))
        addConstraint(NSLayoutConstraint(item: icon, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0))
      }
    }
  }

  private let placeholderLabel = UILabel()

  private lazy var scrollView: UIScrollView = {
    let _scrollView = UIScrollView()
    _scrollView.clipsToBounds = true
    _scrollView.isDirectionalLockEnabled = true
    _scrollView.showsHorizontalScrollIndicator = false
    _scrollView.showsVerticalScrollIndicator = false
    _scrollView.backgroundColor = UIColor.clear
    return _scrollView
  }()

  private lazy var leftEdgeConstraint: NSLayoutConstraint = {
    NSLayoutConstraint(item: self.scrollView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1, constant: 10)
  }()

  private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
    UITapGestureRecognizer(target: self, action: .handleTapGesture)
  }()

  // MARK: - Initialization

  /// Initializes and returns a newly allocated view object with the specified frame rectangle.
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setUpSubviews()
  }

  /// Returns an object initialized from data in a given unarchiver.
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setUpSubviews()
  }

  // MARK: - UIResponder

  open override var isFirstResponder: Bool {
    return inputTextField.isFirstResponder || super.isFirstResponder
  }

  open override func becomeFirstResponder() -> Bool {
    return inputTextField.becomeFirstResponder()
  }

  open override func resignFirstResponder() -> Bool {
    super.resignFirstResponder()
    return inputTextField.resignFirstResponder()
  }

  // MARK: - UIView

  open override func layoutSubviews() {
    super.layoutSubviews()
    layoutTokenTextField()
  }

  // MARK: - NSKeyValueCoding

  open override func setValue(_ value: Any?, forKey key: String) {
    switch value {
    case let image as UIImage? where key == "icon":
      icon = image
    case let text as String? where key == "placeholder":
      placeholder = text
    case let color as UIColor? where key == "textColor":
      textColor = color
    case let value as CGFloat where key == "cornerRadius":
      cornerRadius = value
    default:
      break
    }
  }

  // MARK: - UITextFieldDelegate

  open func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    tokens.forEach { $0.isHighlighted = false }
    return true
  }

  open func textFieldDidBeginEditing(_ textField: UITextField) {
    delegate?.tokenFieldDidBeginEditing?(self)
  }

  open func textFieldDidEndEditing(_ textField: UITextField) {
    completeCurrentInputText()
    togglePlaceholderIfNeeded()
    tokens.forEach { $0.isHighlighted = false }
    delegate?.tokenFieldDidEndEditing?(self)
  }

  open func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    _ = removeHighlightedToken()  // as user starts typing when a token is focused
    inputTextField.showsCursor = true

    guard let input = textField.text else {
      return true
    }

    let text = (input as NSString).replacingCharacters(in: range, with: string).applyFormat
    delegate?.tokenField?(self, didChangeInputText: text)

    for delimiter in delimiters {
      guard text.hasSuffix(delimiter) else {
        continue
      }

      let index = text.index(text.endIndex, offsetBy: -delimiter.count)
      let newText = String(text[..<index])

      if !newText.isEmpty && newText != delimiter && (delegate?.tokenField?(self, shouldCompleteText: newText) ?? true) {
        tokens.append(customizedToken(with: newText))
        layoutTokenTextField()
        delegate?.tokenField?(self, didCompleteText: newText)
      }

      textField.text = nil
      togglePlaceholderIfNeeded()

      return false
    }
    return delegate?.tokenField?(self, shouldChangeCharactersIn: range, replacementString: string) ?? true
  }

  open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    completeCurrentInputText()
    togglePlaceholderIfNeeded()
    delegate?.tokenFieldWillReturn?(self)
    return true
  }

  // MARK: - BackspaceTextFieldDelegate

  @nonobjc func textFieldShouldDelete(_ textField: BackspaceTextField) -> Bool {
    if !textField.showsCursor {
      _ = removeHighlightedToken()
      return true
    }

    guard let text = textField.text else {
      return true
    }

    if text.isEmpty {
      textField.showsCursor = false
      tokens.last?.isHighlighted = true
    } else {
      // textField(_:shouldChangeCharactersIn:replacementString:) is skipped when the delete key is pressed.
      // Notify the delegate of the changed input text manually.
      let index = text.index(text.endIndex, offsetBy: -1)
      delegate?.tokenField?(self, didChangeInputText: String(text[..<index]))
    }

    return true
  }

  // MARK: - UIResponder Callbacks

  @objc fileprivate func togglePlaceholderIfNeeded(_ sender: UITextField? = nil) {
    let showsPlaceholder = tokens.isEmpty && (inputTextField.text?.isEmpty ?? true)
    placeholderLabel.isHidden = !showsPlaceholder
  }

  @objc fileprivate func handleTapGesture(_ sender: UITapGestureRecognizer) {
    if !isFirstResponder {
      inputTextField.becomeFirstResponder()
    }

    let touch = sender.location(in: scrollView)
    var shouldFocusInputTextField = true

    // Hilight the tapped token
    for token in tokens {
      if token.frame.contains(touch) {
        scrollView.scrollRectToVisible(token.frame, animated: true)
        token.isHighlighted = true
        shouldFocusInputTextField = false
      } else {
        token.isHighlighted = false
      }
    }

    inputTextField.showsCursor = shouldFocusInputTextField
  }

  // MARK: - Private Methods

  private func customizedToken(with text: String) -> Token {
    if let string = delegate?.tokenField?(self, subsequentDelimiterForCompletedText: text) {
      return Token(text: text, delimiter: string, normalAttributes: normalTokenAttributes, highlightedAttributes: highlightedTokenAttributes)
    } else {
      return Token(text: text, normalAttributes: normalTokenAttributes, highlightedAttributes: highlightedTokenAttributes)
    }
  }

  /// Returns true if any highlighted token is found and removed, otherwise false.
  private func removeHighlightedToken() -> Bool {
    for (index, token) in tokens.enumerated() where token.isHighlighted {
      tokens.remove(at: index)
      layoutTokenTextField()
      togglePlaceholderIfNeeded()
      inputTextField.showsCursor = true
      delegate?.tokenField?(self, didDeleteText: token.text, atIndex: index)
      return true
    }
    return false
  }

  private func setUpSubviews() {
    if frame.equalTo(CGRect.zero) {
      frame = CGRect(x: 0, y: 7, width: UIScreen.main.bounds.width, height: 30)
    }

    addSubview(scrollView)
    scrollView.addSubview(inputTextField)
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    let views = ["wrapper": scrollView]
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(>=10)-[wrapper]|", options: [], metrics: nil, views: views))
    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[wrapper]|", options: [], metrics: nil, views: views))
    leftEdgeConstraint.isActive = true

    layoutTokenTextField()
    addGestureRecognizer(tapGestureRecognizer)
  }

  private func layoutTokenTextField() {
    var offset = CGFloat(0)
    var contentRect = CGRect.zero

    scrollView.subviews.filter { $0 is Token } .forEach { $0.removeFromSuperview() }

    for token in tokens {
      let frame = CGRect(
        x: offset,
        y: (scrollView.frame.height - token.frame.height) / 2,
        width: token.frame.width,
        height: token.frame.height
      )
      token.frame = frame
      offset += token.frame.width
      contentRect = contentRect.union(token.frame)

      scrollView.addSubview(token)
    }

    inputTextField.frame = CGRect(
      x: offset,
      y: 0,
      width: max(scrollView.frame.width / 3, scrollView.frame.width - offset),
      height: scrollView.frame.height
    )

    contentRect = contentRect.union(inputTextField.frame)
    scrollView.contentSize = contentRect.size
    scrollView.scrollRectToVisible(inputTextField.frame, animated: true)
  }

  // MARK: - Public Methods

  /// Creates a token with the current input text.
  open func completeCurrentInputText() {
    guard let text = inputTextField.text, !text.isEmpty else {
      return
    }

    let shouldCompleteText = delegate?.tokenField?(self, shouldCompleteText: text) ?? true
    guard shouldCompleteText else {
      return
    }

    inputTextField.text = nil
    tokens.append(customizedToken(with: text))
    layoutTokenTextField()
    delegate?.tokenField?(self, didCompleteText: text)
  }

  /// Removes the input text and all displayed tokens.
  open func resetTokens() {
    inputTextField.text = nil
    tokens.removeAll()
    layoutTokenTextField()
    togglePlaceholderIfNeeded()
  }

}


////////////////////////////////////////////////////////////////////////////////


private extension Selector {
  static let togglePlaceholderIfNeeded = #selector(TokenField.togglePlaceholderIfNeeded(_:))
  static let handleTapGesture = #selector(TokenField.handleTapGesture(_:))
}

private extension String {
    var applyFormat: String {
        let isInternationalFormat = self.hasPrefix("+")
        
        let cleanPhoneNumber = self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        let mask = isInternationalFormat ? "+X (XXX) XXX-XXXX" : "(XXX) XXX-XXXX"
        
        var result = ""
        
        var index = cleanPhoneNumber.startIndex
        
        for ch in mask where index < cleanPhoneNumber.endIndex {
            if ch == "X" {
                result.append(cleanPhoneNumber[index])
                
                index = cleanPhoneNumber.index(after: index)
            } else {
                result.append(ch)
            }
        }
        
        return result.isEmpty && isInternationalFormat ? "+" + result : result
    }
}
