//
//  ViewController.swift
//  openface_test
//
//  Created by Aneesh Prabu on 26/10/19.
//  Copyright © 2019 Aneesh Prabu. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageDetect

class ViewController: UIViewController {
    
    @IBOutlet weak var referenceBtn: UIButton!
    @IBOutlet weak var testBtn: UIButton!
    
    @IBOutlet weak var referenceImage: UIImageView!
    @IBOutlet weak var testImage: UIImageView!
    @IBOutlet weak var resultLabel: UILabel!
    
    var flag:Bool = false
    var vector1 = MLMultiArray()
    var vector2 = MLMultiArray()
    
    //MARK: - Image picker controller
    let referenceImagePicker = UIImagePickerController()
    let testImagePicker = UIImagePickerController()
    
    var faceArray = [UIImage]()
    var count = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        referenceImagePicker.delegate = self
        referenceImagePicker.sourceType = .camera
        referenceImagePicker.cameraDevice = .front
        referenceImagePicker.cameraFlashMode = .off
        referenceImagePicker.allowsEditing = false
        
        testImagePicker.delegate = self
        testImagePicker.sourceType = .camera
        testImagePicker.cameraDevice = .front
        testImagePicker.cameraFlashMode = .off
        testImagePicker.allowsEditing = false
    }
    
    @IBAction func referenceTapped(_ sender: UIButton) {
        
        present(referenceImagePicker, animated: true, completion: nil)
        
    }
    
    @IBAction func testTapped(_ sender: UIButton) {
        present(testImagePicker, animated: true, completion: nil)
    }
    
    

    @IBAction func runTapped(_ sender: UIButton) {
        
        if let image1 = referenceImage.image, let image2 = testImage.image {
            
            let newImage1 = UIImage(cgImage: image1.cgImage!, scale: image1.scale, orientation: .right)
            referenceImage.image = newImage1
            let newImage2 = UIImage(cgImage: image2.cgImage!, scale: image2.scale, orientation: .right)
            testImage.image = newImage2
            
            let croppedImage1 = resizeImage(image: newImage1, targetSize: CGSize(width: 96.0, height: 96.0))
            let croppedImage2 = resizeImage(image: newImage2, targetSize: CGSize(width: 96.0, height: 96.0))
            
            referenceImage.image = croppedImage1
            testImage.image = croppedImage2
            
            guard let CI_image1 = CIImage(image: croppedImage1) else {
                fatalError("Could not convert UIImage to CIImage")
            }
            
            detect(image: CI_image1)
            
            guard let CI_image2 = CIImage(image: croppedImage2) else {
                fatalError("Could not convert UIImage to CIImage")
            }
            
            detect(image: CI_image2)
            
            let distance = distanceCalc(array1: vector1, array2: vector2)
            
//            print(vector1)
//            print(vector2)
            
            print(distance)
            
            if distance < 0.8 {
                print("Faces match")
                resultLabel.text = "Accuracy =  \(distance), Faces Match"
            }
            else {
                print("Faces does not match")
                resultLabel.text = "Accuracy =  \(distance), Faces do not Match"
            }
            
        }
    }
    
    //MARK: - ML Model for face feature detection
    func detect(image: CIImage) {
        
        guard let model = try? VNCoreMLModel(for: OpenFace().model) else {
            fatalError("Model failed to load!")
        }
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            
            guard let results = request.results as? [VNCoreMLFeatureValueObservation] else {
                fatalError("Results cant be converted to VNCoreMLFeatureValueObservation")
            }
            
            let obs : VNCoreMLFeatureValueObservation = (results.first)!
            let multiarray: MLMultiArray = obs.featureValue.multiArrayValue!
            
            if self.flag == false {
                self.vector1 = multiarray
                self.flag = true
            }
            else {
                self.vector2 = multiarray
                self.flag = false
            }

        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        
        do {
            try handler.perform([request])
        }
        catch {
            print(error)
        }
        
    }
    
    func distanceCalc(array1: MLMultiArray, array2: MLMultiArray) -> Double {
        
        var sum = 0.0
        var result = 0.0

        for i in 0..<array1.count
        {
            let sub1 = (Double(truncating: array1[i]) - Double(truncating: array2[i]))
            let sub2 = (Double(truncating: array1[i]) - Double(truncating: array2[i]))
            let temp = sub1 * sub2
            sum = sum + temp
            result = Double(sqrt(sum))
        }
        
        return result
    }

    
    //MARK: - Resize image function
    
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
    
        
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
    
}


//MARK: - Extention delegate functions

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if picker == referenceImagePicker {
            
            if let userPickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                
                userPickedImage.detector.crop(type: .face) {
                    result in
                
                    switch result {
                    case .success(let croppedImages):
                        // When the `Vision` successfully find type of object you set and successfuly crops it.
                        print("Found")
                        self.referenceImage.image = croppedImages.first
                            
                    case .notFound:
                        // When the image doesn't contain any type of object you did set, `result` will be `.notFound`.
                        print("Not Found")
                    case .failure(let error):
                        // When the any error occured, `result` will be `failure`.
                        print(error.localizedDescription)
                        }
                }
            }
            
            referenceImagePicker.dismiss(animated: true, completion: nil)
        }
        
        else if picker == testImagePicker {
            if let userPickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                userPickedImage.detector.crop(type: .face) {
                    result in
                
                    switch result {
                    case .success(let croppedImages):
                        // When the `Vision` successfully find type of object you set and successfuly crops it.
                        print("Found")
                        self.testImage.image = croppedImages.first
                            
                    case .notFound:
                        // When the image doesn't contain any type of object you did set, `result` will be `.notFound`.
                        print("Not Found")
                    case .failure(let error):
                        // When the any error occured, `result` will be `failure`.
                        print(error.localizedDescription)
                        }
                }
                
            }
            
            testImagePicker.dismiss(animated: true, completion: nil)
        }
        
    }
}

