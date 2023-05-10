import UIKit
import ARKit
import Photos
import AVFoundation
import ARVideoKit
import FirebaseDatabase
import Firebase
import Foundation


//private let planeWidth: CGFloat = 1.35
private let planeWidth: CGFloat = 1.053
//private let planeHeight: CGFloat = 1.935
private let planeHeight: CGFloat = 1.5093
private let nodeYPosition: Float = 0.028
private let minPositionDistance: Float = 0.0025
private let minScaling: CGFloat = 0.025
private let cellIdentifier = "GlassesCollectionViewCell"
private let glassesCount = 4
private let animationDuration: TimeInterval = 0.25
private let cornerRadius: CGFloat = 10

var userDefaultValue = true


enum DownloadError: Error {
    case notImage
    case invalidStatusCode(URLResponse)
}

//var isRecording = false

public class BaseViewController: UIViewController,ARSCNViewDelegate, RenderARDelegate, RecordARDelegate {
    
    
    var recorder: RecordAR?
    
    //    var currentOption: Int?
    
    
    // Prepare dispatch queue to leverage GCD for running multithreaded operations
    let recordingQueue = DispatchQueue(label: "recordingThread", attributes: .concurrent)
    let snappingQueue = DispatchQueue(label: "snappingThread", attributes: .concurrent)
    
   // @IBOutlet weak var captureButton: UIButton!
   // @IBOutlet weak var recordButton: UIButton!
    
    // @IBOutlet weak var sceneView: ARSCNView!
    //    @IBOutlet weak var glassesView: UIView!
    //    @IBOutlet weak var collectionView: UICollectionView!
    //    @IBOutlet weak var calibrationView: UIView!
    //    @IBOutlet weak var calibrationTransparentView: UIView!
    //    @IBOutlet weak var collectionBottomConstraint: NSLayoutConstraint!
    //    @IBOutlet weak var calibrationBottomConstraint: NSLayoutConstraint!
    //    @IBOutlet weak var collectionButton: UIButton!
    //    @IBOutlet weak var calibrationButton: UIButton!
    //    @IBOutlet weak var alertLabel: UILabel!
    
    private let glassesPlane = SCNPlane(width: planeWidth , height: planeHeight )
    private let glassesNode = SCNNode()
    
    // outlet variables
    private var captureButton = UIButton()
    private var recordButton = UIButton()
    private var sceneView = ARSCNView()
    private var glassesView = UIView()
   // private var collectionView = UICollectionView()
    private var calibrationView = UIView()
    private var calibrationTransparentView = UIView()
    private var collectionBottomConstraint = NSLayoutConstraint()
    private var calibrationBottomConstraint = NSLayoutConstraint()
    private var collectionButton = UIButton()
    private var calibrationButton = UIButton()
    private var alertLabel = UILabel()
    
    
    private var scaling: CGFloat = 1
    
    private var isCollecionOpened = false {
        didSet {
            updateCollectionPosition()
        }
    }
    private var isCalibrationOpened = false {
        didSet {
            updateCalibrationPosition()
        }
    }
    var ref: DatabaseReference!
    
    
    var smallImages = [UIImage]()
    var bigImages = [UIImage]()
    var smallImagesArray = [String]()
    var bigImagesArray = [String]()
    var smallImagesFetched  = 0
    var smallImagesCount = 0
    var bigImagesFetched  = 0
    var bigImagesCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UserDefaults.standard.removeObject(forKey: "smallImages")
        UserDefaults.standard.removeObject(forKey: "bigImages")
        ref = Database.database().reference()
        // Add Loader
        
        
        
        recordButton.layer.cornerRadius = 8
        recordButton.layer.borderWidth = 1
        recordButton.layer.borderColor = UIColor.init(red: 85.0/255.0, green: 203.0/255.0, blue: 86.0/255.0, alpha: 1.0).cgColor
        
        captureButton.layer.cornerRadius = 8
        captureButton.layer.borderWidth = 1
        captureButton.layer.borderColor = UIColor.init(red: 85.0/255.0, green: 203.0/255.0, blue: 86.0/255.0, alpha: 1.0).cgColor
        
        
        
        
        
        
        
        
        
        guard ARFaceTrackingConfiguration.isSupported else {
            alertLabel.text = "Face tracking is not supported on this device"
            
            return
        }
        
        self.downloadImages()
        
    }
    
    
    func addARView()
    {
        
        // sceneView: ARSCNView!
        sceneView = ARSCNView(frame: CGRect(x: 0.0, y: 0.0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        self.view.addSubview(self.sceneView)
        
        // glassesView: UIView!
        //        glassesView = UIView(frame: )
        
        UIScreen.main.brightness = 1.0
        
        sceneView.delegate = self
        sceneView.showsStatistics = false
        
        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration)
        
        sceneView.showsStatistics = false
        
        
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        
        
      //  setupCollectionView()
        setupCalibrationView()
        
        
        /*-------- Prepare ARVideoKit recorder --------*/
        
        // Initialize ARVideoKit recorder
        recorder = RecordAR(ARSceneKit: sceneView)
        
        // Set the recorder's delegate
        recorder?.delegate = self
        // Set the renderer's delegate
        recorder?.renderAR = self
        // Configure the renderer to perform additional image & video processing
        recorder?.onlyRenderWhileRecording = false
        // Configure ARKit content mode. Default is .auto
        recorder?.contentMode = .aspectFill
        // Add environment light rendering. Default is false
        recorder?.enableAdjustEnvironmentLighting = true
        // Set the UIViewController orientations
        recorder?.inputViewOrientations = [.landscapeLeft, .landscapeRight, .portrait]
        // Configure RecordAR to store media files in local app directory
        recorder?.deleteCacheWhenExported = false
        
    }
    
    func clearArray()
    {
        self.smallImages.removeAll()
        self.bigImages.removeAll()
        self.bigImagesArray.removeAll()
        self.smallImagesArray.removeAll()
        UserDefaults.standard.removeObject(forKey: "smallImages")
        UserDefaults.standard.removeObject(forKey: "bigImages")
        UserDefaults.standard.removeObject(forKey: "smallImagesArray")
        UserDefaults.standard.removeObject(forKey: "bigImagesArray")
    }
    
  public  func downloadImages()
    {
        let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.gray
        loadingIndicator.startAnimating();
        
        DispatchQueue.main.async {
            alert.view.addSubview(loadingIndicator)
            self.present(alert, animated: true, completion: nil)
        }
        
        self.smallImages = try! UserDefaults.standard.images(forKey: "smallImages")
        
        if(self.smallImages.count == 0)
        {
            
            
            self.ref.child("Without_Background").observeSingleEvent(of: .value) { snapShot,arg  in
                var value = snapShot.value  as? NSMutableArray
                
                for obj in value as! [String]{
                    self.smallImagesArray.append(obj)
                }
                //   let sortedYourArray = value!.sorted( by: { $0.0 < $1.0 })
                
                // print(sortedYourArray)
                self.smallImagesCount = value?.count ?? 0
                
                for obj in value as? [String] ?? [""]
                {
                    let url = URL(string:obj)
                    if(url != nil)
                    {
                        if let data = try? Data(contentsOf: (url ?? URL (string: ""))!)
                        {
                            let image: UIImage = UIImage(data: data)!
                            
                            // completion(.success(image))
                            self.smallImages.append(image)
                            if( self.smallImages.count == self.smallImagesCount)
                            {
                                self.smallImagesFetched = self.smallImages.count
                                print("All Image fetched")
                                try! UserDefaults.standard.set(images: self.smallImages, forKey: "smallImages")
                                try! UserDefaults.standard.set(self.smallImagesArray, forKey: "smallImagesArray")
                                
                                if(self.smallImagesFetched == self.bigImagesFetched)
                                {
                                    
                                    DispatchQueue.main.async {
                                        self.dismiss(animated: false, completion: nil)
                                    }
                                    self.addARView()
                                    //   self.addObserverFirebase()
                                }
                            }
                        }
                    }
                }
            }
        }
        else
        {
            self.smallImagesArray = UserDefaults.standard.value(forKey: "smallImagesArray") as! [String]
            self.smallImages = try! UserDefaults.standard.images(forKey: "smallImages")
            self.smallImagesFetched = self.smallImages.count
            if(self.smallImagesFetched == self.bigImagesFetched)
            { DispatchQueue.main.async {
                self.dismiss(animated: false, completion: nil)
            }
                self.addARView()
                //  self.addObserverFirebase()
            }
    
        }
        
        self.bigImages = try! UserDefaults.standard.images(forKey: "bigImages")
        
        
        if(self.bigImages.count == 0)
        {
            
            self.ref.child("With_Bakground").observeSingleEvent(of: .value) { snapShot in
                let value = snapShot.value as? NSArray
                print(value)
                self.bigImagesArray = value as! [String]
                self.bigImagesCount = value?.count ?? 0
                var urlArray = [URL]()
                for obj in value as! [String]
                {
                    let url = URL(string:obj)
                    if(url != nil)
                    {
                        if let data = try? Data(contentsOf: url!)
                        {
                            let image: UIImage = UIImage(data: data)!
                            
                            // completion(.success(image))
                            self.bigImages.append(image)
                            if( self.bigImages.count == self.bigImagesCount)
                            {
                                self.bigImagesFetched = self.bigImages.count
                                print("All Image fetched")
                                try! UserDefaults.standard.set(images: self.bigImages, forKey: "bigImages")
                                try! UserDefaults.standard.set(self.bigImagesArray, forKey: "bigImagesArray")
                                if(self.smallImagesFetched == self.bigImagesFetched)
                                {
                                    
                                    DispatchQueue.main.async {
                                        self.dismiss(animated: false, completion: nil)
                                    }
                                    self.addARView()
                                    //       self.addObserverFirebase()
                                    
                                }
                            }
                            
                            
                            
                        }
                    }
                    
                }
                
                
            }
            
        }
        
        else
        {
            self.bigImagesArray = try! UserDefaults.standard.value(forKey: "bigImagesArray") as! [String]
            self.bigImages = try! UserDefaults.standard.images(forKey: "bigImages")
            self.bigImagesFetched = self.bigImages.count
            if(self.smallImagesFetched == self.bigImagesFetched)
            {
                DispatchQueue.main.async {
                    self.dismiss(animated: false, completion: nil)
                }
                self.addARView()
                //  self.addObserverFirebase()
            }
        }
    }
    
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if(self.smallImagesFetched > 0 && self.bigImagesFetched > 0 && self.smallImagesFetched == self.bigImagesFetched)
        {
            let configuration = ARFaceTrackingConfiguration()
            sceneView.session.run(configuration)
            
            
            // Run the view's session
            sceneView.session.run(configuration)
            
            // Prepare the recorder with sessions configuration
            recorder?.prepare(configuration)
        }
    }
    
    func download(_ url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        
        
        
        if let data = try? Data(contentsOf: url)
        {
            let image: UIImage = UIImage(data: data)!
            
            completion(.success(image))
            
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if(self.smallImagesFetched > 0 && self.bigImagesFetched > 0 && self.smallImagesFetched == self.bigImagesFetched)
        {
            sceneView.session.pause()
            
            if recorder?.status == .recording {
                recorder?.stopAndExport()
            }
            recorder?.onlyRenderWhileRecording = true
            recorder?.prepare(ARWorldTrackingConfiguration())
            
            // Switch off the orientation lock for UIViewControllers with AR Scenes
            recorder?.rest()
        }
    }
    
    private func setupCollectionView() {
       // collectionView.dataSource = self
        //collectionView.delegate = self
        collectionBottomConstraint.constant = -glassesView.bounds.size.height
    }
    
    private func setupCalibrationView() {
        calibrationTransparentView.layer.cornerRadius = cornerRadius
        calibrationBottomConstraint.constant = -calibrationView.bounds.size.height
    }
    
    private func updateGlasses(with index: Int) {
        let imageName = "glasses\(index)"
        glassesPlane.firstMaterial?.diffuse.contents = bigImages[index]
        //   glassesPlane.firstMaterial?.diffuse.contents = UIImage(named: imageName)
    }
    
    private func updateCollectionPosition() {
        collectionBottomConstraint.constant = isCollecionOpened ? 0 : -glassesView.bounds.size.height
        UIView.animate(withDuration: animationDuration) {
            self.calibrationButton.alpha = self.isCollecionOpened ? 0 : 1
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateCalibrationPosition() {
        calibrationBottomConstraint.constant = isCalibrationOpened ? 0 : -calibrationView.bounds.size.height
        UIView.animate(withDuration: animationDuration) {
            self.collectionButton.alpha = self.isCalibrationOpened ? 0 : 1
            self.view.layoutIfNeeded()
        }
    }
    
    private func updateSize() {
        glassesPlane.width = scaling * planeWidth
        glassesPlane.height = scaling * planeHeight
    }
    
    
    // MARK: - Present post-exporting UIAlert
    // REMINDER TO SELF: Method must be called on main thread or app will crash!!!
    func exportMessage(success: Bool, status: PHAuthorizationStatus) {
        if success {
            // DispatchQueue.main.sync {
            let alert = UIAlertController(title: "Filter App", message: "Media exported to your camera roll!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
            //  }
        } else if status == .denied || status == .restricted || status == .notDetermined {
            let errorView = UIAlertController(title: "Access Required", message: "Please allow access to the photo library in order to save the file.", preferredStyle: .alert)
            let settingsBtn = UIAlertAction(title: "Open Settings", style: .cancel) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        })
                    } else {
                        UIApplication.shared.openURL(URL(string:UIApplication.openSettingsURLString)!)
                    }
                }
            }
            errorView.addAction(UIAlertAction(title: "Later", style: UIAlertAction.Style.default, handler: {
                (UIAlertAction)in
            }))
            errorView.addAction(settingsBtn)
            self.present(errorView, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: "Exporting Failed", message: "There was an error while exporting your media file.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
    
    
    
    // MARK: - Actions
    
    
    @IBAction func captureButtonAction(_ sender: Any) {
        
        
        capturePhoto()
        
    }
    
    
    @IBAction func recordButtonAction(_ sender: Any) {
        
        
    }
    
    @IBAction func collectionDidTap(_ sender: UIButton) {
        isCollecionOpened = !isCollecionOpened
    }
    
    @IBAction func calibrationDidTap(_ sender: UIButton) {
        isCalibrationOpened = !isCalibrationOpened
    }
    
    @IBAction func sceneViewDidTap(_ sender: UITapGestureRecognizer) {
        isCollecionOpened = false
        isCalibrationOpened = false
    }
    
    @IBAction func upDidTap(_ sender: UIButton) {
        glassesNode.position.y += minPositionDistance
    }
    
    @IBAction func downDidTap(_ sender: UIButton) {
        glassesNode.position.y -= minPositionDistance
    }
    
    @IBAction func leftDidTap(_ sender: UIButton) {
        glassesNode.position.x -= minPositionDistance
    }
    
    @IBAction func rightDidTap(_ sender: UIButton) {
        glassesNode.position.x += minPositionDistance
    }
    
    @IBAction func farDidTap(_ sender: UIButton) {
        glassesNode.position.z += minPositionDistance
    }
    
    @IBAction func closerDidTap(_ sender: UIButton) {
        glassesNode.position.z -= minPositionDistance
    }
    
    @IBAction func biggerDidTap(_ sender: UIButton) {
        scaling += minScaling
        updateSize()
    }
    
    @IBAction func smallerDidTap(_ sender: UIButton) {
        scaling -= minScaling
        updateSize()
    }
    
    func downloadAllImages(_ urls: [URL], completion: @escaping ([UIImage]) -> Void) {
        //   DispatchQueue.global(qos: .utility).async {
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: 3)
        var imageDictionary: [UIImage] = []
        
        // download the images
        
        for url in urls {
            group.enter()
            semaphore.wait()
            
            self.download(url) { result in
                defer {
                    semaphore.signal()
                    group.leave()
                }
                
                switch result {
                case .failure(let error):
                    print(error)
                    
                case .success(let image):
                    DispatchQueue.main.async {
                        imageDictionary.append(image)
                    }
                }
            }
        }
        
        // now sort the results
        
        group.notify(queue: .main) {
            completion(imageDictionary)
        }
        //   }
    }
    
    
    
    
    
}

extension BaseViewController {
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let device = sceneView.device else {
            return nil
        }
        
        let faceGeometry = ARSCNFaceGeometry(device: device)
        let faceNode = SCNNode(geometry: faceGeometry)
        faceNode.geometry?.firstMaterial?.transparency = 0
        
        glassesPlane.firstMaterial?.isDoubleSided = true
        updateGlasses(with: 0)
        
        glassesNode.position.z = faceNode.boundingBox.max.z * 3 / 4
        glassesNode.position.y = nodeYPosition
        glassesNode.geometry = glassesPlane
        
        faceNode.addChildNode(glassesNode)
        
        return faceNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
            return
        }
        
        faceGeometry.update(from: faceAnchor.geometry)
    }
}

extension BaseViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return   0// self.smallImages.count
        //  return glassesCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! GlassesCollectionViewCell
        //    let imageName = "glasses\(indexPath.row + 10)"
        // cell.setup(with: smallImages[indexPath.row])
        cell.setup(with: self.smallImages[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        updateGlasses(with: indexPath.row)
    }
}


extension BaseViewController : AVCaptureFileOutputRecordingDelegate {
    
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        print("Hello")
        
    }
    
    func capturePhoto() {
        let image = sceneView.snapshot()
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { saved, error in
            if saved {
                print("Image saved to photo library.")
                DispatchQueue.main.sync {
                    let alert = UIAlertController(title: "Filter App", message: "Image saved to photo library.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                print("Error saving image: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
    
}





// MARK: - Button Action Methods

extension BaseViewController {
    @IBAction func close(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    
    @IBAction func shoot(_ sender: UIButton) {
        print("video option recognized:")
        
        // Record with duration
        if recorder?.status == .readyToRecord {
            // Recording started. Set to Record
            print("recording started")
            
            sender.backgroundColor = .red
            sender.setTitle("Stop", for: .normal)
            
            
            recordingQueue.async {
                self.recorder?.record(forDuration: 60) { path in
                    self.recorder?.export(video: path) { saved, status in
                        DispatchQueue.main.sync {
                            // Recording stopped. Set to readyToRecord
                            sender.backgroundColor = .clear
                            sender.setTitle("Record", for: .normal)
                            
                            self.exportMessage(success: saved, status: status)
                        }
                    }
                }
            }
        } else if recorder?.status == .recording {
            // Recording stopped. Set to readyToRecord
            print("terminated recording")
            
            sender.backgroundColor = .clear
            sender.setTitle("Record", for: .normal)
            
            
            recorder?.stop() { path in
                self.recorder?.export(video: path) { saved, status in
                    DispatchQueue.main.sync {
                        self.exportMessage(success: saved, status: status)
                    }
                }
            }
        }
    }
    
    //func clickPhotos(){
    //} else {
    //    print("live photo option recognized:")
    //
    //    // Live photo
    //    if recorder?.status == .readyToRecord {
    //        print("snapping live photo")
    //
    //
    //
    //        snappingQueue.async {
    //            self.recorder?.livePhoto(export: true) { ready, photo, status, saved in
    //                /*
    //                 if ready {
    //                 // Do something with the `photo` (PHLivePhotoPlus)
    //                 }
    //                 */
    //
    //                if saved {
    //                    // Inform user Live Photo has exported successfully
    //                    print("live photo successfully saved")
    //                    DispatchQueue.main.sync {
    //                        sender.backgroundColor = .white
    //
    //
    //                        self.exportMessage(success: saved, status: status)
    //                    }
    //                }
    //            }
    //        }
    //    }
    //}
    //
    
}
// MARK: - ARVideoKit Delegate Methods

extension BaseViewController {
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        // Do some image/video processing.
    }
    
    func recorder(didEndRecording path: URL, with noError: Bool) {
        if noError {
            // Do something with the video path.
        }
    }
    
    func recorder(didFailRecording error: Error?, and status: String) {
        // Inform user an error occurred while recording.
    }
    
    func recorder(willEnterBackground status: RecordARStatus) {
        // Use this method to pause or stop video recording. Check [applicationWillResignActive(_:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622950-applicationwillresignactive) for more information.
        if status == .recording {
            recorder?.stopAndExport()
        }
    }
}

extension UIImageView {
    func loadFrom(URLAddress: String) {
        guard let url = URL(string: URLAddress) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            if let imageData = try? Data(contentsOf: url) {
                if let loadedImage = UIImage(data: imageData) {
                    self?.image = loadedImage
                }
            }
        }
    }
}

extension UserDefaults{
    
    func set(images value: [UIImage]?, forKey defaultName: String) throws {
        guard let value = value else {
            removeObject(forKey: defaultName)
            return
        }
        try set(NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false), forKey: defaultName)
    }
    
    func images(forKey defaultName: String) throws -> [UIImage] {
        guard let data = data(forKey: defaultName) else { return [] }
        
        let object = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)
        return object as? [UIImage] ?? []
    }
}
