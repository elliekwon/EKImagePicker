//
//  ImagePickerViewController.swift
//  EKImagePicker
//
//  Copyright © 2017 Ellie Kwon. All rights reserved.

import UIKit
import Photos
import AVFoundation

protocol ImagePickerViewControllerDelegate {
  func createViewSelectedMedia(uploadImage: UIImage)
}

class ImagePickerViewController: CommonViewController, UIGestureRecognizerDelegate {

  var createDelegate: ImagePickerViewControllerDelegate?
  var baseScrollView: UIScrollView!

  var selectedImageScrollView: UIScrollView!
  var selectedImageView: UIImageView!
  var libraryCollectionView: UICollectionView!

  var cameraView: UIView!
  var captureSession: AVCaptureSession?
  var frontCamera: AVCaptureDevice?
  var rearCamera: AVCaptureDevice?

  var captureButton : UIButton!

  var photoOutput: AVCapturePhotoOutput?
  var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?

  let imagesQueue = DispatchQueue(label: "imagePicker.imagesQueue",
                                  qos: DispatchQoS.background,
                                  attributes: DispatchQueue.Attributes.concurrent,
                                  autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                  target: nil)

  let cellSize = CGSize(width: UIScreen.main.bounds.width/3, height: UIScreen.main.bounds.width/3)
  var imageManager: PHCachingImageManager?
  var _images: PHFetchResult<PHAsset>?
  var images: PHFetchResult<PHAsset>? {
    get {
      return imagesQueue.sync {
        return _images
      }
    }
    set {
      imagesQueue.sync {
        _images = newValue
      }
    }
  }

  let cameraController = CameraController()

  var captureSesssion: AVCaptureSession!
  var stillImageOutput: AVCapturePhotoOutput?
  var previewLayer: AVCaptureVideoPreviewLayer?
  var captureDevice : AVCaptureDevice!

  override func viewDidLoad() {
    super.viewDidLoad()

    checkPhotoAuth()

    setupNavigation()

    let options = PHFetchOptions()
    options.sortDescriptors = [
      NSSortDescriptor(key: "creationDate", ascending: false)
    ]

    DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {

      var collections: PHFetchResult<PHAssetCollection>
      collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)

      for index in 0 ..< collections.count {
        let moment = collections[index]
        //print(moment.localizedTitle)
         self.navigationItem.title = moment.localizedTitle

        let assetsFetchResult = PHAsset.fetchAssets(in: moment, options: nil)
        // ...
      }

      self.images = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: options)
      DispatchQueue.main.async {
        if let images = self.images, images.count > 0 {
          if self.selectedImageView.image == nil {
            // 아직 선택된 이미지가 없으면 첫 이미지를 기본으로 셋팅
            let asset = images.firstObject
            self.imageManager?.requestImage(for: asset!,
                                       targetSize: self.selectedImageView.frame.size,
              contentMode: .aspectFit,
              options: nil) { result, _ in
                self.selectedImageView.image = result
            }
          }
          self.libraryCollectionView.reloadData()
          self.libraryCollectionView.selectItem(at: IndexPath(row: 0, section: 0),
                                                animated: false,
                                                scrollPosition: UICollectionViewScrollPosition())
        }
      }
    }
    PHPhotoLibrary.shared().register(self)

    baseScrollView = UIScrollView()
    baseScrollView.isPagingEnabled = true
    baseScrollView.bounces = false

    baseScrollView.contentSize = CGSize(width: self.view.frame.width*2, height: self.view.frame.height)
    
    selectedImageScrollView = UIScrollView()
    selectedImageView = UIImageView()
    selectedImageView.contentMode = UIViewContentMode.scaleAspectFill

    let columnLayout = ColumnFlowLayout(
      cellsPerRow: 3,
      minimumInteritemSpacing: 1,
      minimumLineSpacing: 1,
      sectionInset: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    )
    libraryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: columnLayout)
    libraryCollectionView.dataSource = self
    libraryCollectionView.delegate = self
    libraryCollectionView.register(ImagePickerItemCell.self, forCellWithReuseIdentifier: "cellIdentifier")
    cameraView = UIView()

    self.view.addSubview(baseScrollView)
    baseScrollView.addSubview(selectedImageScrollView)
    baseScrollView.addSubview(cameraView)
    baseScrollView.addSubview(libraryCollectionView)

    selectedImageScrollView.minimumZoomScale = 1.0
    selectedImageScrollView.maximumZoomScale = 10.0
    selectedImageScrollView.delegate = self

    selectedImageScrollView.addSubview(selectedImageView)
//    selectedImageView.frame = CGRect(x: 0, y: 0, width: (selectedImageView.image?.size.width)!, height: (selectedImageView.image?.size.height)!) // 런타임에러 발생으로 주석처리
    selectedImageScrollView.contentSize = selectedImageView.frame.size


    baseScrollView.snp.makeConstraints { (make) in
      make.top.equalTo(self.view).offset(50)
      make.left.right.bottom.equalTo(self.view)
    }
    baseScrollView.contentSize = CGSize(width: self.view.frame.width*2, height: self.view.frame.height)
    //baseScrollView.backgroundColor = UIColor.red

    selectedImageScrollView.snp.makeConstraints { (make) in
      make.top.left.equalTo(baseScrollView)
      make.width.equalTo(self.view.frame.width)
      make.height.equalTo(self.view.frame.width)
    }

    selectedImageView.snp.makeConstraints { (make) in
      make.top.left.right.bottom.equalTo(selectedImageScrollView)
      make.width.height.equalTo(self.view.frame.width)
    }

    libraryCollectionView.snp.makeConstraints { (make) in
      make.top.equalTo(selectedImageScrollView.snp.bottom)
      make.left.equalTo(baseScrollView)
      make.width.equalTo(self.view.frame.width)
      make.height.equalTo(300)
    }
    //libraryCollectionView.backgroundColor = UIColor.lightGray

    cameraView.snp.makeConstraints { (make) in
      make.left.equalTo(selectedImageScrollView.snp.right)
      make.width.equalTo(selectedImageScrollView.snp.width)
      make.height.equalTo(self.view.frame.height)
      //      make.bottom.equalTo(baseScrollView)
      previewLayer?.bounds = self.cameraView.frame
    }
    //cameraView.backgroundColor = UIColor.yellow

    self.captureSession = AVCaptureSession()

    func configureCameraController() {
//      cameraController.prepare {(error) in
//        if let error = error {
//          print(error)
//        }
//
//        try? self.cameraController.displayPreview(on: self.cameraView)
//      }

      captureSesssion = AVCaptureSession()
      captureSession?.sessionPreset = AVCaptureSession.Preset.photo

      stillImageOutput = AVCapturePhotoOutput()

      captureSesssion.sessionPreset = AVCaptureSession.Preset.medium
      captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.back)
      //captureDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front)
      //When change "front" to "back", camera is built.

      do {
        let input = try AVCaptureDeviceInput(device: captureDevice)

        if (captureSesssion.canAddInput(input)) {
          captureSesssion.addInput(input)

          if (captureSesssion.canAddOutput(stillImageOutput!)) {
            captureSesssion.addOutput(stillImageOutput!)
            captureSesssion.startRunning()

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSesssion)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
            previewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait

            self.cameraView.layer.addSublayer(previewLayer!)
            let width = 320// UIScreen.main.bounds.width * UIScreen.main.scale
            previewLayer?.position = CGPoint(x: width/2, y: width/2)
//            previewLayer?.bounds = self.cameraView.frame
            previewLayer?.bounds = CGRect(x: 0, y:  0, width: 414, height: 414)
//            previewLayer?.frame = CGRect(x: 0, y:  0, width: 320, height: 320)
          }
        }
      }
      catch {
        print(error)
      }

    }
    configureCameraController()

    captureButton = UIButton()
    captureButton.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    captureButton.layer.cornerRadius = 0.5 * captureButton.bounds.size.width
    captureButton.clipsToBounds = true
    captureButton.backgroundColor = UIColor.red
    captureButton.addTarget(self, action: #selector(captureImage(completion:)), for: .touchUpInside)
    cameraView.addSubview(captureButton)

    captureButton.snp.makeConstraints { make in
      make.centerX.equalTo(cameraView)
      make.bottom.equalTo(cameraView).offset(-50)
      make.width.equalTo(100)
      make.height.equalTo(100)
    }

    let panGesture      = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
    panGesture.delegate = self
    self.view.addGestureRecognizer(panGesture)
  }

  @objc func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {

    #if false
    let editViewController = ImageEditViewController(image: selectedImageView.image)
    self.navigationController?.pushViewController(editViewController, animated: true)

    #else
    guard let captureSession = captureSesssion, captureSession.isRunning else { return }

    let settings = AVCapturePhotoSettings()
    settings.flashMode = AVCaptureDevice.FlashMode.off

    stillImageOutput?.capturePhoto(with: settings, delegate: self as AVCapturePhotoCaptureDelegate)
    //self.photoCaptureCompletionBlock = completion
    #endif
  }

//  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
//    return selectedImageView
//  }

  func checkPhotoAuth() {
    PHPhotoLibrary.requestAuthorization { status  in
      switch status {
      case .authorized:
        self.imageManager = PHCachingImageManager()
        if let images = self.images, images.count > 0 {
          //self.changeImage(images[0])
        }
      case .restricted, .denied:
        DispatchQueue.main.async {
          //self.delegate?.albumViewCameraRollUnauthorized()
        }
      default:
        break
      }
    }
  }

  func setupNavigation() {

    //let navItem = UINavigationItem(title: "추가");

    //    let backNaviItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(backNaviButtonTap))
    //    navItem.leftBarButtonItem = backNaviItem;
    //    let doneNaviItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(doneNaviButtonTap))
    //    navItem.rightBarButtonItem = doneNaviItem;
    // error
    // *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Cannot call setItems:animated: directly on a UINavigationBar managed by a controller.'
    //self.navigationController?.navigationBar.setItems([navItem], animated: false);

    self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(backNaviButtonTap))
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(doneNaviButtonTap))

    self.navigationItem.title = "TEST"

    let button = UIButton()
    button.setTitle("Button", for: .normal)
    button.frame.size = CGSize(width: 60, height: 30)
    button.addTarget(self, action: #selector(libraryTitleButtonDidTap), for: .touchUpInside)
    let titleView = UIView()
    titleView.backgroundColor = UIColor.cyan

    titleView.frame.size = CGSize(width: 120, height: 44)
    titleView.addSubview(button)
    button.frame.origin = CGPoint(x: titleView.frame.size.width * 0.5 - button.frame.size.width * 0.5,
                                  y: titleView.frame.size.height * 0.5 - button.frame.size.height * 0.5)
    self.navigationItem.titleView = titleView

    navigationController?.interactivePopGestureRecognizer?.delegate = nil
  }

  @objc func panned(_ sender: UIPanGestureRecognizer) {
    print("\(sender)")
  }


  // MARK: User Action

  @objc func libraryTitleButtonDidTap() {
    let albums : CommonViewController = AlbumListViewCotroller()

    self.present(albums, animated: true) {
      // TODO
    }
  }

  /**
   * 네비게이션 '뒤로' 버튼 선택
   */
  @objc func backNaviButtonTap() {
    if self.navigationController == nil || self.navigationController?.viewControllers.first == self {
      self.dismiss(animated: true)
    } else {
      self.navigationController?.popViewController(animated: true)
    }
  }

  /**
   * 네비게이션 '완료' 버튼 선택
   */
  @objc func doneNaviButtonTap() {
    // todo :
    createDelegate?.createViewSelectedMedia(uploadImage: selectedImageView.image!)



    UIGraphicsBeginImageContext(selectedImageView.frame.size)
    selectedImageScrollView.layer.render(in: UIGraphicsGetCurrentContext()!)
    let croppedImage :UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()

    let editViewController = ImageEditViewController(image: croppedImage)
    self.navigationController?.pushViewController(editViewController, animated: true)


    //backNaviButtonTap()
  }
}

extension ImagePickerViewController: UICollectionViewDataSource {
  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return images == nil ? 0 : images!.count
  }

  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellIdentifier", for: indexPath) as! ImagePickerItemCell
    let asset = images?[(indexPath as NSIndexPath).item]
    imageManager?.requestImage(for: asset!,
                               targetSize: CGSize(width: cellSize.width*2, height: cellSize.height*2),//cellSize,
                               contentMode: .aspectFit,
                               options: nil) { result, _ in
                                //if cell.tag == currentTag {
                                cell.imageView.image = result
                                //self.selectedImageView.image = result
                                //}
    }

    return cell
  }
}

extension ImagePickerViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let asset = images?[(indexPath as NSIndexPath).item]
    imageManager?.requestImage(for: asset!,
                               targetSize: CGSize(width: self.selectedImageView.frame.width*2, height: self.selectedImageView.frame.width*2),
                               contentMode: .aspectFit,
                               options: nil) { result, _ in
                                self.selectedImageView.image = result
    }
  }
}

extension ImagePickerViewController: AVCapturePhotoCaptureDelegate {
  public func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                      resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
    if let error = error { self.photoCaptureCompletionBlock?(nil, error) }

    else if let buffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: nil),
      let capturedImage = UIImage(data: data) {

      let editViewController = ImageEditViewController(image: capturedImage)
      self.navigationController?.pushViewController(editViewController, animated: true)

      self.photoCaptureCompletionBlock?(capturedImage, nil)
    }

    else {
      //self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
    }
  }
}



extension ImagePickerViewController: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    //print("\(scrollView.contentOffset)")
  }

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return selectedImageView
  }
}

extension ImagePickerViewController: PHPhotoLibraryChangeObserver {
  public func photoLibraryDidChange(_ changeInstance: PHChange) {
    DispatchQueue.main.async {
      if let images = self.images {
        let collectionChanges = changeInstance.changeDetails(for: images)
        if collectionChanges != nil {
          self.images = collectionChanges!.fetchResultAfterChanges
          let collectionView = self.libraryCollectionView!
          if !collectionChanges!.hasIncrementalChanges || collectionChanges!.hasMoves {
            collectionView.reloadData()
          } else {
            collectionView.performBatchUpdates({
              //              let removedIndexes = collectionChanges!.removedIndexes
              //              if (removedIndexes?.count ?? 0) != 0 {
              //                collectionView.deleteItems(at: removedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
              //              }
              //              let insertedIndexes = collectionChanges!.insertedIndexes
              //              if (insertedIndexes?.count ?? 0) != 0 {
              //                collectionView
              //                  .insertItems(at: insertedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
              //              }
              //              let changedIndexes = collectionChanges!.changedIndexes
              //              if (changedIndexes?.count ?? 0) != 0 {
              //                collectionView.reloadItems(at: changedIndexes!.aapl_indexPathsFromIndexesWithSection(0))
              //              }
            }, completion: nil)
          }
          //self.resetCachedAssets()
        }
      }
    }
  }
}
