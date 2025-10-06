import UIKit

class SALCtrlViewController: UIViewController {

    // MARK: - UI Components
    @IBOutlet weak var textCurLF: UILabel!
    @IBOutlet weak var textCurRF: UILabel!
    @IBOutlet weak var textCurLM: UILabel!
    @IBOutlet weak var textCurRM: UILabel!
    @IBOutlet weak var textCurLB: UILabel!
    @IBOutlet weak var textCurRB: UILabel!
    
    @IBOutlet weak var textMaxLF: UILabel!
    @IBOutlet weak var textMaxRF: UILabel!
    @IBOutlet weak var textMaxLM: UILabel!
    @IBOutlet weak var textMaxRM: UILabel!
    @IBOutlet weak var textMaxLB: UILabel!
    @IBOutlet weak var textMaxRB: UILabel!
    
    @IBOutlet weak var slopeFBLabel: UILabel!
    @IBOutlet weak var slopeLRLabel: UILabel!
    @IBOutlet weak var voltageLabel: UILabel!
    
    @IBOutlet weak var sideImageView: UIImageView!
    @IBOutlet weak var backImageView: UIImageView!
    
    @IBOutlet weak var btLFront: UIButton!
    @IBOutlet weak var btLMiddle: UIButton!
    @IBOutlet weak var btLRear: UIButton!
    @IBOutlet weak var btRFront: UIButton!
    @IBOutlet weak var btRMiddle: UIButton!
    @IBOutlet weak var btRRear: UIButton!
    @IBOutlet weak var btUp: UIButton!
    @IBOutlet weak var btDown: UIButton!
    @IBOutlet weak var btAuto: UIButton!
    @IBOutlet weak var btInit: UIButton!
    @IBOutlet weak var btSetView: UIButton!
    @IBOutlet weak var btParking: UIButton!
    @IBOutlet weak var btGReset: UIButton!
    
    // MARK: - State Variables
    private var FBAngle: CGFloat = 0
    private var LRAngle: CGFloat = 0
    
    private var curLabels: [UILabel] = []
    private var maxLabels: [UILabel] = []
    
    private var frontButtons: [UIButton] = []
    private var middleButtons: [UIButton] = []
    private var rearButtons: [UIButton] = []
    private var buttonMap: [UIButton: String] = [:]
    
    private var iSALModel = 0
    private var isAutoFinish = false
    private var isMode4 = false
    private var mCmdSelect: UInt8 = 0x30  // '0'
    private var mCmdMotion: UInt8 = 0x50 // 'P'
    
    private var motionCmdStopCount = 0
    private let STOP_MESSAGE_SENDNUM = 10
    
    private var buttonStates: [ButtonType: Bool] = [:]
    
    private var timer: Timer?
    
    enum ButtonType {
        case gReset, initSetup, setView, parking
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUIArrays()
        setupButtons()
        loadConfig()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    deinit {
        stopTimer()
    }
    
    // MARK: - Setup
    private func setupUIArrays() {
        curLabels = [textCurLM, textCurRM, textCurLF, textCurRF, textCurLB, textCurRB]
        maxLabels = [textMaxLM, textMaxRM, textMaxLF, textMaxRF, textMaxLB, textMaxRB]
        
        frontButtons = [btLFront, btRFront]
        middleButtons = [btLMiddle, btRMiddle]
        rearButtons = [btLRear, btRRear]
        
        for btn in frontButtons + middleButtons + rearButtons {
            buttonMap[btn] = "0"
            btn.tag = 0
        }
        
        btAuto.tag = 1
        btUp.tag = 0
        btDown.tag = 0
        btSetView.tag = 0
    }
    
    private func setupButtons() {
        for btn in frontButtons + middleButtons + rearButtons + [btUp, btDown, btAuto] {
            btn.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        
        btInit.addTarget(self, action: #selector(expertCommand(_:)), for: .touchUpInside)
        btGReset.addTarget(self, action: #selector(expertCommand(_:)), for: .touchUpInside)
        btSetView.addTarget(self, action: #selector(expertCommand(_:)), for: .touchUpInside)
        btParking.addTarget(self, action: #selector(expertCommand(_:)), for: .touchUpInside)
    }
    
    private func loadConfig() {
        iSALModel = 1 // 기본 모델 설정, 필요 시 MainControlViewController에서 전달
    }
    
    // MARK: - Button Actions
    @objc private func buttonTouchDown(_ sender: UIButton) {
        if sender == btUp {
            btUp.tag = 1
            btDown.tag = 0
            btAuto.tag = 2
        } else if sender == btDown {
            btDown.tag = 1
            btUp.tag = 0
            btAuto.tag = -2
        } else if sender == btAuto {
            btAuto.tag = 1
            btUp.tag = 0
            btDown.tag = 0
        } else {
            clearSelection(for: sender)
            sender.tag = 1
        }
        motionCmdStopCount = STOP_MESSAGE_SENDNUM
        sendActionCommand()
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        if sender == btUp || sender == btDown {
            btUp.tag = 0
            btDown.tag = 0
        }
        motionCmdStopCount = STOP_MESSAGE_SENDNUM
        sendActionCommand()
    }
    
    @objc private func expertCommand(_ sender: UIButton) {
        var type: ButtonType?
        switch sender {
        case btGReset: type = .gReset
        case btInit: type = .initSetup
        case btSetView: type = .setView
        case btParking: type = .parking
        default: break
        }
        
        guard let t = type else { return }
        buttonStates[t] = true
        
        let alert = UIAlertController(title: "확인", message: "이 작업을 수행하시겠습니까?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        self.present(alert, animated: true)
        
        sendActionCommand()
    }
    
    private func clearSelection(for button: UIButton) {
        if !frontButtons.contains(button) {
            frontButtons.forEach { $0.tag = 0 }
        }
        if !middleButtons.contains(button) {
            middleButtons.forEach { $0.tag = 0 }
        }
        if !rearButtons.contains(button) {
            rearButtons.forEach { $0.tag = 0 }
        }
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.sendActionCommand()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Command Handling
    private func sendActionCommand() {
        var data: Data
        let isOneSend = true
        
        if let _ = buttonStates[.setView], buttonStates[.setView]! {
            // Mode toggle
            data = mode4Change(!isMode4)
            buttonStates[.setView] = false
        } else {
            data = Data([UInt8(ascii: "S"), mCmdSelect, UInt8(ascii: "C"), mCmdMotion, UInt8(ascii: "M"), (mCmdSelect + mCmdMotion) & 0xFF, 13, 10])
        }
        
        if motionCmdStopCount > 0 || isOneSend {
            BluetoothManager.shared.sendData(data)
            if isOneSend {
                motionCmdStopCount = 0
                mCmdSelect = 0x30
                mCmdMotion = 0x50
            }
        }
        
        if mCmdMotion == 0x50 && motionCmdStopCount > 0 {
            motionCmdStopCount -= 1
        }
        
        updateCaravanMotion()
    }
    
    private func mode4Change(_ setMode4: Bool) -> Data {
        isMode4 = setMode4
        voltageLabel.text = setMode4 ? "전문가모드 ON" : ""
        return Data([UInt8(ascii: "$"), setMode4 ? 0x34 : 0x30])
    }
    
    private func updateCaravanMotion() {
        // 이미지 회전
        if let side = sideImageView.image {
            sideImageView.image = rotateImage(side, degree: FBAngle)
        }
        if let back = backImageView.image {
            backImageView.image = rotateImage(back, degree: LRAngle)
        }
    }
    
    private func rotateImage(_ image: UIImage, degree: CGFloat) -> UIImage {
        let radians = degree * .pi / 180
        UIGraphicsBeginImageContext(image.size)
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        context.translateBy(x: image.size.width/2, y: image.size.height/2)
        context.rotate(by: radians)
        image.draw(in: CGRect(x: -image.size.width/2, y: -image.size.height/2,
                              width: image.size.width, height: image.size.height))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return rotatedImage
    }
}
