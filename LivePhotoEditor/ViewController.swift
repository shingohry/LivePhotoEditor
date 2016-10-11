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

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    // MARK: - Properties

    @IBOutlet weak var livePhotoView: PHLivePhotoView!
    
    private var targetSize: CGSize {
        let scale = UIScreen.main.scale
        return CGSize(width: self.livePhotoView.bounds.width * scale,
                      height: self.livePhotoView.bounds.height * scale)
    }
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    // MARK: - UINavigationControllerDelegate
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        // get ALAssetURL
        let url = info[UIImagePickerControllerReferenceURL] as! URL?
        
        // Get PHAsset
        let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [url!], options: nil)
        let asset = fetchResult.firstObject
        
        if asset!.mediaSubtypes.contains(.photoLive) {
            // Prepare the options to pass when fetching the live photo.
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            // Request the live photo for the asset from the default PHImageManager.
            PHImageManager.default().requestLivePhoto(for: asset!, targetSize: targetSize, contentMode: .aspectFit, options: options, resultHandler: { livePhoto, info in
                
                // If successful, show the live photo view and display the live photo.
                guard let livePhoto = livePhoto else { return }
                
                // Now that we have the Live Photo, show it.
                self.livePhotoView.livePhoto = livePhoto
                
            })
        }
        
        dismiss(animated: true, completion: nil)
    }
}
