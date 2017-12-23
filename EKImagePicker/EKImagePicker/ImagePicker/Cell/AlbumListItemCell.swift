//
//  AlbumListItemCellTableViewCell.swift
//  EKImagePicker
//
//  Created by Ellie Kwon on 2017. 12. 16..
//  Copyright © 2017년 Ellie Kwon. All rights reserved.
//

import UIKit

class AlbumListItemCell: UITableViewCell {
  static let cellReuseIdentifier = "albumListItemCell"

  @IBOutlet var albumImageView: UIImageView!
  @IBOutlet var albumTitleLabel: UILabel!
  @IBOutlet var albumContentCountLabel: UILabel!

  override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
