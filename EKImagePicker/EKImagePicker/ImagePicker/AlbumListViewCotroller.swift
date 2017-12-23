//
//  AlbumListViewCotroller.swift
//  EKImagePicker
//
//  Copyright © 2017 Ellie Kwon. All rights reserved.
//

import UIKit
import Photos

class AlbumListViewCotroller: CommonViewController {

  typealias albumTuple = (albumTitle: String, albumImage: UIImage)

  var albumsArr : [albumTuple] = []

  var albumsTableView : UITableView!

  init() {


    super.init(nibName: nil, bundle: nil)

    
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    albumsTableView = UITableView()
    self.view.addSubview(albumsTableView)

    albumsTableView.snp.makeConstraints { (make) in
      make.top.left.right.bottom.equalTo(self.view)
    }
    albumsTableView.dataSource = self
    albumsTableView.delegate = self
    albumsTableView.register(AlbumListItemCell.self, forCellReuseIdentifier: AlbumListItemCell.cellReuseIdentifier)

    // Do any additional setup after loading the view.
    DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {

      var collections: PHFetchResult<PHAssetCollection>
      collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)

      for index in 0 ..< collections.count {
        let collection = collections[index]

        self.albumsArr.append(albumTuple(collection.localizedTitle!,UIImage(named: "multi_images")!))
//        self.albumsDic.updateValue(UIImage(named: "multi_images")!, forKey: collection.localizedTitle!)

//        let assetsFetchResult = PHAsset.fetchAssets(in: collection, options: nil)

      }

      DispatchQueue.main.async {
        self.albumsTableView.reloadData()
      }

    }
  }
}

extension AlbumListViewCotroller : UITableViewDataSource {
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return albumsArr.count
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//    AlbumListItemCell

    let cell = tableView.dequeueReusableCell(withIdentifier: AlbumListItemCell.cellReuseIdentifier, for: indexPath) as! AlbumListItemCell
    cell.selectionStyle = .none

//    if let title : String = albumsArr[indexPath.row].albumTitle {
//       cell.albumTitleLabel.text = title
//    }
   //albumsArr[indexPath.row].albumTitle as String!

    return cell
  }
}

extension AlbumListViewCotroller : UITableViewDelegate {
}
