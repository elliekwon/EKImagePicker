//
//  ImageEditViewController.swift
//  EKImagePicker
//
//  Copyright © 2017 Ellie Kwon. All rights reserved.
//

import UIKit

class ImageEditViewController: CommonViewController {

  var originalImage : UIImageView = UIImageView()

  // MARK: - Initialize
  init(image: UIImage?) {
      super.init(nibName: nil, bundle: nil)

      guard let oImage = image else {
          return
      }
      originalImage.image = oImage
  }

  required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.addSubview(originalImage)

    originalImage.contentMode = .scaleAspectFill

    let screenSize = getScaledSizeToWidth(originSize: (originalImage.image?.size)!,
                                          scaledToWidth: self.view.frame.width)
    originalImage.snp.makeConstraints { (make) in
      make.top.equalTo(self.view).offset(50)
      make.left.right.equalTo(self.view).offset(-5)
      make.height.equalTo(screenSize.height)
    }
  }

  func getScaledSizeToWidth (originSize: CGSize, scaledToWidth: CGFloat) -> CGSize {
    let oldWidth = originSize.width
    let scaleFactor = scaledToWidth / oldWidth

    let newHeight = originSize.height * scaleFactor
    let newWidth = oldWidth * scaleFactor

    return CGSize(width: newWidth, height: newHeight)
  }
}
