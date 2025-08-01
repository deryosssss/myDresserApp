//
//  AddViewController.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//

import UIKit
import PhotosUI

class AddViewController: UIViewController {
  
  // MARK: - Data
  private var images: [UIImage] = []
  
  // MARK: - UI
  private lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    let side = (view.bounds.width - 3 * 10) / 2
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
    title = "Add"
    view.backgroundColor = .systemBackground
    view.addSubview(collectionView)
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
      collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
    ])
  }
  
  // MARK: - Helpers
  
  private func presentCamera() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      let ac = UIAlertController(title: "No Camera", message: "Camera not available on this device.", preferredStyle: .alert)
      ac.addAction(.init(title: "OK", style: .default))
      present(ac, animated: true)
      return
    }
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = self
    present(picker, animated: true)
  }
  
  private func presentPhotoPicker() {
    var config = PHPickerConfiguration()
    config.selectionLimit = 0        // 0 = unlimited selection
    config.filter = .images
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    present(picker, animated: true)
  }
}

// MARK: - UICollectionViewDataSource

extension AddViewController: UICollectionViewDataSource {
  func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    // +1 for the “camera” cell
    return images.count + 1
  }
  
  func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = cv.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseID, for: indexPath) as! ImageCell
    if indexPath.item == 0 {
      // camera icon
      cell.configureAsCamera()
    } else {
      cell.configure(with: images[indexPath.item - 1])
    }
    return cell
  }
}

// MARK: - UICollectionViewDelegate

extension AddViewController: UICollectionViewDelegate {
  func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    cv.deselectItem(at: indexPath, animated: true)
    if indexPath.item == 0 {
      // first cell → camera
      presentCamera()
    } else {
      // any other cell → present multi-picker
      presentPhotoPicker()
    }
  }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate

extension AddViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController,
                             didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    if let image = info[.originalImage] as? UIImage {
      images.append(image)
      collectionView.reloadData()
    }
  }
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
  }
}

// MARK: - PHPickerViewControllerDelegate

extension AddViewController: PHPickerViewControllerDelegate {
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    let itemProviders = results.map(\.itemProvider)
    for provider in itemProviders {
      if provider.canLoadObject(ofClass: UIImage.self) {
        provider.loadObject(ofClass: UIImage.self) { [weak self] (obj, _) in
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
    contentView.addSubview(imageView)
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
      imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])
    contentView.layer.cornerRadius = 8
    contentView.layer.borderWidth = 1
    contentView.layer.borderColor = UIColor.secondarySystemFill.cgColor
  }
  
  required init?(coder: NSCoder) { fatalError() }
  
  func configureAsCamera() {
    imageView.image = UIImage(systemName: "camera.fill")
    imageView.tintColor = .label
    imageView.contentMode = .center
  }
  
  func configure(with image: UIImage) {
    imageView.image = image
    imageView.contentMode = .scaleAspectFill
  }
}
