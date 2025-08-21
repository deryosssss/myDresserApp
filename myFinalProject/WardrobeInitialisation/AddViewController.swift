//
//  AddViewController.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025
//
//  1) Shows a 2-column grid: first cell opens the camera; other cells are picked images.
//  2) Lets you add photos via camera (UIImagePickerController) or multi-select library (PHPicker).
//  3) Appends chosen images to a local array and refreshes the grid.
//

import UIKit
import PhotosUI

class AddViewController: UIViewController {
  
  // MARK: - Data
  private var images: [UIImage] = []                      // in-memory images backing the grid
  
  // MARK: - UI
  private lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    let side = (view.bounds.width - 3 * 10) / 2           // 2 columns with 10pt insets/spacings
    layout.itemSize = CGSize(width: side, height: side)
    layout.minimumInteritemSpacing = 10
    layout.minimumLineSpacing = 10
    let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
    cv.backgroundColor = .systemBackground
    cv.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseID)
    cv.dataSource = self
    cv.delegate = self
    return cv
  }()
  
  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Add"                                         // nav title
    view.backgroundColor = .systemBackground
    view.addSubview(collectionView)                       // add grid
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([                          // pin with 10pt margins
      collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
      collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
    ])
  }
  
  // MARK: - Helpers
  
  private func presentCamera() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      // show friendly alert if camera is unavailable (e.g., Simulator)
      let ac = UIAlertController(title: "No Camera", message: "Camera not available on this device.", preferredStyle: .alert)
      ac.addAction(.init(title: "OK", style: .default))
      present(ac, animated: true)
      return
    }
    let picker = UIImagePickerController()                // system camera UI
    picker.sourceType = .camera
    picker.delegate = self
    present(picker, animated: true)
  }
  
  private func presentPhotoPicker() {
    var config = PHPickerConfiguration()
    config.selectionLimit = 0        // 0 = unlimited selection
    config.filter = .images          // images only
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    present(picker, animated: true)
  }
}

// MARK: - UICollectionViewDataSource

extension AddViewController: UICollectionViewDataSource {
  func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }   // single section
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return images.count + 1                                                 // +1 for the camera cell
  }
  
  func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = cv.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseID, for: indexPath) as! ImageCell
    if indexPath.item == 0 {
      cell.configureAsCamera()                                              // first cell shows camera icon
    } else {
      cell.configure(with: images[indexPath.item - 1])                      // other cells show images
    }
    return cell
  }
}

// MARK: - UICollectionViewDelegate

extension AddViewController: UICollectionViewDelegate {
  func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    cv.deselectItem(at: indexPath, animated: true)
    if indexPath.item == 0 {
      presentCamera()                                                       // tap first cell → open camera
    } else {
      presentPhotoPicker()                                                  // tap any image cell → pick more
    }
  }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate

extension AddViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController,
                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    if let image = info[.originalImage] as? UIImage {                       // grab captured image
      images.append(image)                                                  // add to data source
      collectionView.reloadData()                                           // refresh grid
    }
  }
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)                                          // close camera on cancel
  }
}

// MARK: - PHPickerViewControllerDelegate

extension AddViewController: PHPickerViewControllerDelegate {
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    let itemProviders = results.map(\.itemProvider)                          // providers for selected items
    for provider in itemProviders {
      if provider.canLoadObject(ofClass: UIImage.self) {
        provider.loadObject(ofClass: UIImage.self) { [weak self] (obj, _) in // async load each image
          guard let self = self, let img = obj as? UIImage else { return }
          DispatchQueue.main.async {
            self.images.append(img)
            self.collectionView.reloadData()
          }
        }
      }
    }
  }
}

// MARK: - ImageCell

private class ImageCell: UICollectionViewCell {
  static let reuseID = "ImageCell"
  private let imageView = UIImageView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.addSubview(imageView)                                       // fill cell with image view
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
      imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])
    contentView.layer.cornerRadius = 8                                      // subtle card styling
    contentView.layer.borderWidth = 1
    contentView.layer.borderColor = UIColor.secondarySystemFill.cgColor
  }
  
  required init?(coder: NSCoder) { fatalError() }                           // not used in storyboard
  
  func configureAsCamera() {
    imageView.image = UIImage(systemName: "camera.fill")                    // SF Symbol for camera
    imageView.tintColor = .label
    imageView.contentMode = .center
  }
  
  func configure(with image: UIImage) {
    imageView.image = image                                                 // show chosen image
    imageView.contentMode = .scaleAspectFill
  }
}
