//
//  ViewController.swift
//  LivePhotoEditor
//
//  Created by hiraya.shingo on 2016/10/11.
//  Copyright © 2016年 Shingo Hiraya. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import MobileCoreServices

class ViewController: UIViewController {

    // MARK: - Properties

    @IBOutlet weak var livePhotoView: PHLivePhotoView!
    
    private var targetSize: CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: self.livePhotoView.bounds.width * scale,
                      height: self.livePhotoView.bounds.height * scale)
    }
    
    fileprivate var asset: PHAsset?
    private lazy var formatIdentifier = Bundle.main.bundleIdentifier!
    private let formatVersion = "1.0"
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Action

    @IBAction func buttonDidTouch(_ sender: AnyObject) {
        let controller = UIImagePickerController()
        controller.delegate = self
        controller.sourceType = .photoLibrary
        controller.allowsEditing = false
        controller.mediaTypes = [kUTTypeImage as String, kUTTypeLivePhoto as String]
        self.present(controller, animated: true, completion: nil)
    }
    
    @IBAction func editDidTouch(_ sender: UIBarButtonItem) {
        self.showAlertController()
    }
    
    // MARK: - Private
    
    private func showAlertController() {
        guard let asset = self.asset else { return }
        if !(asset.mediaSubtypes.contains(.photoLive)) { return }
        
        let alertController = UIAlertController(title: nil,
                                                message: nil,
                                                preferredStyle: .actionSheet)
        
        // Add a Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel",
                                                style: .cancel,
                                                handler: nil))
        
        if asset.canPerform(.content) {
            // Add actions for some canned filters.
            alertController.addAction(UIAlertAction(title: "Sepia Tone",
                                                    style: .default,
                                                    handler: { _ in self.applyFilter("CISepiaTone") }))
            alertController.addAction(UIAlertAction(title: "Instant",
                                                    style: .default,
                                                    handler: { _ in self.applyFilter("CIPhotoEffectInstant") }))
            alertController.addAction(UIAlertAction(title: "Noir",
                                                    style: .default,
                                                    handler: { _ in self.applyFilter("CIPhotoEffectNoir") }))
            
            // Add actions to revert
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Revert", comment: ""),
                                                    style: .destructive,
                                                    handler: { _ in self.revertAsset() }))
        }

        present(alertController, animated: true)
    }
    
    fileprivate func updateImage() {
        guard let asset = self.asset else { return }
        
        // Prepare the options to pass when fetching the live photo.
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        // Request the live photo for the asset from the default PHImageManager.
        PHImageManager.default().requestLivePhoto(for: asset,
                                                  targetSize: self.targetSize,
                                                  contentMode: .aspectFit,
                                                  options: options,
                                                  resultHandler: { livePhoto, info in
                                                    // If successful, show the live photo view and display the live photo.
                                                    guard let livePhoto = livePhoto else { return }
                                                    
                                                    // Now that we have the Live Photo, show it.
                                                    self.livePhotoView.livePhoto = livePhoto
        })
    }
    
    func applyFilter(_ filterName: String) {
        guard let asset = self.asset else { return }
        
        // Set up a handler to make sure we can handle prior edits.
        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = { adjustmentData in
            return adjustmentData.formatIdentifier == self.formatIdentifier && adjustmentData.formatVersion == self.formatVersion
        }
        
        // Check whether the asset supports the content editing operation
        if !asset.canPerform(.content) { return }
        
        // Request PHContentEditingInput
        asset.requestContentEditingInput(with: options, completionHandler: { input, info in
            guard let input = input else { fatalError("can't get content editing input: \(info)") }
            
            // Create PHAdjustmentData
            let adjustmentData = PHAdjustmentData(formatIdentifier: self.formatIdentifier,
                                                  formatVersion: self.formatVersion,
                                                  data: filterName.data(using: .utf8)!)
            
            // Create PHContentEditingOutput and set PHAdjustmentData
            let output = PHContentEditingOutput(contentEditingInput: input)
            output.adjustmentData = adjustmentData
            
            // Create PHLivePhotoEditingContext from PHContentEditingInput
            guard let livePhotoContext = PHLivePhotoEditingContext(livePhotoEditingInput: input) else { fatalError("can't get live photo to edit") }
            
            // Set frameProcessor
            livePhotoContext.frameProcessor = { frame, _ in
                return frame.image.applyingFilter(filterName, withInputParameters: nil)
            }
            
            // Perform saveLivePhoto
            livePhotoContext.saveLivePhoto(to: output) { success, error in
                if success {
                    // Commit the edit to the Photos library.
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetChangeRequest(for: asset)
                        request.contentEditingOutput = output
                        }, completionHandler: { success, error in
                            if !success {
                                print(Date(), #function, #line, "cannot edit asset: \(error)")
                            }
                    })
                } else {
                    print(Date(), #function, #line, "cannot output live photo")
                }
            }
        })
    }
    
    func revertAsset() {
        guard let asset = self.asset else { return }
        
        // Commit the edit to the Photos library.
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.revertAssetContentToOriginal()
            }, completionHandler: { success, error in
                if !success { print(Date(), #function, #line, "can't revert asset: \(error)")
                }
        })
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension ViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let asset = self.asset else { return }
        
        // Call might come on any background queue. Re-dispatch to the main queue to handle it.
        DispatchQueue.main.sync {
            // Check if there are changes to the asset we're displaying.
            guard let details = changeInstance.changeDetails(for: asset) else { return }
            
            // Get the updated asset.
            self.asset = details.objectAfterChanges as? PHAsset
            
            // If the asset's content changed, update the image and stop any video playback.
            if details.assetContentChanged {
                self.updateImage()
            }
        }
    }
}

// MARK: - UINavigationControllerDelegate

extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        // get ALAssetURL
        let url = info[UIImagePickerControllerReferenceURL] as! URL?
        
        // Get PHAsset
        let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [url!], options: nil)
        self.asset = fetchResult.firstObject
        
        self.updateImage()
        
        dismiss(animated: true, completion: nil)
    }
}
