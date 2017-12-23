//
//  ImagePickerItemCell.swift
//  EKImagePicker
//
//  Copyright © 2017 Ellie Kwon. All rights reserved.
//

import UIKit

class ImagePickerItemCell: UICollectionViewCell {
  let imageView = UIImageView()

  override init(frame: CGRect) {
    super.init(frame: frame)

    self.addSubview(imageView)
    imageView.snp.makeConstraints { (make) in
      make.top.left.right.bottom.equalTo(self)
    }
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForReuse() {
    imageView.image = nil
  }
}
